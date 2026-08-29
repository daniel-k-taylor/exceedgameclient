class_name AIPolicyOmniscient
extends Node

## Omniscient AI policy - a strong, hand-crafted evaluation policy that can read the
## opponent's ENTIRE hand to make optimal decisions.
##
## HIDDEN INFORMATION / "CHEATING":
## When ALLOW_HIDDEN_INFO is true (the default, ported as-is from the source build so we
## can evaluate its strength) this policy inspects the opponent's actual hand contents,
## which is information a fair player would not have. This is a deliberate, gated cheat.
## All reads of the opponent's hand contents go through _visible_opponent_hand(); when
## ALLOW_HIDDEN_INFO is false that helper returns an empty array, so the analysis routines
## simply see "no known cards" and the policy plays without cheating (weaker, but legal).
## A future change can replace the empty-hand fallback with a deck-based estimation to
## build a fair "hard" tier. The exact hidden-info call sites are documented on
## _visible_opponent_hand() below.
##
## NOTE: The original build also shipped an online neural-net "learner" (ai_learner.gd)
## that hooked into this policy. It was intentionally NOT ported (its terminal-reward hook
## was never invoked and no trained weights shipped); every learner hook has been stripped.
##
## Key capabilities:
##   1. Opponent hand analysis (gated by ALLOW_HIDDEN_INFO)
##   2. Counter-play: avoid playing into counter-strikes, blocks, etc.
##   3. Safe positioning: stand where opponent has no valid strikes
##   4. Gauge-aware: reason about what the opponent can afford to play
##   5. Trap avoidance: never walk into ignore_armor when relying on armor
##   6. Block detection: know if opponent has block cards
##   7. Speed-gap exploitation: know if we can outspeed the opponent
##   8. Reading + Spike combo: Standard Focus boost -> name key card -> penetrating hit

## When true, the policy reads the opponent's hidden hand (see class docs). Default true
## preserves the original "super" difficulty behaviour for A/B evaluation. Set to false for
## a fair (blind) variant.
const ALLOW_HIDDEN_INFO := true

var _pick_turn_count: int = 0

const SPEED_CURVE := {1: 7, 2: 6, 3: 5, 4: 4}

# Opponent hand analysis cache (per-turn)
var _cached_state = null
var _card_def_cache: Dictionary = {}
var _opp_hand_analysis: Dictionary = {}
const HIGH_STUN_THRESHOLD := 7
const GUARANTEED_STUN_THRESHOLD := 8
const MAX_CONTINUOUS_BOOSTS := 3


var _last_distance: int = -1  # for detecting zigzag moves
var _last_move_direction: int = 0  # 1=advanced, -1=retreated, 0=none

var __factorial_cache = {
	"cache_max": 7,
	0: 1, 1: 1, 2: 2, 3: 6, 4: 24,
	5: 120, 6: 720, 7: 5040,
}

var __combinations_cache = {
	[0, 0]: 1, [1, 0]: 1, [1, 1]: 1,
	[2, 0]: 1, [2, 1]: 2, [2, 2]: 1,
}

var _sort_state: AIPlayer.AIGameState = null
var _sort_key: String = ""


func _factorial(n: int) -> int:
	if n not in __factorial_cache:
		for i in range(__factorial_cache["cache_max"] + 1, n + 1):
			__factorial_cache[i] = __factorial_cache[i - 1] * i
	return __factorial_cache[n]


func _combinations(n: int, r: int) -> int:
	if n < r: return 0
	if [n, r] not in __combinations_cache:
		if r == 0 or r == n: __combinations_cache[[n, r]] = 1
		else: __combinations_cache[[n, r]] = _combinations(n - 1, r) + _combinations(n - 1, r - 1)
	return __combinations_cache[[n, r]]


func get_locations_after_effect(effect: Dictionary, my_location: int, opponent_location: int, buddy_location: int) -> Dictionary:
	var direction = -1
	if my_location < opponent_location: direction = 1
	match effect['effect_type']:
		'advance':
			for i in range(effect['amount']):
				my_location += direction
				if my_location == opponent_location: my_location += direction
			my_location = clamp(my_location, 1, 9)
			if my_location == opponent_location: my_location -= direction
		'close':
			for i in range(effect['amount']):
				my_location += direction
				if my_location == opponent_location:
					my_location -= direction
					break
		'pull':
			for i in range(effect['amount']):
				opponent_location -= direction
				if my_location == opponent_location: opponent_location -= direction
			opponent_location = clamp(opponent_location, 1, 9)
			if my_location == opponent_location: opponent_location += direction
		'push':
			for i in range(effect['amount']): opponent_location += direction
			opponent_location = clamp(opponent_location, 1, 9)
		'retreat':
			for i in range(effect['amount']): my_location -= direction
			my_location = clamp(my_location, 1, 9)
		'place_buddy_onto_self':
			buddy_location = my_location
		_: pass
	if 'and' in effect:
		var and_result = get_locations_after_effect(effect['and'], my_location, opponent_location, buddy_location)
		my_location = and_result['my_location']
		opponent_location = and_result['opponent_location']
		buddy_location = and_result['buddy_location']
	return {"my_location": my_location, "opponent_location": opponent_location, "buddy_location": buddy_location}


func can_card_hit(card_id: int, ex_card_id: int, ai_game_state: AIPlayer.AIGameState) -> bool:
	if card_id == -1: return false
	var card: GameCard = ai_game_state.card_db.get_card(card_id)
	if not card or not card.definition: return false
	var blocks = ["gg_normal_block", "uni_normal_block", "standard_normal_block"]
	if card.definition['id'] in blocks:
		if ex_card_id != -1:
			var ex_card = ai_game_state.card_db.get_card(ex_card_id)
			if ex_card and ex_card.definition['id'] in blocks: return false
		return true
	var gauge_cost = card.definition.get('gauge_cost', 0)
	if gauge_cost > ai_game_state.my_state.gauge.size(): return false
	var my_location = ai_game_state.my_state.arena_location
	var opponent_location = ai_game_state.opponent_state.arena_location
	var buddy_location = -1
	if ai_game_state.my_state.buddy_locations.size() > 0:
		buddy_location = ai_game_state.my_state.buddy_locations[0]
	var from_buddy = false
	for effect in card.definition.get('effects', []):
		if effect.get('timing') == "before":
			# Skip conditional before effects (e.g. Shoryuken close-on-critical)
			# that may not be active in the current game state
			var cond = effect.get('condition', '')
			if cond != '':
				# is_critical: only apply if character has gauge (can trigger critical)
				if cond == 'is_critical':
					if ai_game_state.my_state.gauge.size() < 1:
						continue
				else:
					continue  # Skip other conditional before effects conservatively
			var result = get_locations_after_effect(effect, my_location, opponent_location, buddy_location)
			my_location = result['my_location']
			opponent_location = result['opponent_location']
			buddy_location = result['buddy_location']
		if effect.get('effect_type') == "calculate_range_from_buddy": from_buddy = true
	var distance_after_effects = abs(my_location - opponent_location)
	if from_buddy: distance_after_effects = abs(buddy_location - opponent_location)
	var range_min = card.definition.get('range_min', 1)
	if range_min is String: range_min = 1
	var range_max = card.definition.get('range_max', range_min + 3)
	if range_max is String: range_max = range_min + 3
	return range_min <= distance_after_effects and distance_after_effects <= range_max


func _get_card_speed(card_id: int, state: AIPlayer.AIGameState, is_response: bool = false, is_critical: bool = false, is_opponent: bool = false) -> int:
	if card_id == -1: return 0
	var card_def = _get_def(card_id, state)
	if not card_def: return 0
	var speed = card_def.get("speed", 0)
	if speed is String: return 20
	# Include conditional speed effects (e.g. Shoryuken +2 on response, Hadoken +2 on crit)
	for ef in card_def.get("effects", []):
		if ef.get("effect_type") == "speedup":
			var cond = ef.get("condition", "")
			if (cond == "not_initiated_strike" and is_response) or (cond == "is_critical" and is_critical):
				speed += ef.get("amount", 0)
	# Include continuous boost effects (boost zone): only count the opponent's own boosts, to prevent our boosts from polluting the opponent's speed
	var boost_source: Array = state.opponent_state.continuous_boosts if is_opponent else state.my_state.continuous_boosts
	for bid in boost_source:
		var _bc = state.card_db.get_card(bid)
		if not _bc or not _bc.definition: continue
		var bdef = _bc.definition.get("boost", {})
		for bef in bdef.get("effects", []):
			if bef.get("timing") == "during_strike":
				if bef.get("effect_type") == "speedup":
					speed += bef.get("amount", 0)
				elif bef.get("effect_type") == "attack_is_ex":
					speed += 1
	return speed


func _get_card_power(card_id: int, state: AIPlayer.AIGameState) -> int:
	if card_id == -1: return 0
	var defn = _get_def(card_id, state)
	if not defn: return 0
	var power = defn.get('power', 0)
	return 0 if power is String else power


func _get_card_guard(card_id: int, state: AIPlayer.AIGameState) -> int:
	if card_id == -1: return 0
	var defn = _get_def(card_id, state)
	if not defn: return 0
	return defn.get('guard', 0)


func _get_card_armor(card_id: int, state: AIPlayer.AIGameState) -> int:
	if card_id == -1: return 0
	var defn = _get_def(card_id, state)
	if not defn: return 0
	return defn.get('armor', 0)


func _get_card_range_min(card_id: int, state: AIPlayer.AIGameState) -> int:
	if card_id == -1: return -1
	var defn = _get_def(card_id, state)
	if not defn: return -1
	var r = defn.get('range_min', 1)
	return 1 if r is String else r


func _get_card_range_max(card_id: int, state: AIPlayer.AIGameState) -> int:
	if card_id == -1: return -1
	var defn = _get_def(card_id, state)
	if not defn: return -1
	var r = defn.get('range_max', 1)
	return 4 if r is String else r


func _is_block_card(card_id: int, state: AIPlayer.AIGameState) -> bool:
	if card_id == -1: return false
	var defn = _get_def(card_id, state)
	if not defn: return false
	var blocks = ["gg_normal_block", "uni_normal_block", "standard_normal_block"]
	return defn['id'] in blocks


func _get_card_id_str(card_id: int, state: AIPlayer.AIGameState) -> String:
	if card_id == -1: return ""
	var defn = _get_def(card_id, state)
	if not defn: return ""
	return defn['id']


func _get_distance(state: AIPlayer.AIGameState) -> int:
	return abs(state.my_state.arena_location - state.opponent_state.arena_location)


func _opp_can_hit_at_distance(d: int, state: AIPlayer.AIGameState) -> bool:
	## Whether the opponent could possibly hit me at distance d (used to judge movement-effect safety):
	## Considers the range of already-played cards + hand cards, including rangeup from the opponent's boost zone
	var _range_bonus_min: int = 0
	var _range_bonus_max: int = 0
	for bid in state.opponent_state.continuous_boosts:
		var _bc = state.card_db.get_card(bid)
		if not _bc or not _bc.definition: continue
		var bdef = _bc.definition.get("boost", {})
		for bef in bdef.get("effects", []):
			if bef.get("effect_type") == "rangeup":
				_range_bonus_min += bef.get("amount", 0)
				_range_bonus_max += bef.get("amount2", 0)
	var _check = func(cid: int) -> bool:
		if cid == -1: return false
		if _is_block_card(cid, state): return true  # Block cards can respond at any distance
		var rmin = _get_card_range_min(cid, state) + _range_bonus_min
		var rmax = _get_card_range_max(cid, state) + _range_bonus_max
		return rmin <= d and d <= rmax
	# 1) Cards the opponent has already played (ongoing strike)
	if state.active_strike and state.active_strike.active:
		if _check.call(state.active_strike.initiator_card_id): return true
		if _check.call(state.active_strike.initiator_ex_card_id): return true
	# 2) Opponent's hand cards
	for cid in _visible_opponent_hand(state):
		if _check.call(cid): return true
	return false


func _movement_effect_new_distance(effect, d: int) -> int:
	## Estimate the distance after applying a movement effect; returns -1 for non-movement effects
	if effect == null or not (effect is Dictionary): return -1
	var et: String = str(effect.get("effect_type", ""))
	var amt = effect.get("amount", 0)
	if amt == null or amt is String: return -1  # Dynamic amount (e.g. strike_x) can't be estimated
	match et:
		"advance", "close", "pull":
			# We close in / pull the opponent closer -> distance decreases (may pass through)
			return max(abs(d - amt), 1)
		"retreat", "push":
			# We retreat / push the opponent away -> distance increases
			return d + amt
	return -1


func _estimate_opponent_max_normal_speed(distance: int, state: AIPlayer.AIGameState) -> int:
	var max_speed: int = 0
	for card in state.opponent_state.deck_list:
		if card.definition.get('type') != "normal": continue
		if _is_block_card(card.id, state): continue
		var rmin = card.definition.get('range_min', 1)
		if rmin is String: rmin = 1
		var rmax = card.definition.get('range_max', rmin + 3)
		if rmax is String: rmax = rmin + 3
		if rmin <= distance and distance <= rmax:
			var speed = card.definition.get('speed', 0)
			if speed is String: speed = 0
			if speed > max_speed: max_speed = speed
	return max_speed


func _get_character_profile(player_state, _state: AIPlayer.AIGameState) -> Dictionary:
	## Returns detailed character profile for strategy adaptation.
	var deck_def = player_state.deck_def
	var char_id: String = deck_def.get("id", "unknown")
	var season: int = deck_def.get("season", 1)

	# Count card types and collect stats
	var normal_cards := []
	var special_cards := []
	var all_specials := []
	for card in player_state.deck_list:
		var cdef = card.definition
		var ctype = cdef.get("type", "")
		if ctype == "normal": normal_cards.append(cdef)
		elif ctype == "special": special_cards.append(cdef)
		if ctype in ["normal", "special"]: all_specials.append(cdef)

	# Range analysis (primarily from specials)
	var ranged_count: int = 0
	var melee_count: int = 0
	var total_range: float = 0.0
	var range_count: int = 0
	for cdef in special_cards:
		var rmax = cdef.get("range_max", 1)
		if rmax is String: rmax = 4
		var rmin = cdef.get("range_min", 1)
		if rmin is String: rmin = 1
		if rmax >= 4: ranged_count += 1
		if rmin <= 1: melee_count += 1
		total_range += (rmin + rmax) * 0.5
		range_count += 1

	var avg_range: float = total_range / max(range_count, 1)
	var special_total: int = special_cards.size()

	# Archetype classification
	var archetype: String = "midrange"
	if special_total > 0:
		var ranged_ratio: float = ranged_count * 1.0 / special_total
		var melee_ratio: float = melee_count * 1.0 / special_total
		if ranged_ratio >= 0.5: archetype = "zoner"
		elif melee_ratio >= 0.5: archetype = "rushdown"
		elif avg_range <= 2.0: archetype = "rushdown"
		elif avg_range >= 3.5: archetype = "zoner"

	# Speed analysis (from all playable cards)
	var total_speed: float = 0.0
	var speed_count: int = 0
	for cdef in all_specials:
		var spd = cdef.get("speed", -1)
		if spd is String: spd = -1
		if spd > 0:
			total_speed += spd
			speed_count += 1
	var avg_speed: float = total_speed / max(speed_count, 1)

	# Power analysis
	var total_power: float = 0.0
	var power_count: int = 0
	for cdef in special_cards:
		var pwr = cdef.get("power", -1)
		if pwr is String: pwr = -1
		if pwr > 0:
			total_power += pwr
			power_count += 1
	var avg_power: float = total_power / max(power_count, 1)

	# Critical ability (S3 Exceed)
	var has_critical: bool = false
	var ability_list: Array = deck_def.get("ability_effects", [])
	if player_state.exceeded: ability_list = deck_def.get("exceed_ability_effects", ability_list)
	for ab_eff in ability_list:
		if ab_eff.get("timing") == "set_strike" and ab_eff.get("effect_type") == "gauge_for_effect":
			var _ov = ab_eff.get("overall_effect", {})
			if _ov is Dictionary and _ov.get("effect_type") == "critical":
				has_critical = true; break

	# Aggression score
	var aggro_score: float = 0.5
	if archetype == "rushdown": aggro_score = 0.8
	elif archetype == "zoner": aggro_score = 0.3
	if avg_speed >= 6: aggro_score += 0.1
	if avg_power >= 7: aggro_score += 0.1
	if has_critical: aggro_score += 0.1
	aggro_score = clamp(aggro_score, 0.1, 1.0)

	return {
		"char_id": char_id,
		"season": season,
		"archetype": archetype,
		"avg_speed": avg_speed,
		"avg_power": avg_power,
		"avg_range": avg_range,
		"special_count": special_total,
		"normal_count": normal_cards.size(),
		"has_critical": has_critical,
		"aggro_score": aggro_score,
	}


func _classify_character(player_state, state: AIPlayer.AIGameState) -> String:
	var profile = _get_character_profile(player_state, state)
	return profile["archetype"]


func _get_ideal_distance(my_class: String, opp_class: String) -> int:
	if my_class == "rushdown": return 2 if opp_class == "rushdown" else 1
	if my_class == "zoner": return max(4, 5)
	if opp_class == "rushdown": return 3
	if opp_class == "zoner": return 2
	return 2  # midrange default
func _sort_by_score_desc(a: Dictionary, b: Dictionary) -> bool: return a['score'] > b['score']
func _sort_by_count_asc(a: Dictionary, b: Dictionary) -> bool: return a['count'] < b['count']
func _sort_by_penalty_asc(a: Dictionary, b: Dictionary) -> bool: return a['penalty'] < b['penalty']


func _sort_strike_by_speed(a, b) -> bool:
	return _get_card_speed(a.card_id, _sort_state) > _get_card_speed(b.card_id, _sort_state)


func _sort_strike_by_guard(a, b) -> bool:
	return _get_card_guard(a.card_id, _sort_state) > _get_card_guard(b.card_id, _sort_state)


func _sort_move_by_score(a, b) -> bool:
	return _score_move(a, _sort_state) > _score_move(b, _sort_state)


func _sort_strike_by_score(a, b) -> bool:
	return _score_strike(a.card_id, a.ex_card_id, _sort_state, _sort_key == "response") > _score_strike(b.card_id, b.ex_card_id, _sort_state, _sort_key == "response")


func _card_has_ignore_armor(card_id: int, state: AIPlayer.AIGameState) -> bool:
	## Ignore-armor detection (top-level or nested inside 'and')
	if card_id == -1: return false
	var defn = _get_def(card_id, state)
	if not defn: return false
	return _def_has_effect(defn, "ignore_armor")


func _card_has_ignore_guard(card_id: int, state: AIPlayer.AIGameState) -> bool:
	## Ignore-guard detection (top-level or nested inside 'and', e.g. Dust/Spike's ignore_armor and ignore_guard)
	if card_id == -1: return false
	var defn = _get_def(card_id, state)
	if not defn: return false
	return _def_has_effect(defn, "ignore_guard")


func _is_spike_like(def_id_lower: String) -> bool:
	## Spike-like: id contains 'spike', or GG's Dust (same card as Spike under a different name: power5 speed3 guard4 range2-3, ignore armor+guard)
	return "spike" in def_id_lower or def_id_lower == "gg_normal_dust"


func _can_kill(card_id: int, ex_card_id: int, state: AIPlayer.AIGameState) -> bool:
	var power: int = _get_card_power(card_id, state)
	if ex_card_id != -1: power += 1
	return power >= state.opponent_state.life


func _score_strike(card_id: int, ex_card_id: int, state: AIPlayer.AIGameState, is_response: bool) -> float:
	if card_id == -1: return 0.0
	if not can_card_hit(card_id, ex_card_id, state): return 0.0

	_cache_state(state)
	var distance: int = _get_distance(state)
	var my_speed: int = _get_card_speed(card_id, state, is_response)
	if ex_card_id != -1: my_speed += 1
	var power: int = _get_card_power(card_id, state)
	if ex_card_id != -1: power += 1
	var guard: int = _get_card_guard(card_id, state)
	if ex_card_id != -1: guard += 1
	var armor: int = _get_card_armor(card_id, state)
	var has_ignore: bool = _card_has_ignore_armor(card_id, state) or _card_has_ignore_guard(card_id, state)
	var opp_analysis = _opponent_can_do_now(state)
	var opp_max_speed: int = opp_analysis["max_speed"]
	var opp_can_hit: int = opp_analysis["can_hit_count"]
	var opp_can_kill_me: bool = opp_analysis["can_kill_me"]
	var my_speed_beats_opp: bool = my_speed > opp_max_speed
	var score: float = 0.0

	# Speed advantage (30 points) — omniscient: weighted by actual opponent speed
	var curve_speed: int = SPEED_CURVE.get(distance, 3)
	var speed_diff: int = my_speed - curve_speed
	if my_speed_beats_opp:
		score += 30.0  # Guaranteed first strike vs opponent's ACTUAL best
	elif my_speed == opp_max_speed:
		score += 18.0  # Speed tie (initiator wins)
	else:
		score += 5.0   # Will go second — need armor/guard
	if is_response and my_speed_beats_opp: score += 12.0

	# Opponent-aware threat assessment
	if is_response and my_speed < opp_max_speed and guard < opp_analysis["max_power"]:
		score -= 30.0  # Will get stunned — terrible response
	if not is_response and not my_speed_beats_opp:
		if guard >= opp_analysis["max_power"]: score += 12.0  # Can tank opponent's best
		elif armor >= opp_analysis["max_power"]: score += 8.0
		elif has_ignore: score += 5.0  # At least pierce armor

	# Opponent can't hit us at all — unilateral hit bonus!
	if opp_can_hit == 0: score += 30.0
	# Opponent has ignore_armor — our armor is useless
	if opp_analysis["has_ignore_armor"] and armor > 0 and not is_response: score -= 10.0
	# Opponent can kill us — prioritize survival
	if opp_can_kill_me and not is_response: score -= 15.0

	# Opponent-aware: if opponent HAS Block, penetrating cards are MUCH more valuable
	if opp_analysis["has_block"] and has_ignore:
		score += 18.0  # Opponent can't Block — Spike/penetrate is ideal
	# Opponent-aware: if opponent has few/no in-range cards, our strike is safer
	if opp_can_hit <= 1 and is_response:
		score += 10.0  # Opponent has almost no options — counter-strike is safe
	# Opponent-aware: if opponent's fastest card is slow, aggressive strike is better
	if opp_max_speed <= 3 and not is_response:
		score += 8.0  # We likely go first, strike more confidently
	# Opponent-aware: if opponent has high guard, penetrating cards are more valuable
	if opp_analysis["max_guard"] >= 4 and has_ignore:
		score += 8.0  # Opponent's guard is high — penetrating bypasses it
	# Opponent-aware: if opponent's max_guard is high, we need more power to stun
	if opp_analysis["max_guard"] >= 4 and power <= opp_analysis["max_guard"]:
		score -= 5.0  # Our power won't stun through their guard

	# -- Value trade: worst-case net life swing for us when the opponent responds with their best card --
	var my_def_for_counter = _get_def(card_id, state)
	if my_def_for_counter != null and not my_def_for_counter.is_empty():
		var worst_exchange: int = 0
		var has_exchange: bool = false
		for cb in opp_analysis["cards_by_range"]:
			if not cb.get("in_range", false): continue
			var opp_def_for_counter = cb.get("defn", {})
			if opp_def_for_counter == null or opp_def_for_counter.is_empty(): continue
			var ev: int = _card_exchange_value(my_def_for_counter, opp_def_for_counter, distance, is_response)
			if not has_exchange or ev < worst_exchange:
				worst_exchange = ev
				has_exchange = true
		if has_exchange:
			# Net gain -> reward; net loss of 3+ life -> countered, heavy penalty
			if worst_exchange > 0:
				score += clamp(worst_exchange * 5.0, 0.0, 25.0)
			elif worst_exchange < -2:
				score -= min(-worst_exchange * 6.0, 30.0)
			elif worst_exchange == 0:
				score += 3.0  # Even trade (both hit, or both block) -- slight encouragement

	# -- Deck threat: how many cards remain in the opponent's deck that could hit me at the current distance (may be drawn) --
	var deck_threat_count: int = opp_analysis.get("deck_threats", []).size()
	if deck_threat_count > 0:
		if is_response:
			score -= min(deck_threat_count * 3.0, 9.0)  # When responding, the opponent has more room to swap cards
		else:
			score -= min(deck_threat_count * 1.5, 6.0)  # When initiating, weigh the opponent's draw threat only slightly

	# EX bonus
	if ex_card_id != -1: score += 8.0

	# Combo tips
	var has_gain_adv: bool = false
	var has_draw: bool = false
	var has_discard: bool = false
	var has_retreat: bool = false
	var has_before_advance: bool = false
	var _combo_def = _get_def(card_id, state)
	if _combo_def:
		for ef in _combo_def.get("effects", []):
			var et = ef.get("effect_type")
			if et == "gain_advantage": has_gain_adv = true
			if et == "draw": has_draw = true
			if et == "opponent_discard_random": has_discard = true
			if et == "retreat": has_retreat = true
			if et == "advance" and ef.get("timing") == "before": has_before_advance = true
	if distance == 2 and not is_response and has_ignore: score += 15.0
	if distance == 3 and not is_response and has_gain_adv: score += 20.0
	if is_response and ex_card_id == -1:
		if has_ignore: score -= 25.0
		if has_before_advance: score -= 20.0
	if distance == 3 and is_response:
		if has_draw: score += 12.0
		if has_discard and guard >= 4: score += 10.0
		if has_retreat and my_speed >= 6: score += 10.0
		if has_gain_adv and ex_card_id != -1: score += 15.0

	# Damage & stun (25 points)
	var dmg_score: float = power * 5.0
	if power >= GUARANTEED_STUN_THRESHOLD: dmg_score += 12.0
	elif power >= HIGH_STUN_THRESHOLD: dmg_score += 7.0
	if has_ignore: dmg_score += 5.0
	score += min(dmg_score, 25.0)

	# Survivability (15 points, doubled on defense)
	var survival: float = armor * 2.0 + guard * 1.5
	if is_response: survival *= 2.0
	score += min(survival, 15.0)

	# Guard bonus
	if not is_response and guard >= 4: score += 5.0
	# Speed/Guard bias (with opponent-aware adjustments)
	if not is_response:
		# Strongly prefer at-curve-speed + high guard as initiator
		if speed_diff == 0: score += 15.0
		if speed_diff == 0 and guard >= 4: score += 12.0
		# Penalize above-curve speed UNLESS opponent is also fast
		if speed_diff >= 1:
			if opp_max_speed >= curve_speed: score += 5.0  # Opponent is fast too — speed is needed
			else: score -= 10.0
		# Penalize very slow initiator UNLESS opponent is also slow
		if speed_diff <= -2:
			if opp_max_speed <= 3: score += 3.0  # Opponent is slow too — slow initiator is safe
			else: score -= 8.0
	else:
		# Strongly prefer above-curve speed as responder
		if speed_diff >= 1: score += 25.0
		# Prefer slow at dist 1 and 3 as responder
		if (distance == 1 or distance == 3) and my_speed <= 2: score += 10.0

	# Focus/Block omniscient bonuses
	var card_id_lower = _get_card_id_str(card_id, state).to_lower()
	if "focus" in card_id_lower:
		score += 12.0  # Draw effect
		if not my_speed_beats_opp: score += 8.0  # Safe when slower
		if distance <= 2: score += 5.0
	if "block" in card_id_lower:
		if not my_speed_beats_opp: score += 18.0  # Defensive value
		if opp_can_kill_me: score += 25.0  # Emergency block
		score += 5.0  # Resource positive

	# Utility effects (25 points)
	var card: GameCard = state.card_db.get_card(card_id)
	if not card or not card.definition: return 0.0
	for effect in card.definition.get('effects', []):
		var etype = effect.get('effect_type')
		if etype == 'draw':
			score += 12.0 * effect.get('amount', 1)
			if state.my_state.hand.size() < 5: score += 4.0
		elif etype == 'opponent_discard_random':
			score += 10.0 * effect.get('amount', 1)
			if state.opponent_state.hand.size() <= 3: score += 5.0
		elif etype == 'gain_advantage':
			score += 25.0
		elif etype == 'add_strike_to_gauge_after_cleanup':
			score += 6.0

	# Distance control (15 points)
	var my_class := _classify_character(state.my_state, state)
	var ideal_dist := _get_ideal_distance(my_class, _classify_character(state.opponent_state, state))
	for effect in card.definition.get('effects', []):
		var etype = effect.get('effect_type')
		if etype == 'close' or etype == 'advance':
			if distance > ideal_dist: score += min(effect.get('amount', 0) * 5.0, 15.0)
		elif etype == 'retreat' or etype == 'push':
			if distance < ideal_dist: score += min(effect.get('amount', 0) * 5.0, 15.0)
		elif etype == 'pull':
			if distance > ideal_dist: score += min(effect.get('amount', 0) * 4.0, 12.0)

	return score


func _score_boost(boost_action, state: AIPlayer.AIGameState) -> float:
	if boost_action == null: return 0.0
	var card_id: int = -1
	if boost_action is AIPlayer.BoostAction: card_id = boost_action.card_id
	else: return 0.0
	if card_id == -1: return 0.0

	var card: GameCard = state.card_db.get_card(card_id)
	if not card or not card.definition: return 0.0
	var boost_def = card.definition.get('boost', {})
	var effects = boost_def.get('effects', [])
	var boost_type = boost_def.get('boost_type', 'immediate')
	var distance: int = _get_distance(state)
	var score: float = 0.0

	for effect in effects:
		var etype = effect.get('effect_type', '')
		if etype == 'powerup':
			var amount = effect.get('amount', 0)
			var my_max_speed: int = 0
			for hand_id in state.my_state.hand:
				var spd = _get_card_speed(hand_id, state)
				if spd > my_max_speed: my_max_speed = spd
			var curve_speed = SPEED_CURVE.get(distance, 3)
			var opp_max_spd_pu = _opponent_can_do_now(state)["max_speed"]
			if my_max_speed > curve_speed: score += amount * 18.0
			else: score += amount * 12.0
			# Powerup is safer/more valuable when we already outspeed opponent
			if my_max_speed > opp_max_spd_pu: score += amount * 6.0
			if state.opponent_state.life <= _get_card_power(card_id, state) + amount + 3:
				score += 20.0
		elif etype == 'speedup' or etype == 'attack_is_ex':
			var amount = effect.get('amount', 1)
			score += amount * (18.0 if distance >= 2 else 10.0)
			if not _is_my_turn(state): score += 8.0
		elif etype == 'armorup' or etype == 'guardup':
			var amount = effect.get('amount', 0)
			score += amount * 10.0
			if distance <= 2: score += amount * 7.0
		elif etype == 'advance':
			var my_class := _classify_character(state.my_state, state)
			var opp_class := _classify_character(state.opponent_state, state)
			var ideal_dist := _get_ideal_distance(my_class, opp_class)
			if distance > ideal_dist: score += min(effect.get('amount', 0) * 10.0, 25.0)
			# Guerrilla bonus: boost with advance AND retreat enables hit-and-run
			var _has_retreat: bool = false
			for _e2 in effects:
				if _e2.get('effect_type') == 'retreat':
					_has_retreat = true
					break
			if _has_retreat:
				score += 12.0  # Guerrilla tactics: advance to strike, retreat to safety
			# Zigzag penalty: don't advance after retreating last turn
			if _last_move_direction == -1: score -= 15.0
		elif etype == 'retreat':
			var my_class := _classify_character(state.my_state, state)
			var opp_class := _classify_character(state.opponent_state, state)
			var ideal_dist := _get_ideal_distance(my_class, opp_class)
			if distance < ideal_dist: score += min(effect.get('amount', 0) * 10.0, 25.0)
			# Zigzag penalty: don't retreat after advancing last turn
			if _last_move_direction == 1: score -= 15.0
			
			if _opponent_can_do_now(state)["max_speed"] >= _get_card_speed(card_id, state):
				score += 5.0
		elif etype == 'push' or etype == 'pull' or etype == 'choice':
			score += 10.0
		elif etype == 'name_card_opponent_discards':
			score += 18.0
			if state.opponent_state.hand.size() <= 3: score += 10.0
		elif etype == 'opponent_wild_swings' or etype == 'opponent_wild_strikes':
			score += 16.0
			if distance >= 3: score += 8.0
		elif etype == 'draw':
			score += effect.get('amount', 1) * 12.0
			if state.my_state.hand.size() < 5: score += effect.get('amount', 1) * 4.0
		elif etype == 'discard_continuous_boost':
			# Only worth it if opponent actually has continuous boosts
			if state.opponent_state.continuous_boosts.size() == 0:
				score -= 50.0  # No opponent boosts -> total waste!
			else:
				score += 24.0  # Opponent has boosts -> high value
		elif etype == 'reading_normal':
			# Focus boost (Reading): name one of the opponent's normals, forcing them to use it
			# Hard gate: only use it when we hold a card that can hit the opponent, otherwise the boost is wasted
			var _rd_any_hits: bool = false
			for _rd_hid in state.my_state.hand:
				if can_card_hit(_rd_hid, -1, state):
					_rd_any_hits = true
					break
			if not _rd_any_hits:
				score -= 120.0
				continue
			# Boost the score substantially based on the quality of the opponent's hand
			var _opp_rd = _opponent_can_do_now(state)
			var opp_range_normals: int = 0
			var opp_has_block = false
			var opp_has_focus = false
			for cid in _visible_opponent_hand(state):
				var d = _get_def(cid, state)
				if not d: continue
				if d.get("type", "") != "normal": continue
				var rmin = d.get("range_min", 1)
				if rmin is String: rmin = 1
				var rmax = d.get("range_max", rmin + 3)
				if rmax is String: rmax = rmin + 3
				var dl = d.get("id", "").to_lower()
				if "block" in dl: opp_has_block = true
				if "focus" in dl: opp_has_focus = true
				if rmin <= distance and distance <= rmax:
					opp_range_normals += 1
			# Base score: Reading is valuable on its own
			score += 25.0
			# The fewer normals the opponent can hit with, the stronger the lock
			if opp_range_normals == 1:
				score += 50.0  # Opponent has only 1 option -> fully locked down!
			elif opp_range_normals == 2:
				score += 30.0  # Only 2 options -> strong constraint
			elif opp_range_normals >= 3:
				score += 15.0
			# Extra score: opponent has Block/Focus -> name it to nullify a key defensive card
			if opp_has_block: score += 20.0
			if opp_has_focus: score += 15.0
			# Distance factor: Reading works best at mid range
			if distance >= 2 and distance <= 3: score += 10.0

	# -- Auto-attack range check: a boost with a strike effect will attack using the boost card itself --
	for effect in effects:
		if effect.get('effect_type') == 'strike':
			var s_rmin = card.definition.get('range_min', 1)
			if s_rmin is String: s_rmin = 1
			var s_rmax = card.definition.get('range_max', s_rmin + 3)
			if s_rmax is String: s_rmax = s_rmin + 3
			if not (s_rmin <= distance and distance <= s_rmax):
				score -= 45.0  # Auto-attack is out of range (e.g. Focus range 1-2) -> the strike would whiff
			break

	# Only boost when you have a card that can hit the opponent
	var _any_card_hits: bool = false
	for _hid in state.my_state.hand:
		if can_card_hit(_hid, -1, state):
			_any_card_hits = true
			break
	if not _any_card_hits:
		score -= 25.0  # Heavy penalty: boosting without follow-up is wasteful
	if boost_type == 'continuous':
		if state.my_state.continuous_boosts.size() >= MAX_CONTINUOUS_BOOSTS: score -= 20.0
		else: score += 8.0
	var force_cost = boost_def.get('force_cost', 0)
	if force_cost > 0: score -= force_cost * 5.0
	return score


func _passes_through_opponent(target_location: int, state: AIPlayer.AIGameState) -> bool:
	var my_loc: int = state.my_state.arena_location
	var opp_loc: int = state.opponent_state.arena_location
	return (my_loc < opp_loc and target_location > opp_loc) or (my_loc > opp_loc and target_location < opp_loc)


func _score_move(move_action, state: AIPlayer.AIGameState, has_alternatives: bool = false) -> float:
	if move_action == null: return 0.0
	if not move_action is AIPlayer.MoveAction: return 0.0
	var new_distance: int = abs(move_action.location - state.opponent_state.arena_location)
	var current_distance: int = _get_distance(state)
	var my_class := _classify_character(state.my_state, state)
	var opp_class := _classify_character(state.opponent_state, state)
	var ideal_dist := _get_ideal_distance(my_class, opp_class)
	var score: float = -15.0  # Base tax: moving costs your entire turn, prefer any other action
	# If there are better alternatives (boosts/character actions), move is even worse
	if has_alternatives: score -= 20.0
	# Close range: movement wastes resources. Attacking/boosting is MUCH better.
	if current_distance <= 2:
		score -= 50.0  # Near distance movement extremely wasteful
	elif current_distance == 3:
		score -= 20.0  # Distance 3 movement still not worth it
	var current_diff: int = abs(current_distance - ideal_dist)
	var new_diff: int = abs(new_distance - ideal_dist)
	var improvement: int = current_diff - new_diff
	# Only reward significant improvements (2+ steps closer to ideal)
	if improvement >= 2: score += improvement * 15.0
	elif improvement == 1: score += 8.0  # Small improvement, small reward
	# else: staying same or getting worse, no reward
	var can_attack_now: bool = false
	var can_attack_after: bool = false
	for card_id in state.my_state.hand:
		if can_card_hit(card_id, -1, state): can_attack_now = true
	for card_id in state.my_state.hand:
		var cmin = _get_card_range_min(card_id, state)
		var cmax = _get_card_range_max(card_id, state)
		if cmin <= new_distance and new_distance <= cmax: can_attack_after = true
	# Only switch if currently cannot attack and will be able to after move
	if not can_attack_now and can_attack_after: score += 12.0
	if can_attack_now and not can_attack_after: score -= 15.0
	# Long range movement: only approach when hand > 5 AND opponent can hit you
	if current_distance >= 4:
		var my_hand_size: int = state.my_state.hand.size()
		var opp_can_hit_now: int = _analyze_opponent_at_distance(current_distance, state)["can_hit_count"]
		if my_hand_size <= 5 or opp_can_hit_now == 0:
			score -= 60.0  # Far but low hand/opponent can't hit -> no need to move
	# Zigzag penalty: don't reverse last move direction
	if _last_move_direction == 1 and new_distance > current_distance:
		score -= 20.0  # Advanced last turn, now retreating
	elif _last_move_direction == -1 and new_distance < current_distance:
		score -= 20.0  # Retreated last turn, now advancing
	# Opponent threat: compare threats at current vs new distance
	var opp_threats_now = _analyze_opponent_at_distance(current_distance, state)
	var opp_threats_new = _analyze_opponent_at_distance(new_distance, state)
	var opp_hits_now: int = opp_threats_now["can_hit_count"]
	var opp_hits_new: int = opp_threats_new["can_hit_count"]
	if opp_hits_new == 0 and opp_hits_now > 0:
		score += 25.0  # Move to safety — opponent can't hit at new position!
	elif opp_hits_new < opp_hits_now:
		score += (opp_hits_now - opp_hits_new) * 8.0  # Fewer threats
	elif opp_hits_new > opp_hits_now:
		score -= (opp_hits_new - opp_hits_now) * 10.0  # More threats — dangerous!
	# If new position exposes us to kill threat
	if opp_threats_new["can_kill_me"] and not opp_threats_now["can_kill_me"]:
		score -= 20.0  # Moving INTO kill range — very dangerous
	score -= abs(move_action.location - state.my_state.arena_location) * 4.0
	# Never pass through opponent
	if _passes_through_opponent(move_action.location, state): score -= 100.0
	return score


func _is_my_turn(state: AIPlayer.AIGameState) -> bool:
	return state.active_turn_player == state.my_state.player_id


## Returns the opponent's hand card ids for analysis. This is the single choke point for
## reading hidden information: when ALLOW_HIDDEN_INFO is true it returns the opponent's real
## hand (a cheat); when false it returns an empty array so the policy plays blind.
##
## Hidden-information call sites (all iterate the result of this helper):
##   - _opp_can_hit_at_distance()      : whether the opponent could hit at distance d
##   - _score_boost()                   : Reading/lockdown boost valuation
##   - pick_discard_opponent_gauge()    : follow-up threat evaluation
##   - pick_name_opponent_card()        : omniscient (20%) Reading naming branch
##   - _opponent_hand_counts()          : same-name (EX) counting
##   - _analyze_opponent_at_distance()  : opponent threat analysis at a target distance
##   - _try_reading_combo()             : Reading + Spike combo target selection
## Note: reads of the opponent's hand *size* (public information) are NOT gated.
func _visible_opponent_hand(state: AIPlayer.AIGameState) -> Array:
	if ALLOW_HIDDEN_INFO:
		return state.opponent_state.hand
	return []


# ============================================================
# Core Decisions
# ============================================================

func pick_turn_action(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	var state: AIPlayer.AIGameState = ai_game_state
	_sort_state = state
	var distance: int = _get_distance(state)
	var my_hand_size: int = state.my_state.hand.size()
	var opp_hand_size: int = state.opponent_state.hand.size()
	var _low_hand_bias: bool = false  # hand <= 3: suppress boost/move/strike, favor Prepare
	# Detect zigzag: record whether last turn moved closer or further
	if _last_distance >= 0:
		if distance < _last_distance: _last_move_direction = 1  # Advanced
		elif distance > _last_distance: _last_move_direction = -1  # Retreated
		else: _last_move_direction = 0  # No net move
	_last_distance = distance  # Update for next turn
	_pick_turn_count += 1
	_cache_state(state)

	# --- Omniscient: analyze opponent hand ---
	var _opp_init = _opponent_can_do_now(state)

	# The online learner was intentionally not ported (see file header). `exploring`
	# is retained as a constant-false flag so the downstream branches stay intact.
	var exploring: bool = false

	var my_class := _classify_character(state.my_state, state)
	var opp_class := _classify_character(state.opponent_state, state)
	var my_profile := _get_character_profile(state.my_state, state)
	var _opp_profile := _get_character_profile(state.opponent_state, state)
	var _ideal_dist := _get_ideal_distance(my_class, opp_class)

	# Categorize actions
	var exceed_actions := []
	var strike_actions := []
	var boost_actions := []
	var move_actions := []
	var prepare_action = null
	var character_actions := []

	for action in possible_actions:
		if action is AIPlayer.ExceedAction: exceed_actions.append(action)
		elif action is AIPlayer.StrikeAction:
			if can_card_hit(action.card_id, action.ex_card_id, state):
				if not _is_block_card(action.card_id, state): strike_actions.append(action)
		elif action is AIPlayer.BoostAction: boost_actions.append(action)
		elif action is AIPlayer.MoveAction: move_actions.append(action)
		elif action is AIPlayer.PrepareAction: prepare_action = action
		elif action is AIPlayer.CharacterActionAction: character_actions.append(action)

	# 1. KILL CHECK — opponent-aware: don't go for kill if opponent kills us first
	var opp_kill_analysis = _opponent_can_do_now(state)
	for sa in strike_actions:
		if _can_kill(sa.card_id, sa.ex_card_id, state):
			var my_speed: int = _get_card_speed(sa.card_id, state, false)
			if sa.ex_card_id != -1: my_speed += 1
			# Only go for kill if we outspeed opponent or they can't kill us back
			if my_speed >= opp_kill_analysis["max_speed"] or not opp_kill_analysis.get("can_kill_me", false):
				return sa
	# 1.5 hand <= 3: resource-starved -- greatly raise Prepare (draw) chance, suppress boost/move/strike
	# (kill chances were handled in step 1 and are unaffected; the remaining 30% normal flow keeps suppressing via _low_hand_bias)
	if my_hand_size <= 3 and prepare_action:
		if randf() < 0.7:
			return prepare_action
		_low_hand_bias = true
	# 2. FORCED CLOSE — dist≥4 + hand>5 + can't hit → must move to ≤3
	# Priority: character action with movement > boost with movement > regular move
	if distance >= 4 and my_hand_size > 5:
		var _can_any_hit: bool = false
		for _cid in state.my_state.hand:
			if can_card_hit(_cid, -1, state):
				_can_any_hit = true
				break
		if not _can_any_hit:
			# 1st: character action with move effect
			if character_actions.size() > 0:
				var _best_ca = null
				var _best_ca_score: float = -999.0
				for _ca in character_actions:
					var _s: float = _score_character_action(_ca, state)
					var _cdef = state.my_state.deck_def
					var _ca_effs: Array = _cdef.get("ability_effects", [])
					if state.my_state.exceeded: _ca_effs = _cdef.get("exceed_ability_effects", _ca_effs)
					if _ca.action_idx >= 0 and _ca.action_idx < _ca_effs.size():
						var _cab = _ca_effs[_ca.action_idx]
						var _ce = _cab.get("effect_type", "")
						if _ce == "move": _s += 20.0
					if _s > _best_ca_score: _best_ca_score = _s; _best_ca = _ca
				if _best_ca and _best_ca_score > 5.0:
					return _best_ca
			# 2nd: boost with advance/retreat toward opponent
			if boost_actions.size() > 0:
				var _best_boost = null
				var _best_boost_score: float = -999.0
				for _ba in boost_actions:
					var _bs: float = _score_boost(_ba, state)
					var _bcard = state.card_db.get_card(_ba.card_id)
					var _bdef: Dictionary = {}
					if _bcard and _bcard.definition: _bdef = _bcard.definition.get("boost", {})
					for _be in _bdef.get("effects", []):
						var _bet = _be.get("effect_type", "")
						if _bet == "advance" or _bet == "retreat":
							_bs += 25.0; break
					if _bs > _best_boost_score: _best_boost_score = _bs; _best_boost = _ba
				if _best_boost and _best_boost_score > 5.0:
					return _best_boost
			# 3rd: regular move
			if move_actions.size() > 0:
				var _best_move = null
				var _best_dist: int = 999
				for _ma in move_actions:
					if _ma is AIPlayer.MoveAction:
						if _passes_through_opponent(_ma.location, state): continue
						var _d: int = abs(_ma.location - state.opponent_state.arena_location)
						if _d <= 3 and _d < _best_dist:
							_best_dist = _d; _best_move = _ma
				if _best_move:
					return _best_move

	# 3. NO STRIKES & VERY FAR (dist > 4 only) — prefer prepare/character over blind move
	if strike_actions.size() == 0 and distance > 4:
		# Don't prepare when hand already has 5+ cards
		if prepare_action and my_hand_size <= 5: return prepare_action
		# Prefer character-ability movement -> then plain movement
		if character_actions.size() > 0:
			var __far_ca = null
			var __far_move_ca = null
			var __far_ca_score: float = -999.0
			var __far_move_ca_score: float = -999.0
			for __ca in character_actions:
				var s: float = _score_character_action(__ca, state)
				# Check whether the character ability has a movement effect
				var __is_move_ca: bool = false
				var __cdef = state.my_state.deck_def
				var __cabilities: Array = __cdef.get("ability_effects", [])
				if state.my_state.exceeded: __cabilities = __cdef.get("exceed_ability_effects", __cabilities)
				if __ca.action_idx >= 0 and __ca.action_idx < __cabilities.size():
					var __cab = __cabilities[__ca.action_idx]
					if __cab.get("effect_type", "") == "move" or __cab.get("timing", "") == "move":
						__is_move_ca = true
						s += 10.0  # Extra score for a movement ability
				if s > __far_ca_score: __far_ca_score = s; __far_ca = __ca
				if __is_move_ca and s > __far_move_ca_score: __far_move_ca_score = s; __far_move_ca = __ca
			# Prefer the movement character ability
			if __far_move_ca and __far_move_ca_score > 3.0: return __far_move_ca
			if __far_ca and __far_ca_score > 8.0: return __far_ca
		# Only move 60% of the time when far — sometimes try boost instead
		if move_actions.size() > 0 and randf() < 0.6:
			var best_move = null
			var best_dist: int = 999
			for ma in move_actions:
				if ma is AIPlayer.MoveAction:
					if _passes_through_opponent(ma.location, state): continue
					var d: int = abs(ma.location - state.opponent_state.arena_location)
					if d <= 3 and d < best_dist: best_dist = d; best_move = ma
			if best_move: return best_move
		# If not moving, try a boost (don't use Reading/Focus boost when no card in hand can hit)
		if boost_actions.size() > 0:
			var _b_any_hits: bool = false
			for _b_hid in state.my_state.hand:
				if can_card_hit(_b_hid, -1, state):
					_b_any_hits = true
					break
			if _b_any_hits or not _has_reading_boost(boost_actions[0].card_id, state):
				return boost_actions[0]
			for _ba_far in boost_actions:
				if not _has_reading_boost(_ba_far.card_id, state):
					return _ba_far
			# Only Reading (Focus) boosts left and can't hit -> rather move than waste the boost
			if move_actions.size() > 0:
				for _ma_far in move_actions:
					if not _passes_through_opponent(_ma_far.location, state):
						return _ma_far
			return boost_actions[0]

	# 3. SCORE STRIKES
	var scored_strikes := []
	_sort_key = "attack"
	for sa in strike_actions:
		scored_strikes.append({"action": sa, "score": _score_strike(sa.card_id, sa.ex_card_id, state, false)})
	if scored_strikes.size() > 0:
		scored_strikes.sort_custom(_sort_by_score_desc)

	# 4. READING + SPIKE COMBO — Focus boost -> name opponent card -> penetrating strike
	# This uses the Standard Focus Reading boost to name opponent's best normal
	# (Block/Focus/Fast card), then immediately strikes with Spike to penetrate.
	if boost_actions.size() > 0 and strike_actions.size() > 0 and not _low_hand_bias:
		# With hand <= 3, skip the Reading combo (lowers boost+strike chance, favors Prepare)
		var reading_combo = _try_reading_combo(state, boost_actions, strike_actions)
		if reading_combo != null:
			return reading_combo

	# 5. UNILATERAL HIT — opponent has no cards that can hit at current range
	var opp_analysis_unilateral = _opponent_can_do_now(state)
	if opp_analysis_unilateral["can_hit_count"] == 0 and scored_strikes.size() > 0:
		var best_unilateral = scored_strikes[0]
		if best_unilateral["score"] > 5.0:
			return best_unilateral["action"]

	# 6. EXCEED — threshold varies by character aggression
	var exceed_threshold: int = 6
	if my_profile["aggro_score"] >= 0.8: exceed_threshold = 5  # rushdown
	elif my_profile["aggro_score"] <= 0.3: exceed_threshold = 7  # zoner
	if my_profile["has_critical"]: exceed_threshold -= 1  # more value from exceed
	# Don't waste exceed on opponent without boosts unless it enables a kill
	if state.opponent_state.continuous_boosts.size() == 0 and exceed_actions.size() > 0:
		var _exceed_for_kill: bool = false
		for _sa in strike_actions:
			if _can_kill(_sa.card_id, _sa.ex_card_id, state):
				_exceed_for_kill = true
				break
		if not _exceed_for_kill:
			exceed_threshold += 2  # Save exceed for when opponent invests in boosts
	if exceed_actions.size() > 0 and my_hand_size >= exceed_threshold: return exceed_actions[0]

	# 7. CHARACTER ACTION
	if character_actions.size() > 0:
		var __sp_best_ca = null
		var __sp_best_ca_score: float = -999.0
		for __sp_ca in character_actions:
			var __sp_ca_score: float = _score_character_action(__sp_ca, state)
			if __sp_ca_score > __sp_best_ca_score:
				__sp_best_ca_score = __sp_ca_score
				__sp_best_ca = __sp_ca
		if __sp_best_ca and __sp_best_ca_score > 5.0:
			return __sp_best_ca

	# 8. THREAT — defend if opponent near death
	if state.opponent_state.life <= 6 and opp_hand_size > 0:
		for sa in strike_actions:
			var sid = _get_card_id_str(sa.card_id, state)
			if "block" in sid or "focus" in sid: return sa

	# 8.5 CANT REACH — if no card in hand can hit, try to move closer without passing through
	var _any_card_can_hit: bool = false
	for _cid in state.my_state.hand:
		if can_card_hit(_cid, -1, state):
			_any_card_can_hit = true
			break
	if not _any_card_can_hit and not _passes_through_opponent(state.my_state.arena_location - 1 if state.my_state.arena_location > state.opponent_state.arena_location else state.my_state.arena_location + 1, state):
		# 0th priority: with few cards, prefer Prepare instead of spending force on move/boost
		if _low_hand_bias and prepare_action:
			return prepare_action
		# 1st priority: boost with advance/retreat towards opponent
		if boost_actions.size() > 0:
			var _best_move_boost = null
			var _best_move_boost_score: float = -999.0
			for _ba in boost_actions:
				var _bscore: float = _score_boost(_ba, state)
				var _bcard = state.card_db.get_card(_ba.card_id)
				var _bdef: Dictionary = {}
				if _bcard and _bcard.definition: _bdef = _bcard.definition.get("boost", {})
				var _beffects = _bdef.get("effects", [])
				for _be in _beffects:
					var _betype = _be.get("effect_type", "")
					if _betype == "advance" or _betype == "retreat":
						_bscore += 15.0  # Bonus for movement boost
						break
				if _bscore > _best_move_boost_score:
					_best_move_boost_score = _bscore; _best_move_boost = _ba
			if _best_move_boost and _best_move_boost_score > 10.0:
				return _best_move_boost
		# 2nd priority: character action with movement
		if character_actions.size() > 0:
			var _best_move_ca = null
			var _best_move_ca_score: float = -999.0
			for _ca in character_actions:
				var _cscore: float = _score_character_action(_ca, state)
				var _cdef = state.my_state.deck_def
				var _cabilities: Array = _cdef.get("ability_effects", [])
				if state.my_state.exceeded: _cabilities = _cdef.get("exceed_ability_effects", _cabilities)
				if _ca.action_idx >= 0 and _ca.action_idx < _cabilities.size():
					var _cab = _cabilities[_ca.action_idx]
					var _catiming = _cab.get("timing", "")
					var _caeff = _cab.get("effect_type", "")
					if _caeff == "move" or _catiming == "move":
						_cscore += 25.0
				if _cscore > _best_move_ca_score:
					_best_move_ca_score = _cscore; _best_move_ca = _ca
			if _best_move_ca and _best_move_ca_score > 5.0:
				return _best_move_ca
		# 3rd priority: regular move (closer, not through opponent)
		if move_actions.size() > 0:
			var _best_plain_move = null
			var _best_plain_move_score: float = -999.0
			for _ma in move_actions:
				if _passes_through_opponent(_ma.location, state): continue
				var _mscore: float = _score_move(_ma, state, false)
				if _mscore > _best_plain_move_score:
					_best_plain_move_score = _mscore; _best_plain_move = _ma
			if _best_plain_move and _best_plain_move_score > -50.0:
				return _best_plain_move

	# 9. FREQUENCY-BASED SELECTION (with opponent-aware adjustments)
	var opp_freq = _opponent_can_do_now(state)
	# 9a. Opponent can't hit at all → strike aggressively
	if opp_freq["can_hit_count"] == 0 and scored_strikes.size() > 0 and scored_strikes[0]['score'] > 5.0:
		return scored_strikes[0]['action']
	# 9b. Opponent can kill us → prioritize defense
	if opp_freq["can_kill_me"] and scored_strikes.size() > 0:
		# Look for a strike with high guard or Block
		for ss in scored_strikes:
			var sid = _get_card_id_str(ss['action'].card_id, state).to_lower()
			if "block" in sid or _get_card_guard(ss['action'].card_id, state) >= 4:
				return ss['action']
	# 9c. Opponent is near death and we can finish → strike
	if state.opponent_state.life <= 5 and scored_strikes.size() > 0:
		for ss in scored_strikes:
			if _can_kill(ss['action'].card_id, ss['action'].ex_card_id, state):
				return ss['action']

	if exploring:
		# Exploration: pick random valid action
		var all_valid := []
		if scored_strikes.size() > 0: all_valid.append_array(scored_strikes)
		if boost_actions.size() > 0:
			var sb := []
			for ba in boost_actions: sb.append({"action": ba, "score": _score_boost(ba, state)})
			all_valid.append_array(sb)
		if move_actions.size() > 0:
			for ma in move_actions:
				if not _passes_through_opponent(ma.location, state):
					var __has_alt = (boost_actions.size() > 0 or character_actions.size() > 0)
					all_valid.append({"action": ma, "score": _score_move(ma, state, __has_alt)})
		if prepare_action: all_valid.append({"action": prepare_action, "score": 0.0})
		if character_actions.size() > 0:
			for ca in character_actions: all_valid.append({"action": ca, "score": _score_character_action(ca, state)})
		if all_valid.size() > 0: return all_valid[randi() % all_valid.size()]['action']

	var has_strike: bool = scored_strikes.size() > 0 and scored_strikes[0]['score'] >= 12.0
	var has_boost: bool = false
	if boost_actions.size() > 0 and state.my_state.continuous_boosts.size() < MAX_CONTINUOUS_BOOSTS:
		for ba in boost_actions:
			if _score_boost(ba, state) > 5.0: has_boost = true; break

	var roll: float = randf()
	if my_hand_size <= 3:
		# LOW HAND (<= 3 cards): greatly raise Prepare chance, suppress strike/boost (but still keep a chance to act)
		if roll < 0.5 and has_strike: return scored_strikes[0]['action']
		elif roll < 0.65 and has_boost:
			var sb := []
			for ba in boost_actions: sb.append({"action": ba, "score": _score_boost(ba, state)})
			sb.sort_custom(_sort_by_score_desc)
			return sb[0]['action']
		elif prepare_action: return prepare_action
		elif has_strike: return scored_strikes[0]['action']
	elif my_hand_size < 5:
		if roll < 0.3 and has_strike: return scored_strikes[0]['action']
		elif roll < 0.5 and has_boost:
			var sb := []
			for ba in boost_actions: sb.append({"action": ba, "score": _score_boost(ba, state)})
			sb.sort_custom(_sort_by_score_desc)
			return sb[0]['action']
		elif prepare_action: return prepare_action
		elif has_strike: return scored_strikes[0]['action']
	else:
		# Hand >= 5: reduce prepare, prefer boost and character actions
		if roll < 0.50 and has_strike: return scored_strikes[0]['action']
		elif roll < 0.78 and has_boost:
			var sb := []
			for ba in boost_actions: sb.append({"action": ba, "score": _score_boost(ba, state)})
			sb.sort_custom(_sort_by_score_desc)
			return sb[0]['action']
		elif roll < 0.90 and character_actions.size() > 0:
			var __hca = null; var __hca_score: float = -999.0
			for __ca in character_actions:
				var s: float = _score_character_action(__ca, state)
				if s > __hca_score: __hca_score = s; __hca = __ca
			if __hca and __hca_score > 3.0:
				return __hca
			if has_strike: return scored_strikes[0]['action']
		elif has_strike: return scored_strikes[0]['action']

	# 10. FALLBACK
	if scored_strikes.size() > 0: return scored_strikes[0]['action']
	# Low hand: prepare before boost to refill cards
	if my_hand_size < 4 and prepare_action: return prepare_action
	if boost_actions.size() > 0: return boost_actions[randi() % boost_actions.size()]
	if prepare_action and my_hand_size <= 5: return prepare_action
	# Prefer character-ability movement -> then plain movement
	if character_actions.size() > 0:
		var __fb_move_ca = null; var __fb_move_score: float = -999.0
		var __fb_best_ca = null; var __fb_best_score: float = -999.0
		for __fb_ca in character_actions:
			var s: float = _score_character_action(__fb_ca, state)
			# Detect movement effect
			var __fb_is_move: bool = false
			var __fb_cdef = state.my_state.deck_def
			var __fb_cabilities: Array = __fb_cdef.get("ability_effects", [])
			if state.my_state.exceeded: __fb_cabilities = __fb_cdef.get("exceed_ability_effects", __fb_cabilities)
			if __fb_ca.action_idx >= 0 and __fb_ca.action_idx < __fb_cabilities.size():
				var __fb_cab = __fb_cabilities[__fb_ca.action_idx]
				if __fb_cab.get("effect_type", "") == "move" or __fb_cab.get("timing", "") == "move":
					__fb_is_move = true
					s += 8.0
			if __fb_is_move and s > __fb_move_score: __fb_move_score = s; __fb_move_ca = __fb_ca
			if s > __fb_best_score: __fb_best_score = s; __fb_best_ca = __fb_ca
		# Prefer returning the movement character ability
		if __fb_move_ca: return __fb_move_ca
		return __fb_best_ca
	# Move is last resort
	if move_actions.size() > 0:
		var __fallback_moves := []
		for __ma in move_actions:
			if not _passes_through_opponent(__ma.location, state): __fallback_moves.append(__ma)
		if __fallback_moves.size() > 0:
			__fallback_moves.sort_custom(_sort_move_by_score)
			return __fallback_moves[0]
		# All moves pass through opponent - pick any non-move action if possible
		if scored_strikes.size() > 0: return scored_strikes[0]["action"]
		if boost_actions.size() > 0: return boost_actions[randi() % boost_actions.size()]
	return possible_actions[randi() % possible_actions.size()]



func _score_character_action(ca, state: AIPlayer.AIGameState) -> float:
	## Score character ability based on situation. Only use when conditions are right.
	var score: float = 0.0
	var char_def = state.my_state.deck_def
	var ability_list: Array = char_def.get("ability_effects", [])
	if state.my_state.exceeded: ability_list = char_def.get("exceed_ability_effects", ability_list)
	if ca.action_idx < 0 or ca.action_idx >= ability_list.size():
		return 0.0
	var ab_eff = ability_list[ca.action_idx]
	var timing = ab_eff.get("timing", "")
	var eff_type = ab_eff.get("effect_type", "")
	# Heal/recovery: use when actually low on life
	if eff_type == "heal" or eff_type == "recover_cards":
		var life_pct: float = float(state.my_state.life) / float(state.my_state.max_life)
		if life_pct < 0.4: score += 20.0 * (1.0 - life_pct)
		elif life_pct < 0.6: score += 8.0
		else: return 0.0  # Don't waste heal when healthy
	# Draw/card advantage: use when hand is small or need resources
	if eff_type == "draw" or eff_type == "card_draw":
		if state.my_state.hand.size() <= 3: score += 12.0
		elif state.my_state.hand.size() <= 5: score += 6.0
		else: score += 2.0  # Still OK but less urgent
	# Force generation: use when low on gauge or not exceeded
	if eff_type == "generate_force" or timing == "generate_force":
		if not state.my_state.exceeded: score += 10.0  # Need force to exceed
		elif state.my_state.gauge.size() < 2: score += 7.0
		else: score += 3.0
	# Movement: character-ability movement takes priority over plain movement
	if eff_type == "move" or timing == "move":
		var my_class := _classify_character(state.my_state, state)
		var opp_class := _classify_character(state.opponent_state, state)
		var ideal_dist := _get_ideal_distance(my_class, opp_class)
		var dist: int = _get_distance(state)
		var dist_diff: int = abs(dist - ideal_dist)
		if dist_diff >= 3: score += 40.0
		elif dist_diff >= 2: score += 28.0
		elif dist_diff >= 1: score += 18.0
		else: score += 5.0  # Usable even at the ideal distance (comes with other effects)
	# Gauge generation: use when actually low on gauge
	if eff_type == "generate_gauge":
		if state.my_state.gauge.size() == 0: score += 12.0
		elif state.my_state.gauge.size() < 2: score += 7.0
		else: score += 2.0
	# Boost-related: use when boost slots available
	if eff_type == "boost" or timing == "boost":
		if state.my_state.continuous_boosts.size() < 2: score += 10.0
		elif state.my_state.continuous_boosts.size() < 3: score += 5.0
		else: score += 1.0
	# Hand size: can we afford the cards?
	if state.my_state.hand.size() >= 5: score += 3.0
	elif state.my_state.hand.size() < 3: score -= 5.0  # Too risky
	# Never burn Ultra cards for force cost
	var force_cost = ab_eff.get("force_cost", 0)
	if force_cost > 0 and ca.card_ids.size() > 0:
		for cid in ca.card_ids:
			var cdef = _get_def(cid, state)
			if cdef and cdef.get('type') == 'ultra': score -= 15.0
	return score

func pick_strike(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	var state: AIPlayer.AIGameState = ai_game_state
	_sort_state = state; _sort_key = "attack"
	var valid_strikes := []
	for action in possible_actions:
		if action is AIPlayer.StrikeAction:
			if can_card_hit(action.card_id, action.ex_card_id, state):
				if not _is_block_card(action.card_id, state): valid_strikes.append(action)
	if valid_strikes.size() == 0:
		for action in possible_actions:
			if action is AIPlayer.StrikeAction and action.wild_swing: return action
		return possible_actions[randi() % possible_actions.size()]
	var scored := []
	for sa in valid_strikes:
		scored.append({"action": sa, "score": _score_strike(sa.card_id, sa.ex_card_id, state, false)})
	scored.sort_custom(_sort_by_score_desc)
	return scored[0]['action']


func pick_strike_response(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	var state: AIPlayer.AIGameState = ai_game_state
	_sort_state = state
	var distance: int = _get_distance(state)
	var valid_strikes := []
	var wild_action = null

	for action in possible_actions:
		if action is AIPlayer.StrikeAction:
			if action.wild_swing: wild_action = action; continue
			if can_card_hit(action.card_id, action.ex_card_id, state):
				valid_strikes.append(action)

	# OMNISCIENT: Analyze the opponent's COMMITTED strike card
	var opp_strike = _analyze_opponent_strike(state)
	var opp_speed: int = opp_strike["speed"]
	var opp_power: int = opp_strike["power"]
	var opp_guard: int = opp_strike["guard"]

	if valid_strikes.size() == 0:
		# No card can hit opponent at this distance
		# Analyze opponent's strike to try retreat dodge
		if opp_strike["has_strike"] and distance >= 2:
			# Try to find cards with retreat effect to dodge
			var dodge_cards := []
			for action in possible_actions:
				if action is AIPlayer.StrikeAction and not action.wild_swing:
					var _dd = _get_def(action.card_id, state)
					if not _dd: continue
					for eff in _dd.get("effects", []):
						if eff.get("effect_type") == "retreat":
							var retreat_amt = eff.get("amount", 3)
							var my_spd = _get_card_speed(action.card_id, state, true)
							if action.ex_card_id != -1: my_spd += 1
							# Must outspeed opponent to retreat before they hit
							if my_spd > opp_strike["speed"]:
								# Calculate post-retreat position
								var my_loc = state.my_state.arena_location
								var opp_loc = state.opponent_state.arena_location
								var after_loc: int
								if my_loc < opp_loc:
									after_loc = my_loc - retreat_amt
									if after_loc < 0: after_loc = 0
								else:
									after_loc = my_loc + retreat_amt
								var new_dist = abs(after_loc - opp_loc)
								# Dodge works if new distance is outside opponent's range
								var _orng_min = opp_strike["range_min"]
								var _orng_max = opp_strike["range_max"]
								if new_dist > _orng_max or new_dist < _orng_min:
									dodge_cards.append({"action": action, "new_dist": new_dist, "speed": my_spd, "retreat": retreat_amt})
									break  # Found retreat effect, stop checking effects
			if dodge_cards.size() > 0:
				dodge_cards.sort_custom(func(a, b): return a["new_dist"] > b["new_dist"])
				var _best = dodge_cards[0]
				return _best["action"]
		# Cannot dodge: wild swing as last resort
		if wild_action: return wild_action
		return possible_actions[randi() % possible_actions.size()]


	if not opp_strike["has_strike"]:
		var _ns_scored := []
		_sort_key = "response"
		for _ns_sa in valid_strikes:
			_ns_scored.append({"action": _ns_sa, "score": _score_strike(_ns_sa.card_id, _ns_sa.ex_card_id, state, true)})
		_ns_scored.sort_custom(_sort_by_score_desc)
		return _ns_scored[0]["action"]

	# ================================================================
	# Opponent plays a slow, high-power, high-guard heavy card (Sweep/Dust/Spike) -> evaluate all 4 counter approaches:
	#   1. High-guard high-power clash: tank the damage with guard, hit back with high power
	#   2. Fast card, slight loss trade: strike first for a bit, a small net loss (<=3 life) is acceptable to gain tempo
	#   3. First-strike stun: we're faster (e.g. Spike speed3 > Sweep speed2) and ignore-guard hits -> hit first and stun, voiding the opponent's whole card
	#   4. Cross retreat 3 to leave the opponent's range / Dive pass-through dodge: avoid big damage + on-hit effects
	# Measure all candidate cards uniformly by value trade (net life swing), then add card-advantage/stun/dodge corrections
	# ================================================================
	if _is_slow_power_card(opp_strike):
		var opp_def: Dictionary = opp_strike["defn"].duplicate(true)
		opp_def["speed"] = opp_strike["speed"]
		opp_def["power"] = opp_strike["power"]
		opp_def["guard"] = opp_strike["guard"]
		var best_counter = null
		var best_counter_score: float = -99999.0
		var best_counter_stunned: bool = false
		for action in possible_actions:
			if not (action is AIPlayer.StrikeAction) or action.wild_swing: continue
			var my_def = _get_def(action.card_id, state)
			if not my_def: continue
			# Simulate using effective stats that include boosts/EX
			var sim_def: Dictionary = my_def.duplicate(true)
			var _spd: int = _get_card_speed(action.card_id, state, true)
			if action.ex_card_id != -1: _spd += 1
			var _pwr: int = _get_card_power(action.card_id, state)
			if action.ex_card_id != -1: _pwr += 1
			var _grd: int = _get_card_guard(action.card_id, state)
			if action.ex_card_id != -1: _grd += 1
			sim_def["speed"] = _spd
			sim_def["power"] = _pwr
			sim_def["guard"] = _grd
			var sim: Dictionary = _eval_counter_response(sim_def, opp_def, distance, true)
			var score: float = float(sim["exchange"])
			# Card-advantage correction: opponent hit discards my card -> card loss; my hit discards their card -> card gain
			if sim["opp_hit"] and _def_has_effect(opp_def, "opponent_discard_random"):
				score -= 3.0
			if sim["my_hit"] and _def_has_effect(sim_def, "opponent_discard_random"):
				score += 3.0
			# Positioning correction for the 4 approaches: when value trades are close, prefer first-strike stun / dodge / slight-loss trade
			# Stun bonus only when the opponent dealt no damage (hit first and stun, voiding their whole card); if they already resolved, stun gives nothing
			if sim["stunned"] and not sim["opp_hit"]: score += 2.0
			if sim["dodged"]: score += 2.0
			if sim["exchange"] >= -3 and sim["my_hit"] and _spd > opp_strike["speed"]:
				score += 1.0   # Approach 2: fast trade, a slight loss is acceptable
			# On ties prefer first-strike stun (approach 3) over dodging (approach 4): stun voids the opponent's whole card
			if score > best_counter_score or (score == best_counter_score and sim["stunned"] and not best_counter_stunned):
				best_counter_score = score
				best_counter = action
				best_counter_stunned = sim["stunned"]
		if best_counter != null:
			return best_counter

	# ================================================================
	# THREE SPEED-TIER COUNTER STRATEGIES
	# Tier: HIGH >=6 | MEDIUM 4-5 | LOW <=3
	# Case 1: Opponent HIGH speed -> LOW spd + HIGH guard (absorb, hit back)
	# Case 2: Opponent MEDIUM speed -> HIGH speed (outspeed, stun first)
	# Case 3: Opponent LOW speed -> HIGH trade / MEDIUM pierce+retreat / LOW trade
	# ================================================================

	# Classify each valid strike by speed tier
	var high_speed_strikes := []   # speed >= 6
	var med_speed_strikes := []    # speed 4-5
	var low_speed_strikes := []    # speed <= 3
	var high_guard_strikes := []   # guard >= 4

	for sa in valid_strikes:
		var spd = _get_card_speed(sa.card_id, state, true)
		if sa.ex_card_id != -1: spd += 1
		var grd = _get_card_guard(sa.card_id, state)
		var pwr = _get_card_power(sa.card_id, state)
		var has_ia = _card_has_ignore_armor(sa.card_id, state)
		var sid = _get_card_id_str(sa.card_id, state).to_lower()
		var has_ig = _card_has_ignore_guard(sa.card_id, state)
		var has_ret = "cross" in sid
		var has_igr = has_ia or has_ig

		var info := {
			"action": sa, "speed": spd, "guard": grd, "power": pwr,
			"has_ignore": has_igr, "has_ig": has_ig, "has_retreat": has_ret,
			"card_id_str": sid,
		}

		if spd >= 6: high_speed_strikes.append(info)
		elif spd >= 4: med_speed_strikes.append(info)
		else: low_speed_strikes.append(info)

		if grd >= 4: high_guard_strikes.append(info)

	# ================================================================
	# CASE 1: Opponent HIGH speed (>=6) -> LOW speed + HIGH guard
	# Grasp(7)/Cross(6) power=3 -> guard 4+ absorbs completely
	# ================================================================
	if opp_speed >= 6:
		var tank_counters := []
		for info in low_speed_strikes + med_speed_strikes:
			if info["guard"] >= 3:
				tank_counters.append(info)
		if tank_counters.size() > 0:
			tank_counters.sort_custom(func(a, b): return a["guard"] > b["guard"])
			var best = tank_counters[0]
			return best["action"]
		# Fallback: any high guard
		if high_guard_strikes.size() > 0:
			high_guard_strikes.sort_custom(func(a, b): return a["guard"] > b["guard"])
			return high_guard_strikes[0]["action"]

	# ================================================================
	# CASE 2: Opponent MEDIUM speed (4-5) -> HIGH speed to stun first
	# Assault(5)/Dive(4) -> outspeed with Grasp(7)/Cross(6)
	# ================================================================
	if opp_speed >= 4 and opp_speed <= 5:
		var stun_counters := []
		for info in high_speed_strikes:
			if info["speed"] > opp_speed and info["power"] > opp_guard:
				stun_counters.append(info)
		if stun_counters.size() > 0:
			stun_counters.sort_custom(func(a, b): return a["speed"] > b["speed"] if a["speed"] != b["speed"] else a["power"] > b["power"])
			var best = stun_counters[0]
			return best["action"]
		# Can't stun: at least outspeed and hit
		var outspeed := []
		for info in high_speed_strikes:
			if info["speed"] > opp_speed:
				outspeed.append(info)
		if outspeed.size() > 0:
			outspeed.sort_custom(func(a, b): return a["speed"] > b["speed"] if a["speed"] != b["speed"] else a["power"] > b["power"])
			return outspeed[0]["action"]
		# Fallback: high guard
		if high_guard_strikes.size() > 0:
			high_guard_strikes.sort_custom(func(a, b): return a["guard"] > b["guard"])
			return high_guard_strikes[0]["action"]

	# ================================================================
	# CASE 3: Opponent LOW speed (<=3) -> three options
	#   3a: HIGH speed trade (outspeed, get damage)
	#   3b: MEDIUM speed + pierce/retreat to interrupt
	#   3c: LOW speed trade (match speed, win with power/guard)
	# ================================================================
	if opp_speed <= 3:
		# 3s: first-strike stun -- we're faster (e.g. Spike speed3 > Sweep speed2) with ignore-guard/high damage -> hit first and stun
		# Even if the opponent's slow card isn't a 'slow heavy card' (e.g. guard < 4), as long as it's slower, an ignore-guard card can first-strike stun and void it entirely
		var stun_firsters := []
		for info in low_speed_strikes + med_speed_strikes + high_speed_strikes:
			if info["speed"] > opp_speed and (info["has_ig"] or info["power"] > opp_guard):
				stun_firsters.append(info)
		if stun_firsters.size() > 0:
			stun_firsters.sort_custom(func(a, b): return a["speed"] > b["speed"] if a["speed"] != b["speed"] else a["power"] > b["power"])
			var _sf_best = stun_firsters[0]
			return _sf_best["action"]

		# 3a: HIGH speed trade
		var fast_traders := []
		for info in high_speed_strikes:
			if info["speed"] > opp_speed:
				fast_traders.append(info)
		if fast_traders.size() > 0:
			fast_traders.sort_custom(func(a, b): return a["speed"] > b["speed"] if a["speed"] != b["speed"] else a["power"] > b["power"])
			var best = fast_traders[0]
			return best["action"]

		# 3b: MEDIUM speed + pierce/retreat to interrupt
		var disruptors := []
		for info in med_speed_strikes:
			if info["speed"] > opp_speed and (info["has_ignore"] or info["has_retreat"]):
				disruptors.append(info)
		if disruptors.size() > 0:
			disruptors.sort_custom(func(a, b): return a["speed"] > b["speed"] if a["speed"] != b["speed"] else a["power"] > b["power"])
			var best = disruptors[0]
			return best["action"]

		# 3c: LOW speed trade
		var slow_traders := []
		for info in low_speed_strikes:
			slow_traders.append(info)
		if slow_traders.size() > 0:
			slow_traders.sort_custom(func(a, b):
				var a_score = (10 if a["guard"] >= opp_power else 0) + (10 if a["power"] > opp_guard else 0) + a["power"]
				var b_score = (10 if b["guard"] >= opp_power else 0) + (10 if b["power"] > opp_guard else 0) + b["power"]
				return a_score > b_score
			)
			var best = slow_traders[0]
			return best["action"]

	# Fallback: best scored strike
	var _fb_scored := []
	_sort_key = "response"
	for _fb_sa in valid_strikes:
		_fb_scored.append({"action": _fb_sa, "score": _score_strike(_fb_sa.card_id, _fb_sa.ex_card_id, state, true)})
	_fb_scored.sort_custom(_sort_by_score_desc)
	return _fb_scored[0]["action"]


func pick_boost_action(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var scored := []
	for action in possible_actions: scored.append({"action": action, "score": _score_boost(action, ai_game_state)})
	scored.sort_custom(_sort_by_score_desc)
	return scored[0]['action']


func pick_pay_strike_force_cost(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	_sort_state = state
	var _distance: int = _get_distance(state)

	# Precompute: which cards are the ONLY one of their type in hand?
	var hand_card_types: Dictionary = {}
	for cid in state.my_state.hand:
		var dl = _get_card_id_str(cid, state).to_lower()
		if dl == "gg_normal_dust": dl = "gg_normal_spike"  # Dust = same card as Spike
		for keyword in ["spike", "sweep", "focus", "grasp", "assault", "cross", "dive", "block"]:
			if keyword in dl:
				hand_card_types[keyword] = hand_card_types.get(keyword, 0) + 1
	# Also track special/ultra uniqueness
	for cid in state.my_state.hand:
		var cdef = _get_def(cid, state)
		if not cdef: continue
		var card_type = cdef.get("type", "")
		if card_type in ["special", "ultra"]:
			hand_card_types[card_type] = hand_card_types.get(card_type, 0) + 1

	var scored := []
	for action in possible_actions:
		var penalty: float = 0.0
		if action is AIPlayer.PayStrikeCostAction:
			for cid in action.card_ids:
				var card_score: float = _score_strike(cid, -1, state, false)
				# BASE: 60% of card's strike score — properly values keeping good cards
				penalty += card_score * 0.6
				# Cards that can hit at current distance are MORE valuable to keep
				if can_card_hit(cid, -1, state):
					penalty += card_score * 0.25  # Extra 25% for usable cards
				else:
					penalty -= card_score * 0.15  # Discount for out-of-range cards
				# Check uniqueness: if this is the ONLY card of its type, extra penalty
				var dl = _get_card_id_str(cid, state).to_lower()
				if dl == "gg_normal_dust": dl = "gg_normal_spike"  # Dust = same card as Spike
				for keyword in ["spike", "sweep", "focus", "grasp"]:
					if keyword in dl and hand_card_types.get(keyword, 0) <= 1:
						penalty += 25.0  # Heavy penalty: only Spike/Sweep/Focus/Grasp in hand!
						break
				# Special/Ultra cards are very valuable, don't discard lightly
				var cdef = _get_def(cid, state)
				if cdef:
					var card_type = cdef.get("type", "")
					if card_type == "special":
						if hand_card_types.get("special", 0) <= 1:
							penalty += 30.0  # Only special — preserve it!
						else:
							penalty += 15.0
					elif card_type == "ultra":
						penalty += 40.0  # NEVER discard ultra lightly
				# Block cards are lower priority for offense
				if "block" in dl:
					penalty -= 8.0  # Block is less valuable when striking
			if action.wild_swing: penalty += 15.0
		scored.append({"action": action, "penalty": penalty})
	scored.sort_custom(_sort_by_penalty_asc)
	return scored[0]['action']


func pick_pay_strike_gauge_cost(possible_actions: Array, _ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.PayStrikeCostAction: scored.append({"action": action, "count": action.card_ids.size()})
	if scored.size() > 0: scored.sort_custom(_sort_by_count_asc); return scored[0]['action']
	return possible_actions[randi() % possible_actions.size()]


func _get_card_discard_priority(card_id: int, state: AIPlayer.AIGameState) -> int:
	var distance: int = _get_distance(state)
	if not can_card_hit(card_id, -1, state): return 100
	if _is_block_card(card_id, state): return -10
	var speed: int = _get_card_speed(card_id, state)
	if speed >= SPEED_CURVE.get(distance, 4): return -5
	return 50 - speed * 3 - _get_card_power(card_id, state) * 2

func pick_choose_to_discard(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.ChooseToDiscardAction:
			var total_priority: int = 0
			for cid in action.card_ids: total_priority += _get_card_discard_priority(cid, state)
			scored.append({"action": action, "score": total_priority})
	if scored.size() > 0: scored.sort_custom(_sort_by_score_desc); return scored[0]['action']
	return possible_actions[randi() % possible_actions.size()]


func pick_discard_to_max(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	return pick_choose_to_discard(possible_actions, ai_game_state)


func pick_effect_choice(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	# Movement-effect safety gate: push/pull/advance/retreat/close -- don't execute moves that enter the opponent's attack range; prefer moves that escape it
	var _glogic = state.true_original()
	var _choices: Array = []
	if _glogic and _glogic.decision_info and _glogic.decision_info.choice:
		_choices = _glogic.decision_info.choice
	if _choices.size() > 0:
		var _d: int = _get_distance(state)
		var _in_danger_now: bool = _opp_can_hit_at_distance(_d, state)
		var _escapes := []    # options that escape the opponent's attack range
		var _enters := []     # options that enter the opponent's attack range
		var _kept := []       # remaining options (including non-movement effects)
		for i in range(min(possible_actions.size(), _choices.size())):
			var ch = _choices[i]
			var _nd: int = _movement_effect_new_distance(ch, _d)
			if _nd >= 0:
				var _in_danger_after: bool = _opp_can_hit_at_distance(_nd, state)
				if _in_danger_now and not _in_danger_after:
					_escapes.append({"idx": i, "d": _nd})
				elif not _in_danger_now and _in_danger_after:
					_enters.append({"idx": i, "d": _nd})
				else:
					_kept.append(i)
			else:
				_kept.append(i)
		# 1) Can escape the opponent's attack range -> execute, the further the better
		if _escapes.size() > 0:
			_escapes.sort_custom(func(a, b): return a["d"] > b["d"])
			return possible_actions[_escapes[0]["idx"]]
		# 2) Would enter the opponent's attack range -> skip (unless all options enter, then pick the shallowest)
		if _kept.size() > 0:
			# Run the original logic on safe options: Season 2 prefers transform, otherwise random
			if state.my_state.deck_def.get("season", 0) == 2:
				for i in _kept:
					var ch = _choices[i]
					if not (ch is Dictionary): continue
					var et = ch.get("effect_type", "")
					if et in ["add_to_transforms", "transform_attack"]:
						return possible_actions[i]
					var _and = ch.get("and", {})
					if _and is Dictionary and _and.get("effect_type", "") in ["add_to_transforms", "transform_attack"]:
						return possible_actions[i]
			return possible_actions[_kept[randi() % _kept.size()]]
		_enters.sort_custom(func(a, b): return a["d"] > b["d"])
		return possible_actions[_enters[0]["idx"]]
	# Season 2: prefer transform over gauge
	if state.my_state.deck_def.get("season", 0) == 2:
		var game_logic = state.true_original()
		if game_logic and game_logic.has_method("get_decision_info"):
			var dinfo = game_logic.decision_info
			if dinfo and dinfo.effect:
				var effect = dinfo.effect
				if effect.get("effect_type") == "choice":
					var choices = effect.get("choice", [])
					for j in range(min(possible_actions.size(), choices.size())):
						var ch = choices[j]
						if not (ch is Dictionary): continue
						var et = ch.get("effect_type", "")
						if et in ["add_to_transforms", "transform_attack"]:
							return possible_actions[j]
						var _and = ch.get("and", {})
						if _and is Dictionary and _and.get("effect_type", "") in ["add_to_transforms", "transform_attack"]:
							return possible_actions[j]
	return possible_actions[randi() % possible_actions.size()]
func pick_force_for_armor(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state

	# Payment mode: "force" (pay by discarding) or "gauge" (pay from gauge, each gauge card = 1 force)
	var _is_gauge_mode: bool = false
	var _glogic = state.true_original()
	if _glogic and _glogic.decision_info and _glogic.decision_info.limitation == "gauge":
		_is_gauge_mode = true

	# Minimal payment (fallback): 0 force = 0 cards
	var _min_action = null; var _min_cnt: int = 999
	for action in possible_actions:
		if action is AIPlayer.ForceForArmorAction:
			if action.card_ids.size() < _min_cnt: _min_cnt = action.card_ids.size(); _min_action = action
	if not _min_action: return possible_actions[0]

	# No ongoing strike (or opponent hasn't revealed) -> minimal payment
	var opp_strike_ffa = _analyze_opponent_strike(state)
	if not opp_strike_ffa["has_strike"]:
		return _min_action

	# 1) Check whether the opponent's played card ignores armor -> if so, don't pay force for armor (armor is useless)
	if opp_strike_ffa["has_ignore_armor"]:
		return _min_action

	# 2) The opponent card's final power (including EX +1 and during_strike powerups from their boost zone)
	var opp_power: int = opp_strike_ffa["power"]
	for bid in state.opponent_state.continuous_boosts:
		var _bc = state.card_db.get_card(bid)
		if not _bc or not _bc.definition: continue
		var _bdef = _bc.definition.get("boost", {})
		for _bef in _bdef.get("effects", []):
			if _bef.get("timing") == "during_strike" and _bef.get("effect_type") == "powerup":
				opp_power += _bef.get("amount", 0)

	# 3) Our current armor (Block armor + EX armor +1 + during_strike armorup from our boost zone)
	var my_armor: int = 0
	var _def_id: int = state.active_strike.defender_card_id
	if _def_id != -1:
		my_armor = _get_card_armor(_def_id, state)
		if state.active_strike.defender_ex_card_id != -1: my_armor += 1  # EX armor +1
	for bid in state.my_state.continuous_boosts:
		var _bc = state.card_db.get_card(bid)
		if not _bc or not _bc.definition: continue
		var _bdef = _bc.definition.get("boost", {})
		for _bef in _bdef.get("effects", []):
			if _bef.get("timing") == "during_strike" and _bef.get("effect_type") == "armorup":
				my_armor += _bef.get("amount", 0)

	# 4) Goal: hold the opponent to 0 or 1 damage -> armor >= opp power - 1; 1 force = +2 armor
	# Force accounting matches the engine (force mode): includes our own force_cost_reduction and free force
	var _my_real = state.my_state.true_original()
	var _ffa_base: int = 0
	var _ffa_free: int = 0
	if _my_real:
		_ffa_base = _my_real.force_cost_reduction
		_ffa_free = _my_real.get_available_free_force()
	var need_armor: int = max(opp_power - 1 - my_armor, 0)
	if need_armor <= 0:
		return _min_action  # Current armor is already enough, pay nothing
	var force_needed: int = int(ceil(float(need_armor) / 2.0))
	if force_needed <= _ffa_base:
		return _min_action  # Our own cost reduction (applies even on empty payment) is already enough

	# 5) Choose a payment plan: meet the target without overpaying; on ties prefer free force and the least valuable cards
	var _exact_best = null
	var _exact_score: int = -9999
	var _over_best = null
	var _over_fg: int = 999
	var _over_score: int = -9999
	for action in possible_actions:
		if action is AIPlayer.ForceForArmorAction:
			var fg: int = 0
			if _is_gauge_mode:
				fg = action.card_ids.size()  # gauge: each card = 1 force
			else:
				fg = _ffa_base
				if action.use_free_force: fg += _ffa_free
				for cid in action.card_ids: fg += state.card_db.get_card_force_value(cid)
			# Payment cost: higher discard-priority cards are more expendable; free force costs nothing
			var pay_cost: int = 0
			for cid in action.card_ids: pay_cost += _get_card_discard_priority(cid, state)
			if action.use_free_force: pay_cost += 100
			if fg == force_needed:
				if pay_cost > _exact_score:
					_exact_score = pay_cost; _exact_best = action
			elif fg > force_needed:
				# Minimal overshoot: force closest to the target with the lowest payment cost
				if fg < _over_fg or (fg == _over_fg and pay_cost > _over_score):
					_over_fg = fg; _over_score = pay_cost; _over_best = action
	if _exact_best:
		return _exact_best
	if _over_best:
		return _over_best
	# Not enough force to meet the target -> take the plan that pays the most force (as close to target as possible)
	var _best_fg: int = -1
	var _best_fg_action = null
	for action in possible_actions:
		if action is AIPlayer.ForceForArmorAction:
			var fg2: int = 0
			if _is_gauge_mode: fg2 = action.card_ids.size()
			else:
				fg2 = _ffa_base
				if action.use_free_force: fg2 += _ffa_free
				for cid in action.card_ids: fg2 += state.card_db.get_card_force_value(cid)
			if fg2 > _best_fg:
				_best_fg = fg2; _best_fg_action = action
	if _best_fg_action: return _best_fg_action
	return _min_action


func pick_cancel(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	var has_good: bool = false
	for cid in state.my_state.hand:
		if can_card_hit(cid, -1, state) and not _is_block_card(cid, state):
			var sp = _get_card_speed(cid, state)
			var gd = _get_card_guard(cid, state)
			if sp >= 6 or gd >= 4 or _score_strike(cid, -1, state, false) >= 12.0:
				has_good = true
				break
	for action in possible_actions:
		if action is AIPlayer.CancelAction and action.cancel:
			if has_good and state.my_state.gauge.size() >= 1: return action
	for action in possible_actions:
		if action is AIPlayer.CancelAction and not action.cancel: return action
	return possible_actions[randi() % possible_actions.size()]
func pick_discard_continuous(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	var own := []; var opp := []
	for action in possible_actions:
		if action is AIPlayer.DiscardContinuousBoostAction:
			if action.mine: own.append(action)
			else: opp.append(action)

	# NEVER discard own boosts if opponent boosts exist
	if opp.size() > 0:
		# Score opponent boosts: discard the most dangerous one first
		var scored_opp := []
		for act in opp:
			var s: float = _score_opponent_boost_danger(act.card_id, state)
			scored_opp.append({"action": act, "score": s})
		scored_opp.sort_custom(_sort_by_score_desc)
		return scored_opp[0]["action"]

	# Forced to discard own boost: pick the LEAST valuable one
	if own.size() > 0:
		var scored_own := []
		for act in own:
			var s: float = _score_boost_by_card_id(act.card_id, state)
			scored_own.append({"action": act, "score": s})
		scored_own.sort_custom(func(a, b): return a["score"] < b["score"])
		return scored_own[0]["action"]

	return possible_actions[randi() % possible_actions.size()]


func _score_opponent_boost_danger(boost_card_id: int, state: AIPlayer.AIGameState) -> float:
	## Score how dangerous an opponent's continuous boost is.
	## Higher score = more dangerous = discard this first.
	if boost_card_id <= 0: return 0.0
	var cdef = _get_def(boost_card_id, state)
	if not cdef: return 0.0
	var boost_def = cdef.get("boost", {})
	if boost_def.is_empty(): return 0.0
	var score: float = 10.0  # Base: any continuous boost has value
	var distance: int = _get_distance(state)
	for eff in boost_def.get("effects", []):
		var et = eff.get("effect_type", "")
		var timing = eff.get("timing", "")
		var amount = eff.get("amount", 1)
		if et == "speedup":
			score += amount * 12.0  # Speed is critical
			if timing == "during_strike": score += 8.0
		elif et == "powerup":
			score += amount * 10.0
		elif et == "armorup":
			score += amount * 8.0
		elif et == "armor_ignore":
			score += 20.0  # Piercing armor is very dangerous
		elif et == "guard_ignore":
			score += 15.0
		elif et == "draw":
			score += amount * 8.0  # Card advantage
		elif et == "opponent_discard_random":
			score += 12.0
		elif et == "stun":
			score += 18.0
		elif et == "advance_after_strike" or et == "retreat_after_strike":
			score += 6.0  # Mobility
		elif et == "reading_normal":
			score += 25.0  # Reading is extremely dangerous
		elif et == "continuous_push" or et == "continuous_pull":
			score += 10.0  # Position control
	# Higher score if opponent can actually use it at this distance
	var boost_rmin = boost_def.get("range_min", 1)
	if boost_rmin is String: boost_rmin = 1
	var boost_rmax = boost_def.get("range_max", boost_rmin + 3)
	if boost_rmax is String: boost_rmax = boost_rmin + 3
	if boost_rmin <= distance and distance <= boost_rmax:
		score *= 1.5  # Active range bonus
	return score

func pick_discard_own_gauge(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.DiscardGaugeAction:
			var _dtype_def = _get_def(action.card_id, state)
			var ctype = _dtype_def.get('type', '') if _dtype_def else ''
			scored.append({"action": action, "score": 1 if ctype == 'ultra' else (2 if ctype == 'special' else 3)})
	if scored.size() > 0:
		scored.sort_custom(_sort_by_score_desc)
		return scored[0]['action']
	return possible_actions[randi() % possible_actions.size()]

func pick_discard_opponent_gauge(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.DiscardGaugeAction:
			var _dtype_def = _get_def(action.card_id, state)
			var ctype = _dtype_def.get('type', '') if _dtype_def else ''
			scored.append({"action": action, "score": 3 if ctype == 'ultra' else (2 if ctype == 'special' else 1)})
	if scored.size() > 0:
		scored.sort_custom(_sort_by_score_desc)
		return scored[0]['action']
	return possible_actions[randi() % possible_actions.size()]


func pick_name_opponent_card(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	_cache_state(state)
	var distance: int = _get_distance(state)

	# Detect context: Reading (only normal cards nameable) vs Parry (any card discards)
	# Reading: from Standard Focus boost (reading_normal effect)
	# Parry: from Block boost (name_card_opponent_discards effect)
	var is_reading_context: bool = true
	for action in possible_actions:
		if action is AIPlayer.NameCardAction:
			var defn = _get_def(action.card_id, state)
			if defn and defn.get("type", "") != "normal":
				is_reading_context = false
				break

	# Gather opponent's in-hand card IDs for targeting
	var in_hand_names: Array = []
	var in_hand_by_id: Dictionary = {}
	for cid in _visible_opponent_hand(state):
		var defn = _get_def(cid, state)
		if defn:
			var did = defn.get("id", "")
			in_hand_names.append(did)
			in_hand_by_id[did] = defn

	# Analyze opponent hand context for targeted Reading decisions
	var opp_in_range_normals: Array = []  # definition IDs of normals that can hit now
	var opp_fastest_in_range: String = ""
	var opp_fastest_speed: int = 0
	var opp_has_block_in_hand: bool = false
	for cid in _visible_opponent_hand(state):
		var defn = _get_def(cid, state)
		if not defn: continue
		if defn.get("type", "") != "normal": continue
		var did = defn.get("id", "")
		var rmin = defn.get("range_min", 1)
		if rmin is String: rmin = 1
		var rmax = defn.get("range_max", rmin + 3)
		if rmax is String: rmax = rmin + 3
		var spd = defn.get("speed", 0)
		if spd is String: spd = 0
		var did_lower = did.to_lower()
		if "block" in did_lower:
			opp_has_block_in_hand = true
		if rmin <= distance and distance <= rmax:
			opp_in_range_normals.append(did)
			if spd > opp_fastest_speed:
				opp_fastest_speed = spd
				opp_fastest_in_range = did

	# In Reading context: find our best strike card for matchup analysis
	var my_best_strike_defn = null
	if is_reading_context:
		var best_strike_score: float = -999.0
		for cid in state.my_state.hand:
			var defn = _get_def(cid, state)
			if not defn: continue
			if defn.get("type", "") == "ultra": continue  # Reading only affects normals
			var gauge_cost = defn.get("gauge_cost", 0)
			if gauge_cost > state.my_state.gauge.size(): continue
			var rmin = defn.get("range_min", 1)
			if rmin is String: rmin = 1
			var rmax = defn.get("range_max", rmin + 3)
			if rmax is String: rmax = rmin + 3
			if rmin <= distance and distance <= rmax:
				# Score by power + speed for pairing with Reading
				var sc: float = defn.get("power", 0) * 2.0 + defn.get("speed", 0) * 1.0
				# Ignore-guard cards like Spike/Dust are the ideal follow-up after a Reading name
				if _def_has_effect(defn, "ignore_guard"): sc += 20.0
				if _def_has_effect(defn, "ignore_armor"): sc += 10.0
				if _def_has_effect(defn, "ignore_guard"): sc += 10.0
				if sc > best_strike_score:
					best_strike_score = sc
					my_best_strike_defn = defn

	# ────────────────────────────────────────────────────────────────
	# Player feedback: omniscient naming is too accurate. 20% chance keep omniscient naming; 80% chance use only public info
	# (opponent deck - publicly seen cards) infers which cards are likely still in hand, then names weighted-randomly
	# ────────────────────────────────────────────────────────────────
	if randf() >= 0.2:
		return _pick_name_inferred(possible_actions, state, is_reading_context, distance, my_best_strike_defn)

	# -- 20%: omniscient naming (original logic, reads the opponent's hand directly) --
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.NameCardAction:
			var defn = _get_def(action.card_id, state)
			if not defn: continue
			var s: float = 0.0
			var def_id = defn.get("id", "")
			var def_id_lower = def_id.to_lower()
			var ctype = defn.get("type", "")
			var in_hand: bool = def_id in in_hand_names

			if is_reading_context:
				# Reading: use per-distance matchup scoring with our best strike
				s = _score_reading_target(action.card_id, defn, in_hand, distance, my_best_strike_defn)
				# Opponent-hand-context bonuses: target cards the opponent actually relies on
				if in_hand and s > 0.0:
					# 1) ONLY in-range normal: naming it forces opponent to use it or reveal
					if opp_in_range_normals.size() == 1 and def_id in opp_in_range_normals:
						s += 40.0  # Opponent's ONLY option — devastating lockdown
					elif opp_in_range_normals.size() == 2 and def_id in opp_in_range_normals:
						s += 15.0  # One of only 2 options — strong constraint
					# 2) Opponent's FASTEST in-range card: neutralize their speed advantage
					if def_id == opp_fastest_in_range and opp_fastest_speed >= 5:
						s += 12.0  # Shut down their speed threat
					# 3) Opponent HAS Block: locking Block removes their safe defense
					if opp_has_block_in_hand and "block" in def_id_lower:
						s += 10.0  # No more Block — all our strikes get through
					# 4) Opponent's Focus: denying Focus = denying their draw engine
					if "focus" in def_id_lower and in_hand:
						s += 8.0  # Cut off their card draw
			else:
				# Parry (name_card_opponent_discards): force opponent to discard
				if in_hand:
					s += 30.0
					# Target the most THREATENING cards
					s += defn.get("speed", 0) * 3.0
					s += defn.get("power", 0) * 2.0
					match ctype:
						"ultra": s += 12.0
						"special": s += 6.0
						_: s += 1.0
					# Bonus if it's in range (discarding a usable card hurts more)
					var rmin = defn.get("range_min", 1)
					if rmin is String: rmin = 1
					var rmax = defn.get("range_max", rmin + 3)
					if rmax is String: rmax = rmin + 3
					if rmin <= distance and distance <= rmax: s += 10.0
				else:
					s -= 20.0  # Not in hand, unlikely to discard anything useful

			# Seen penalty (card already in discard/gauge)
			var seen_count: int = 0
			for did in state.opponent_state.discards:
				if state.card_db.are_same_card(action.card_id, did): seen_count += 1
			for gid in state.opponent_state.gauge:
				if state.card_db.are_same_card(action.card_id, gid): seen_count += 1
			s -= seen_count * 7.0

			scored.append({"action": action, "score": s})

	if scored.size() > 0: scored.sort_custom(_sort_by_score_desc)
	if scored.size() > 0 and scored[0]['score'] > 0:
		return scored[0]['action']
	return possible_actions[randi() % possible_actions.size()]


# ================================================================
# Inferred naming (80% chance): don't look at the opponent's hand, use only public info to judge which cards may remain
# Public info = opponent deck (fixed per character, public) - discards / gauge / boosts / revealed strike cards
# Idea: cards not yet publicly seen are more likely in hand; combine with "can hit at current distance, high threat" to judge
# which cards the opponent likely keeps, then name weighted-randomly by (likely-in-hand x matchup value) -- not guaranteed to hit
# ================================================================
func _pick_name_inferred(possible_actions: Array, state: AIPlayer.AIGameState, is_reading_context: bool, distance: int, my_best_strike_defn):
	# Tally public info: total copies of each card in the opponent deck & copies publicly seen
	var seen_by_id: Dictionary = {}   # definition id -> copies publicly seen
	var total_by_id: Dictionary = {}  # definition id -> total copies in the deck
	for card in state.opponent_state.deck_list:
		if card == null: continue
		var cdef = null
		if card is Dictionary:
			cdef = card.get("definition", null)
			if cdef == null and card.has("id"):
				cdef = _get_global_card_def(str(card["id"]))
		else:
			cdef = card.definition
		if cdef == null: continue
		var cdid = cdef.get("id", "")
		total_by_id[cdid] = int(total_by_id.get(cdid, 0)) + 1
	for did in state.opponent_state.discards:
		var ddef = _get_def(did, state)
		if ddef: seen_by_id[ddef.get("id", "")] = int(seen_by_id.get(ddef.get("id", ""), 0)) + 1
	for gid in state.opponent_state.gauge:
		var gdef = _get_def(gid, state)
		if gdef: seen_by_id[gdef.get("id", "")] = int(seen_by_id.get(gdef.get("id", ""), 0)) + 1
	for bid in state.opponent_state.continuous_boosts:
		var bdef = _get_def(bid, state)
		if bdef: seen_by_id[bdef.get("id", "")] = int(seen_by_id.get(bdef.get("id", ""), 0)) + 1
	# The opponent's revealed strike card is also public info
	if state.active_strike and state.active_strike.active and state.active_strike.initiator == state.opponent_state.player_id:
		var _scid: int = state.active_strike.initiator_card_id
		if _scid != -1:
			var _sdef = _get_def(_scid, state)
			if _sdef: seen_by_id[_sdef.get("id", "")] = int(seen_by_id.get(_sdef.get("id", ""), 0)) + 1

	# Derive board context from "cards not yet publicly seen" (replaces the omniscient version's opponent-hand context)
	var inf_in_range: Array = []   # normals that may still be in hand and can hit at the current distance
	var inf_fastest_id: String = ""
	var inf_fastest_speed: int = 0
	var inf_has_block: bool = false
	for card in state.opponent_state.deck_list:
		if card == null: continue
		var cdef = null
		if card is Dictionary:
			cdef = card.get("definition", null)
			if cdef == null and card.has("id"):
				cdef = _get_global_card_def(str(card["id"]))
		else:
			cdef = card.definition
		if cdef == null: continue
		if cdef.get("type", "") != "normal": continue
		var did = cdef.get("id", "")
		if int(seen_by_id.get(did, 0)) >= int(total_by_id.get(did, 0)): continue  # all copies already seen publicly
		var rmin = cdef.get("range_min", 1)
		if rmin is String: rmin = 1
		var rmax = cdef.get("range_max", rmin + 3)
		if rmax is String: rmax = rmin + 3
		var spd = cdef.get("speed", 0)
		if spd is String: spd = 0
		var did_lower = did.to_lower()
		if "block" in did_lower:
			inf_has_block = true
		if rmin <= distance and distance <= rmax:
			inf_in_range.append(did)
			if spd > inf_fastest_speed:
				inf_fastest_speed = spd
				inf_fastest_id = did

	var scored := []
	for action in possible_actions:
		if action is AIPlayer.NameCardAction:
			var defn = _get_def(action.card_id, state)
			if not defn: continue
			var s: float = 0.0
			var def_id = defn.get("id", "")
			var def_id_lower = def_id.to_lower()
			var ctype = defn.get("type", "")
			var total_copies: int = int(total_by_id.get(def_id, 0))
			var seen_copies: int = int(seen_by_id.get(def_id, 0))
			var unseen_copies: int = max(total_copies - seen_copies, 0)
			# Likely-in-hand weight: unseen copies -> proportional to their count; all seen -> 0.15 (discards may reshuffle into deck)
			var presence: float = float(unseen_copies) if unseen_copies > 0 else 0.15

			if is_reading_context:
				# Reading: matchup score of "if the opponent were playing this card, how valuable to name it" x likely-in-hand
				s = _score_reading_target(action.card_id, defn, true, distance, my_best_strike_defn)
				if s > 0.0:
					s *= presence
					# Same context bonuses as the omniscient version, but based on "not yet seen" inference
					if inf_in_range.size() == 1 and def_id in inf_in_range:
						s += 40.0 * presence   # inferred to be the opponent's only card that can hit
					elif inf_in_range.size() == 2 and def_id in inf_in_range:
						s += 15.0 * presence
					if def_id == inf_fastest_id and inf_fastest_speed >= 5:
						s += 12.0 * presence   # locks down the inferred fastest card of the opponent
					if inf_has_block and "block" in def_id_lower:
						s += 10.0 * presence
					if "focus" in def_id_lower and unseen_copies > 0:
						s += 8.0 * presence
			else:
				# Parry: the inferred most threatening card (speed/power/type), also weighted by likely-in-hand
				s = 30.0 + defn.get("speed", 0) * 3.0 + defn.get("power", 0) * 2.0
				match ctype:
					"ultra": s += 12.0
					"special": s += 6.0
					_: s += 1.0
				var rmin = defn.get("range_min", 1)
				if rmin is String: rmin = 1
				var rmax = defn.get("range_max", rmin + 3)
				if rmax is String: rmax = rmin + 3
				if rmin <= distance and distance <= rmax: s += 10.0
				s *= presence

			scored.append({"action": action, "score": s})

	# Weighted-random naming: weight = score^2, so the more likely a card is played the higher its chance to be named, but not guaranteed
	var total_weight: float = 0.0
	for e in scored:
		if e["score"] > 0.0:
			total_weight += e["score"] * e["score"]
	if total_weight > 0.0:
		var roll: float = randf() * total_weight
		for e in scored:
			if e["score"] > 0.0:
				roll -= e["score"] * e["score"]
				if roll <= 0.0:
					return e['action']
	return possible_actions[randi() % possible_actions.size()]


func pick_card_hand_to_gauge(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.HandToGaugeAction:
			var penalty: int = 0
			for cid in action.card_ids: penalty += _get_card_discard_priority(cid, state)
			scored.append({"action": action, "score": penalty})
	if scored.size() > 0: scored.sort_custom(_sort_by_score_desc); return scored[0]['action']
	return possible_actions[randi() % possible_actions.size()]


func pick_mulligan(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	var starting_distance: int = 4
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.MulliganAction:
			var value: int = 0
			for cid in action.card_ids:
				if _get_card_range_min(cid, state) <= starting_distance and starting_distance <= _get_card_range_max(cid, state):
					value -= 5
				else: value += 10
				var _mdef = _get_def(cid, state)
				if _mdef and _mdef.get('type') == 'ultra': value -= 15
			scored.append({"action": action, "score": value})
	if scored.size() > 0: scored.sort_custom(_sort_by_score_desc); return scored[0]['action']
	return possible_actions[randi() % possible_actions.size()]


func pick_choose_from_boosts(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.ChooseFromBoostsAction:
			var s: float = 0.0
			for cid in action.card_ids:
				s += _score_boost_by_card_id(cid, state)
			scored.append({"action": action, "score": s})
	if scored.size() > 0:
		scored.sort_custom(_sort_by_score_desc)
		return scored[0]["action"]
	return possible_actions[randi() % possible_actions.size()]


func _score_boost_by_card_id(card_id: int, state: AIPlayer.AIGameState) -> float:
	## Score a card's boost value (used for choosing between boost options).
	if card_id <= 0: return 0.0
	var cdef = _get_def(card_id, state)
	if not cdef: return 0.0
	var boost_def = cdef.get("boost", {})
	if boost_def.is_empty(): return 0.0
	var score: float = 5.0
	var distance: int = _get_distance(state)
	for eff in boost_def.get("effects", []):
		var et = eff.get("effect_type", "")
		var amount = eff.get("amount", 1)
		if et == "speedup": score += amount * 12.0
		elif et == "powerup": score += amount * 10.0
		elif et == "armorup": score += amount * 8.0
		elif et == "draw": score += amount * 10.0
		elif et == "opponent_discard_random": score += 12.0
		elif et == "stun": score += 18.0
		elif et == "reading_normal": score += 22.0
		elif et == "advance" or et == "retreat": score += 5.0
		elif et == "ignore_armor": score += 15.0
		elif et == "ignore_guard": score += 12.0
		var _and = eff.get("and", {})
		var and_et = _and.get("effect_type", "") if _and is Dictionary else ""
		if and_et == "ignore_armor": score += 15.0
		elif and_et == "ignore_guard": score += 12.0
	# Active range bonus
	var brmin = boost_def.get("range_min", 1)
	if brmin is String: brmin = 1
	var brmax = boost_def.get("range_max", brmin + 3)
	if brmax is String: brmax = brmin + 3
	if brmin <= distance and distance <= brmax:
		score *= 1.3
	return score


func pick_choose_from_discard(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	_sort_state = state
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.ChooseFromDiscardAction:
			var s: float = 0.0
			for cid in action.card_ids: s += _score_strike(cid, -1, state, false)
			scored.append({"action": action, "score": s})
	if scored.size() > 0: scored.sort_custom(_sort_by_score_desc); return scored[0]['action']
	return possible_actions[randi() % possible_actions.size()]


func pick_force_for_effect(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	# Check if this is a beneficial effect (transform) - prefer paying
	var should_pay: bool = false
	var game_logic = state.true_original()
	if game_logic and game_logic.has_method("get_decision_info"):
		var dinfo = game_logic.decision_info
		if dinfo and dinfo.effect:
			var overall = dinfo.effect.get("overall_effect", {})
			if not (overall is Dictionary):
				overall = {}
			var et = overall.get("effect_type", "")
			var and_overall = dinfo.effect.get("and", {})
			if not (and_overall is Dictionary): and_overall = {}
			var and_et2 = and_overall.get("effect_type", "")
			if et in ["powerup", "speedup", "armorup", "guardup", "critical", "ignore_armor", "ignore_guard"] \
					or and_et2 in ["ignore_armor", "ignore_guard"]:
				should_pay = true
	if should_pay:
		var best = null
		var best_count: int = -1
		for action in possible_actions:
			if action is AIPlayer.ForceForEffectAction:
				var cnt = action.card_ids.size()
				if cnt > best_count:
					best_count = cnt
					best = action
		if best: return best
	# Default: minimum payment
	var fallback := []
	for action in possible_actions:
		if action is AIPlayer.ForceForEffectAction: fallback.append({"action": action, "count": action.card_ids.size()})
	if fallback.size() > 0: fallback.sort_custom(Callable(self, "_sort_by_count_asc")); return fallback[0]["action"]
	return possible_actions[randi() % possible_actions.size()]
func pick_gauge_for_effect(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state

	# Whether the character has a critical ability (Season 3 Exceed: spend gauge to crit an attack)
	var has_critical_ability: bool = _has_critical_ability(state)

	if has_critical_ability and state.my_state.gauge.size() >= 1:
		# Determine "the AI's own attack card": use initiator if the AI initiated, defender if the AI is responding
		# (Key: don't just read initiator_card_id, because when responding that is the opponent's card.)
		var my_card_id: int = -1
		if state.active_strike.active:
			if state.active_strike.initiator == state.my_state.player_id:
				my_card_id = state.active_strike.initiator_card_id
			else:
				my_card_id = state.active_strike.defender_card_id

		# Whether this crit is beneficial (card has is_critical effects / character crit ability is pure gain)
		if _critical_has_value(state, my_card_id):
			for action in possible_actions:
				if action is AIPlayer.GaugeForEffectAction and action.card_ids.size() == 1:
					return action
		# No benefit -> don't spend gauge (pass)
		for action in possible_actions:
			if action is AIPlayer.GaugeForEffectAction and action.card_ids.size() == 0:
				return action

	# No critical ability or no gauge -> default to minimal payment
	var scored := []
	for action in possible_actions:
		if action is AIPlayer.GaugeForEffectAction: scored.append({"action": action, "count": action.card_ids.size()})
	if scored.size() > 0: scored.sort_custom(_sort_by_count_asc); return scored[0]["action"]
	return possible_actions[randi() % possible_actions.size()]
func pick_choose_opponent_card_to_discard(possible_actions: Array, _ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	return possible_actions[randi() % possible_actions.size()]


func pick_choose_from_topdeck(possible_actions: Array, _ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	for action in possible_actions:
		if action is AIPlayer.ChooseFromTopdeckAction and action.action != "pass": return action
	return possible_actions[randi() % possible_actions.size()]


func pick_choose_arena_location_for_effect(possible_actions: Array, ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	var state: AIPlayer.AIGameState = ai_game_state
	# Placement-movement effects (push/pull the opponent to a space, or move self to a space) -- safety check
	var _et: String = ""
	var _glogic = state.true_original()
	if _glogic and _glogic.decision_info and _glogic.decision_info.effect_type != null:
		_et = str(_glogic.decision_info.effect_type)
	var _is_opp_move: bool = _et in ["push_or_pull_to_space", "pull_to_space_and_gain_power"]
	var _is_self_move: bool = _et == "move_to_space"
	if _is_opp_move or _is_self_move:
		var _my_loc: int = state.my_state.arena_location
		var _opp_loc: int = state.opponent_state.arena_location
		var _d: int = abs(_my_loc - _opp_loc)
		var _in_danger_now: bool = _opp_can_hit_at_distance(_d, state)
		var _escapes := []; var _enters := []; var _kept := []
		for action in possible_actions:
			if action.location == 0:
				_kept.append(action)  # pass: no movement, distance unchanged
				continue
			var _nd: int = abs(action.location - _my_loc) if _is_opp_move else abs(action.location - _opp_loc)
			var _in_danger_after: bool = _opp_can_hit_at_distance(_nd, state)
			if _in_danger_now and not _in_danger_after:
				_escapes.append({"action": action, "d": _nd})
			elif not _in_danger_now and _in_danger_after:
				_enters.append({"action": action, "d": _nd})
			else:
				_kept.append(action)
		# 1) Can escape the opponent's attack range -> execute, the further the better
		if _escapes.size() > 0:
			_escapes.sort_custom(func(a, b): return a["d"] > b["d"])
			return _escapes[0]["action"]
		# 2) Would enter the opponent's attack range -> skip (prefer pass/neutral placement); if all enter, pick the shallowest
		if _kept.size() > 0:
			return _kept[randi() % _kept.size()]
		_enters.sort_custom(func(a, b): return a["d"] > b["d"])
		return _enters[0]["action"]
	# Non-movement placement: keep the original behavior
	if possible_actions[0].location == 0 and possible_actions.size() > 1:
		return possible_actions[(randi() % (possible_actions.size() - 1)) + 1]
	return possible_actions[randi() % possible_actions.size()]


func pick_number_from_range_for_effect(possible_actions: Array, _ai_game_state: AIPlayer.AIGameState):
	if possible_actions.size() == 0: return null
	return possible_actions[randi() % possible_actions.size()]

# ============================================================
# Omniscient Helpers -- Caching & Opponent Hand Analysis
# ============================================================

func _cache_state(state: AIPlayer.AIGameState) -> void:
	if _cached_state != state:
		_cached_state = state
		_card_def_cache.clear()
		_opp_hand_analysis.clear()


func _get_def(card_id: int, state: AIPlayer.AIGameState):
	if card_id == -1: return null
	if card_id in _card_def_cache:
		return _card_def_cache[card_id]
	var card = state.card_db.get_card(card_id)
	if card and card.definition:
		_card_def_cache[card_id] = card.definition
		return card.definition
	return null


## Overlay the during_strike-timing boost stats (powerup/speedup/guardup/armorup/attack_is_ex)
## onto a copy of the card definition, returning a new defn (without mutating the cached original).
## is_opponent decides whether to read the opponent's or our own boost zone.
func _apply_boost_stats(defn: Dictionary, state: AIPlayer.AIGameState, is_opponent: bool) -> Dictionary:
	if defn.is_empty():
		return defn
	var boost_source: Array = state.opponent_state.continuous_boosts if is_opponent else state.my_state.continuous_boosts
	if boost_source.is_empty():
		return defn
	var d: Dictionary = defn.duplicate(true)
	var p_bonus := 0
	var s_bonus := 0
	var g_bonus := 0
	var a_bonus := 0
	for bid in boost_source:
		var bc = state.card_db.get_card(bid)
		if not bc or not bc.definition: continue
		var bdef = bc.definition.get("boost", {})
		for bef in bdef.get("effects", []):
			if bef.get("timing", "") != "during_strike":
				continue
			var et: String = str(bef.get("effect_type", ""))
			var amt = bef.get("amount", 0)
			if amt is String: amt = 0
			match et:
				"powerup": p_bonus += int(amt)
				"speedup": s_bonus += int(amt)
				"guardup": g_bonus += int(amt)
				"armorup": a_bonus += int(amt)
				"attack_is_ex": s_bonus += 1
	if p_bonus != 0 and not (d.get("power", 0) is String):
		d["power"] = int(d.get("power", 0)) + p_bonus
	if s_bonus != 0 and not (d.get("speed", 0) is String):
		d["speed"] = int(d.get("speed", 0)) + s_bonus
	if g_bonus != 0 and not (d.get("guard", 0) is String):
		d["guard"] = int(d.get("guard", 0)) + g_bonus
	if a_bonus != 0 and not (d.get("armor", 0) is String):
		d["armor"] = int(d.get("armor", 0)) + a_bonus
	return d


## Count occurrences of each card in the opponent's hand (to tell whether they can play EX: two copies of the same card).
func _opponent_hand_counts(state: AIPlayer.AIGameState) -> Dictionary:
	var counts := {}
	for cid in _visible_opponent_hand(state):
		counts[cid] = int(counts.get(cid, 0)) + 1
	return counts


## Add EX's +1 (speed/power/guard/armor) onto a copy of the card definition.
## EX attack = two copies set together, +1 to each of the four stats (see set_ex in player.gd).
func _apply_ex_to_def(defn: Dictionary) -> Dictionary:
	if defn.is_empty():
		return defn
	var d: Dictionary = defn.duplicate(true)
	for k in ["speed", "power", "guard", "armor"]:
		var v = d.get(k, 0)
		if not (v is String):
			d[k] = int(v) + 1
	return d


## Apply the card's own conditional stat bonuses (initiate/respond related).
## is_initiator=true -> apply initiated_strike; false -> apply not_initiated_strike.
## E.g. Ryu's Dragon Punch not_initiated_strike speed +2 (only when responding); Ken's initiated_strike speed +2 (only when initiating).
func _apply_strike_condition_stats(defn: Dictionary, is_initiator: bool) -> Dictionary:
	if defn.is_empty():
		return defn
	var has_cond: bool = false
	for ef in defn.get("effects", []):
		var cond = str(ef.get("condition", ""))
		if cond == "initiated_strike" or cond == "not_initiated_strike":
			has_cond = true
			break
	if not has_cond:
		return defn
	var d: Dictionary = defn.duplicate(true)
	var p_bonus := 0
	var s_bonus := 0
	var g_bonus := 0
	var a_bonus := 0
	for ef in d.get("effects", []):
		var et: String = str(ef.get("effect_type", ""))
		var cond: String = str(ef.get("condition", ""))
		var amt = ef.get("amount", 0)
		if amt is String: amt = 0
		var applies: bool = (cond == "initiated_strike" and is_initiator) or (cond == "not_initiated_strike" and not is_initiator)
		if not applies: continue
		match et:
			"powerup": p_bonus += int(amt)
			"speedup": s_bonus += int(amt)
			"guardup": g_bonus += int(amt)
			"armorup": a_bonus += int(amt)
	if p_bonus != 0 and not (d.get("power", 0) is String):
		d["power"] = int(d.get("power", 0)) + p_bonus
	if s_bonus != 0 and not (d.get("speed", 0) is String):
		d["speed"] = int(d.get("speed", 0)) + s_bonus
	if g_bonus != 0 and not (d.get("guard", 0) is String):
		d["guard"] = int(d.get("guard", 0)) + g_bonus
	if a_bonus != 0 and not (d.get("armor", 0) is String):
		d["armor"] = int(d.get("armor", 0)) + a_bonus
	return d


## Whether the character has a critical ability (Season 3 Exceed: spend gauge to crit a Special).
func _has_critical_ability(state: AIPlayer.AIGameState) -> bool:
	var deck_def = state.my_state.deck_def
	var ability_list: Array = deck_def.get("ability_effects", [])
	if state.my_state.exceeded:
		ability_list = deck_def.get("exceed_ability_effects", ability_list)
	for ab_eff in ability_list:
		if ab_eff.get("timing") == "set_strike" and ab_eff.get("effect_type") == "gauge_for_effect":
			var _ov = ab_eff.get("overall_effect", {})
			if _ov is Dictionary and _ov.get("effect_type") == "critical":
				if ab_eff.get("gauge_max", 0) >= 1:
					return true
	return false


## Apply critical stat bonuses: when the character has a crit ability + has gauge + the card is a Special,
## overlay the is_critical-conditioned speedup/powerup/armorup/guardup onto the defn copy.
## (is_critical ignore_guard/ignore_armor flags are already recognized unconditionally by _def_has_effect, no handling needed.)
func _apply_critical_to_def(defn: Dictionary, state: AIPlayer.AIGameState) -> Dictionary:
	if defn.is_empty():
		return defn
	if str(defn.get("type", "")) != "special":
		return defn
	if state.my_state.gauge.size() < 1:
		return defn
	if not _has_critical_ability(state):
		return defn
	var d: Dictionary = defn.duplicate(true)
	var p_bonus := 0
	var s_bonus := 0
	var g_bonus := 0
	var a_bonus := 0
	for ef in d.get("effects", []):
		if str(ef.get("condition", "")) != "is_critical":
			continue
		var et: String = str(ef.get("effect_type", ""))
		var amt = ef.get("amount", 0)
		if amt is String: amt = 0
		match et:
			"powerup": p_bonus += int(amt)
			"speedup": s_bonus += int(amt)
			"guardup": g_bonus += int(amt)
			"armorup": a_bonus += int(amt)
	if p_bonus != 0 and not (d.get("power", 0) is String):
		d["power"] = int(d.get("power", 0)) + p_bonus
	if s_bonus != 0 and not (d.get("speed", 0) is String):
		d["speed"] = int(d.get("speed", 0)) + s_bonus
	if g_bonus != 0 and not (d.get("guard", 0) is String):
		d["guard"] = int(d.get("guard", 0)) + g_bonus
	if a_bonus != 0 and not (d.get("armor", 0) is String):
		d["armor"] = int(d.get("armor", 0)) + a_bonus
	return d


## Decide whether this crit is beneficial, and thus whether to spend gauge:
## 1) The AI's attack card (initiate or respond) has is_critical-conditioned effects (e.g. Sagat's lowstepkick crit ignore_guard);
## 2) The character's crit ability gives pure gain on crit (e.g. Zangief at distance 1: power +1 speed +1);
## 3) Akuma's add_attack_effect powerup_both_players (+2 power to both) only helps when the AI's power is ahead.
func _critical_has_value(state: AIPlayer.AIGameState, my_card_id: int) -> bool:
	# 1) The attack card itself has is_critical-conditioned effects -> crit is beneficial
	if my_card_id > 0:
		var defn = _get_def(my_card_id, state)
		if defn:
			for ef in defn.get("effects", []):
				if str(ef.get("condition", "")) == "is_critical":
					return true
	# 2) Character crit ability (set_strike timing + is_critical-conditioned bonus effects)
	var deck_def = state.my_state.deck_def
	var ability_list: Array = deck_def.get("ability_effects", [])
	if state.my_state.exceeded:
		ability_list = deck_def.get("exceed_ability_effects", ability_list)
	for ab_eff in ability_list:
		if ab_eff.get("timing") != "set_strike":
			continue
		if str(ab_eff.get("condition", "")) != "is_critical":
			continue
		var et: String = str(ab_eff.get("effect_type", ""))
		var _and = ab_eff.get("and", {})
		var and_et: String = str(_and.get("effect_type", "")) if _and is Dictionary else ""
		# Pure gain: our own power/speed/armor/guard bonuses
		if et in ["powerup", "speedup", "armorup", "guardup"]:
			return true
		if and_et in ["powerup", "speedup", "armorup", "guardup"]:
			return true
		# Akuma: +2 power to both, only crit when the AI's power is ahead
		if et == "add_attack_effect":
			var added = ab_eff.get("added_effect", {})
			if added is Dictionary and str(added.get("effect_type", "")) == "powerup_both_players":
				if my_card_id > 0:
					var my_p: int = _get_card_power(my_card_id, state)
					var opp_analysis: Dictionary = _opponent_can_do_now(state)
					if my_p >= int(opp_analysis.get("max_power", 0)):
						return true
	return false


# ============================================================
# Global card pool — ALL characters' cards (normal/special/ultra)
# ============================================================
var _global_card_cache: Dictionary = {}

func _get_global_card_def(def_id: String) -> Dictionary:
	## Read ANY card definition from the global database (all characters, all types).
	## CardDataManager (autoload) holds all 800+ cards regardless of the current match.
	if _global_card_cache.has(def_id):
		return _global_card_cache[def_id]
	var def = null
	if CardDataManager.card_data.has(def_id):
		def = CardDataManager.card_data[def_id]
	var result: Dictionary = def if def != null else {}
	_global_card_cache[def_id] = result
	return result


func _def_has_effect(defn: Dictionary, effect_type: String) -> bool:
	## Returns true if effect_type appears at top level or nested inside 'and' (e.g. Spike's ignore_armor and ignore_guard)
	if defn.is_empty(): return false
	for eff in defn.get("effects", []):
		if eff.get("effect_type") == effect_type: return true
		var and_eff = eff.get("and", {})
		if not and_eff.is_empty() and and_eff.get("effect_type") == effect_type: return true
	return false


func _range_hits(defn: Dictionary, dist: int) -> bool:
	## Whether the card's attack range covers dist
	var rmin = defn.get("range_min", 1)
	if rmin is String: rmin = 1
	var rmax = defn.get("range_max", rmin + 3)
	if rmax is String: rmax = rmin + 3
	return rmin <= dist and dist <= rmax


func _post_advance_distance(distance: int, advance: int, crossed: bool) -> int:
	## Distance after a 'before' advance: if it crosses the opponent to the other side (gap = advance - distance + 1); otherwise = distance - advance
	if advance <= 0: return distance
	if crossed: return advance - distance + 1
	return max(distance - advance, 1)


func _eval_counter_response(my_def: Dictionary, opp_def: Dictionary, distance: int, is_response: bool, my_retreat_cap: int = -1) -> Dictionary:
	## Full response simulation (matches local_game.gd resolution order):
	## Speed sets who goes first (initiator wins ties) -> faster resolves fully (before -> hit -> after) -> slower resolves -> a stunned side doesn't resolve
	## Includes movement dodges: our 'before' advance passing through (dodge_attacks makes all miss) / 'after' retreat out of the opponent's range
	## Returns: exchange (my net life gain, positive = good) my_hit opp_hit dodged (avoided the opponent's attack) stunned (I stunned the opponent)
	if my_def.is_empty():
		return {"exchange": -99, "my_hit": false, "opp_hit": true, "dodged": false, "stunned": false}
	if opp_def.is_empty():
		return {"exchange": 99, "my_hit": true, "opp_hit": false, "dodged": false, "stunned": false}

	# Apply initiate/respond conditional stat bonuses (e.g. Dragon Punch not_initiated_strike speed +2).
	# is_response=true means "I" am responding (opponent initiated); otherwise I initiated.
	if is_response:
		my_def = _apply_strike_condition_stats(my_def, false)   # I respond -> not_initiated_strike
		opp_def = _apply_strike_condition_stats(opp_def, true)  # opponent initiates -> initiated_strike
	else:
		my_def = _apply_strike_condition_stats(my_def, true)    # I initiate -> initiated_strike
		opp_def = _apply_strike_condition_stats(opp_def, false) # opponent responds -> not_initiated_strike

	var my_speed = my_def.get("speed", 0)
	if my_speed is String: my_speed = 20
	var opp_speed = opp_def.get("speed", 0)
	if opp_speed is String: opp_speed = 20
	var my_power = my_def.get("power", 0)
	if my_power is String: my_power = 0
	var opp_power = opp_def.get("power", 0)
	if opp_power is String: opp_power = 0
	var my_guard = my_def.get("guard", 0)
	if my_guard is String: my_guard = 0
	var opp_guard = opp_def.get("guard", 0)
	if opp_guard is String: opp_guard = 0
	var my_armor = my_def.get("armor", 0)
	if my_armor is String: my_armor = 0
	var opp_armor = opp_def.get("armor", 0)
	if opp_armor is String: opp_armor = 0

	var my_ia: bool = _def_has_effect(my_def, "ignore_armor")
	var opp_ia: bool = _def_has_effect(opp_def, "ignore_armor")
	var my_ig: bool = _def_has_effect(my_def, "ignore_guard")
	var opp_ig: bool = _def_has_effect(opp_def, "ignore_guard")

	# Our movement effects: 'before' advance/close (advance can pass through and trigger dodge_attacks) / 'after' retreat (dodge range)
	var my_advance: int = 0
	var my_can_cross: bool = false
	var my_dodge_thru: bool = false
	var my_retreat: int = 0
	for eff in my_def.get("effects", []):
		var et = eff.get("effect_type", "")
		if (et == "advance" or et == "close") and eff.get("timing", "") == "before":
			var amt = eff.get("amount", 0)
			if amt is String: amt = 0
			my_advance = max(my_advance, amt)
			if et == "advance":
				my_can_cross = true
				var and_eff = eff.get("and", {})
				if not and_eff.is_empty() and and_eff.get("effect_type") == "dodge_attacks":
					my_dodge_thru = true
		elif et == "retreat":
			var amt = eff.get("amount", 0)
			if amt is String: amt = 0
			my_retreat = max(my_retreat, amt)
	# Retreat is limited by the arena edge (my_retreat_cap = max spaces I can retreat, -1 = no limit)
	if my_retreat_cap >= 0:
		my_retreat = min(my_retreat, my_retreat_cap)
	# Advance >= current distance -> steps over the opponent's space (passes through)
	var crossed: bool = my_can_cross and my_advance > 0 and distance <= my_advance
	var dodge_active: bool = crossed and my_dodge_thru

	# Opponent movement effects (predict where they land going first): 'before' advance/close + 'after' retreat
	var opp_advance: int = 0
	var opp_can_cross: bool = false
	var opp_retreat: int = 0
	for oeff in opp_def.get("effects", []):
		var oet = oeff.get("effect_type", "")
		if (oet == "advance" or oet == "close") and oeff.get("timing", "") == "before":
			var oamt = oeff.get("amount", 0)
			if oamt is String: oamt = 0
			opp_advance = max(opp_advance, int(oamt))
			if oet == "advance":
				opp_can_cross = true
		elif oet == "retreat":
			var oamt = oeff.get("amount", 0)
			if oamt is String: oamt = 0
			opp_retreat = max(opp_retreat, int(oamt))
	var opp_crossed: bool = opp_can_cross and opp_advance > 0 and distance <= opp_advance

	# First-strike check: on equal speed the initiator wins (if is_response=true I am responding -> on ties the opponent goes first)
	var my_first: bool = (my_speed > opp_speed) if is_response else (my_speed >= opp_speed)

	# Actual damage each side deals
	var my_dmg: int = max(my_power - (0 if my_ia else opp_armor), 0)
	var opp_dmg: int = max(opp_power - (0 if opp_ia else my_armor), 0)
	# Effective guard used for the stun check (treated as 0 if ignore-guard)
	var my_eff_guard: int = 0 if opp_ig else my_guard
	var opp_eff_guard: int = 0 if my_ig else opp_guard

	var my_hit: bool = false
	var opp_hit: bool = false
	var dodged: bool = false
	var stunned: bool = false

	if my_first:
		# I resolve fully: advance -> hit check -> retreat; only then does the opponent resolve
		var my_attack_dist: int = _post_advance_distance(distance, my_advance, crossed)
		if _range_hits(my_def, my_attack_dist):
			my_hit = true
			if my_dmg > opp_eff_guard:
				stunned = true
				return {"exchange": my_dmg, "my_hit": true, "opp_hit": false, "dodged": false, "stunned": true}
		# Opponent's counter: my pass-through dodge -> all miss; after my retreat, re-check by range
		if dodge_active:
			dodged = true
			return {"exchange": my_dmg if my_hit else 0, "my_hit": my_hit, "opp_hit": false, "dodged": true, "stunned": false}
		# Opponent counters second: after I advance into position (not yet retreated), the opponent's 'before' advance chases to check if it can hit;
		# then I retreat away and re-check. Only "could hit before retreat, can't hit after retreat" counts as a real dodge.
		var opp_crossed_pre: bool = opp_can_cross and opp_advance > 0 and my_attack_dist <= opp_advance
		var opp_pre_dist: int = _post_advance_distance(my_attack_dist, opp_advance, opp_crossed_pre)
		var opp_pre_hits: bool = _range_hits(opp_def, opp_pre_dist)
		var my_post: int = my_attack_dist + my_retreat
		var opp_crossed2: bool = opp_can_cross and opp_advance > 0 and my_post <= opp_advance
		var opp_reply_dist: int = _post_advance_distance(my_post, opp_advance, opp_crossed2)
		if not _range_hits(opp_def, opp_reply_dist):
			# Only "could hit before retreat" counts as dodged; otherwise the opponent's range simply wasn't enough
			if opp_pre_hits:
				dodged = true
			return {"exchange": my_dmg if my_hit else 0, "my_hit": my_hit, "opp_hit": false, "dodged": dodged, "stunned": false}
		opp_hit = true
		return {"exchange": (my_dmg if my_hit else 0) - opp_dmg, "my_hit": my_hit, "opp_hit": true, "dodged": false, "stunned": false}
	else:
		# Opponent resolves first: their 'before' movement (advance/close) lands, then they hit at the landed distance
		var opp_landing: int = _post_advance_distance(distance, opp_advance, opp_crossed)
		if _range_hits(opp_def, opp_landing):
			opp_hit = true
			if opp_dmg > my_eff_guard:
				return {"exchange": -opp_dmg, "my_hit": false, "opp_hit": true, "dodged": false, "stunned": false}
		# After the opponent's 'after' retreat pulls away, I advance to counter (hit checked at their post-move position)
		var opp_post: int = opp_landing + opp_retreat
		var my_crossed2: bool = my_can_cross and my_advance > 0 and opp_post <= my_advance
		var my_attack_dist2: int = _post_advance_distance(opp_post, my_advance, my_crossed2)
		if _range_hits(my_def, my_attack_dist2):
			my_hit = true
			if my_dmg > opp_eff_guard:
				stunned = true
		return {"exchange": (my_dmg if my_hit else 0) - (opp_dmg if opp_hit else 0), "my_hit": my_hit, "opp_hit": opp_hit, "dodged": false, "stunned": stunned}


func _is_slow_power_card(opp_strike: Dictionary) -> bool:
	## Sweep/Dust/Spike heavy cards: slow (<=3) + high power (>=5) + high guard (>=4)
	return opp_strike["has_strike"] \
		and opp_strike["defn"] != null \
		and opp_strike["speed"] <= 3 \
		and opp_strike["power"] >= 5 \
		and opp_strike["guard"] >= 4


func _card_exchange_value(my_def: Dictionary, opp_def: Dictionary, distance: int, is_response: bool = false) -> int:
	## Value trade: net life swing when I use my_def and the opponent uses opp_def (real resolution sim, including movement dodges).
	## Positive = I gain (opponent loses more life), negative = I lose.
	## Rules match local_game.gd: speed sets first-strike (initiator wins ties) -> damage = max(power - armor, 0) (armor = 0 if ignore-armor)
	## -> damage > guard causes stun (guard = 0 if ignore-guard) -> a stunned side doesn't resolve and can't counter.
	## is_response=true: I am the responder (on ties the opponent goes first).
	return _eval_counter_response(my_def, opp_def, distance, is_response)["exchange"]


func _get_effective_speed(card_id: int, state: AIPlayer.AIGameState, defn = null) -> int:
	if defn == null: defn = _get_def(card_id, state)
	if not defn: return 0
	var speed = defn.get("speed", 0)
	if speed is String: return 20
	for bid in state.my_state.continuous_boosts:
		var bdef = _get_def(bid, state)
		if not bdef: continue
		var boost = bdef.get("boost", {})
		for bef in boost.get("effects", []):
			if bef.get("timing") == "during_strike":
				if bef.get("effect_type") == "speedup":
					speed += bef.get("amount", 0)
				elif bef.get("effect_type") == "attack_is_ex":
					speed += 1
	return speed


func _get_effective_power(_card_id: int, defn = null) -> int:
	if defn == null: return 0
	var power = defn.get("power", 0)
	return 0 if power is String else power


func _is_focus(card_id: int, state: AIPlayer.AIGameState) -> bool:
	var defn = _get_def(card_id, state)
	if not defn: return false
	return "focus" in defn.get("id", "").to_lower()


func _is_focus_card(card_id: int, state: AIPlayer.AIGameState) -> bool:
	return _is_focus(card_id, state)


func _is_block_card_defn(defn) -> bool:
	if not defn: return false
	return "block" in defn.get("id", "").to_lower()


func _is_standard_focus(card_id: int, state: AIPlayer.AIGameState) -> bool:
	var defn = _get_def(card_id, state)
	if not defn: return false
	return defn.get("id", "") == "standard_normal_focus"


func _has_reading_boost(card_id: int, state: AIPlayer.AIGameState) -> bool:
	var defn = _get_def(card_id, state)
	if not defn: return false
	var boost = defn.get("boost", {})
	if boost.is_empty(): return false
	for eff in boost.get("effects", []):
		if eff.get("effect_type") == "reading_normal":
			return true
	return false


func _is_penetrating_card(card_id: int, state: AIPlayer.AIGameState) -> bool:
	var defn = _get_def(card_id, state)
	if not defn: return false
	var has_ignore_armor: bool = false
	var has_ignore_guard: bool = false
	for eff in defn.get("effects", []):
		if eff.get("effect_type") == "ignore_armor":
			has_ignore_armor = true
			var _and_eff2 = eff.get("and", {}) if "and" in eff else {}
			if _and_eff2 is Dictionary and _and_eff2.get("effect_type") == "ignore_guard":
				has_ignore_guard = true
		if eff.get("effect_type") == "ignore_guard":
			has_ignore_guard = true
	return has_ignore_armor and has_ignore_guard


# ============================================================
# Opponent Hand Analysis (THE KEY ADVANTAGE)
# ============================================================

func _analyze_opponent_strike(state: AIPlayer.AIGameState) -> Dictionary:
	## Analyze the opponent's COMMITTED strike card (from active_strike).
	## Returns detailed info about the card the opponent actually played.
	var result := {
		"has_strike": false,
		"card_id": -1,
		"ex_card_id": -1,
		"defn": null,
		"speed": 0,
		"power": 0,
		"armor": 0,
		"guard": 0,
		"range_min": 1,
		"range_max": 4,
		"type": "",
		"id_str": "",
		"has_ignore_armor": false,
		"has_ignore_guard": false,
		"has_stun": false,
		"has_armor_break": false,
		"can_kill_me": false,
		"is_block": false,
		"is_focus": false,
		"is_spike": false,
		"is_sweep": false,
		"is_throw": false,
		"is_assault": false,
		"is_cross": false,
	}
	if not state.active_strike.active: return result
	if state.active_strike.initiator_card_id <= 0: return result
	result["has_strike"] = true
	result["card_id"] = state.active_strike.initiator_card_id
	result["ex_card_id"] = state.active_strike.initiator_ex_card_id
	var defn = _get_def(state.active_strike.initiator_card_id, state)
	if not defn: return result
	defn = _apply_boost_stats(defn, state, true)  # overlay opponent boosts (powerup/guardup/armorup)
	result["defn"] = defn
	result["speed"] = _get_card_speed(state.active_strike.initiator_card_id, state, false, false, true)
	var _pw = defn.get("power", 0)
	result["power"] = 0 if _pw is String else int(_pw)
	var _ar = defn.get("armor", 0)
	result["armor"] = 0 if _ar is String else int(_ar)
	var _gd = defn.get("guard", 0)
	result["guard"] = 0 if _gd is String else int(_gd)
	# Opponent EX: speed+1 power+1 armor+1 guard+1 (player.gd set_ex), directly affects first-strike and stun thresholds
	if state.active_strike.initiator_ex_card_id != -1:
		result["speed"] += 1
		result["power"] += 1
		result["armor"] += 1
		result["guard"] += 1
	result["range_min"] = _get_card_range_min(state.active_strike.initiator_card_id, state)
	result["range_max"] = _get_card_range_max(state.active_strike.initiator_card_id, state)
	result["type"] = defn.get("type", "")
	var dl = defn.get("id", "").to_lower()
	result["id_str"] = dl
	if "block" in dl: result["is_block"] = true
	if "focus" in dl: result["is_focus"] = true
	if _is_spike_like(dl): result["is_spike"] = true
	if "sweep" in dl: result["is_sweep"] = true
	if "grasp" in dl: result["is_throw"] = true
	if "assault" in dl: result["is_assault"] = true
	if "cross" in dl: result["is_cross"] = true
	if result["power"] >= state.my_state.life: result["can_kill_me"] = true
	for eff in defn.get("effects", []):
		var et = eff.get("effect_type", "")
		if et == "ignore_armor": result["has_ignore_armor"] = true
		if et == "ignore_guard": result["has_ignore_guard"] = true
		var _and_eff = eff.get("and", {})
		if _and_eff is Dictionary and not _and_eff.is_empty() and _and_eff.get("effect_type") == "ignore_guard":
			result["has_ignore_guard"] = true  # Spike/Dust: ignore_guard nested inside 'and'
		if et == "stun": result["has_stun"] = true
		if et == "armor_break": result["has_armor_break"] = true
	return result


func _analyze_opponent_at_distance(target_distance: int, state: AIPlayer.AIGameState) -> Dictionary:
	var result := {
		"max_speed": 0,
		"max_power": 0,
		"max_guard": 0,
		"can_hit_count": 0,
		"has_block": false,
		"has_ignore_armor": false,
		"speeds": [],
		"cards_by_range": [],
		"deck_threats": [],
		"can_kill_me": false,
	}
	var my_life: int = state.my_state.life
	var hand_counts := _opponent_hand_counts(state)  # count same-name copies -> whether the opponent can EX
	for cid in _visible_opponent_hand(state):
		var raw_defn = _get_def(cid, state)
		if not raw_defn: continue
		var defn = _apply_boost_stats(raw_defn, state, true)  # overlay opponent boosts (powerup/guardup/armorup)
		# Opponent can EX (two same-name cards in hand): +1 to all four stats, must be factored into threat evaluation,
		# otherwise the AI misjudges (using raw single-card stats) whether it can first-strike interrupt / survive.
		var ex_available: bool = int(hand_counts.get(cid, 0)) >= 2
		if ex_available:
			defn = _apply_ex_to_def(defn)
		var gauge_cost = defn.get("gauge_cost", 0)
		if gauge_cost > state.opponent_state.gauge.size(): continue
		var rmin = defn.get("range_min", 1)
		if rmin is String: rmin = 1
		var rmax = defn.get("range_max", rmin + 3)
		if rmax is String: rmax = rmin + 3
		var in_range: bool = rmin <= target_distance and target_distance <= rmax
		var card_id_lower = defn.get("id", "").to_lower()
		if "block" in card_id_lower:
			result["has_block"] = true
			if in_range: result["can_hit_count"] += 1
		elif in_range:
			result["can_hit_count"] += 1
			var spd = _get_card_speed(cid, state, false, false, true)
			if ex_available:
				spd += 1  # EX speed +1
			var pwr = defn.get("power", 0)
			if pwr is String: pwr = 0
			var grd = defn.get("guard", 0)
			if grd is String: grd = 0
			result["speeds"].append(spd)
			if spd > result["max_speed"]: result["max_speed"] = spd
			if pwr > result["max_power"]: result["max_power"] = pwr
			if grd > result["max_guard"]: result["max_guard"] = grd
			if pwr >= my_life: result["can_kill_me"] = true
			if _def_has_effect(defn, "ignore_armor"):
				result["has_ignore_armor"] = true
		result["cards_by_range"].append({
			"definition_id": defn.get("id", ""),
			"defn": defn,
			"range": [rmin, rmax],
			"in_range": in_range,
		})

	# -- Deck threat: read the opponent's entire deck (including special/ultra not yet drawn) --
	# deck_list = the opponent character's full deck definition, including cards not yet drawn into hand
	for cid in state.opponent_state.deck_list:
		if cid == null: continue
		var ddef = null
		if cid is Dictionary:
			ddef = cid.get("definition", null)
			if ddef == null and cid.has("id"):
				# Global card-pool fallback: look up any character's card by definition id
				ddef = _get_global_card_def(str(cid["id"]))
		else:
			ddef = cid.definition
		if ddef == null: continue
		var d_gauge = ddef.get("gauge_cost", 0)
		if d_gauge > state.opponent_state.gauge.size(): continue
		var d_rmin = ddef.get("range_min", 1)
		if d_rmin is String: d_rmin = 1
		var d_rmax = ddef.get("range_max", d_rmin + 3)
		if d_rmax is String: d_rmax = d_rmin + 3
		var d_in_range: bool = d_rmin <= target_distance and target_distance <= d_rmax
		if d_in_range:
			result["deck_threats"].append({
				"definition_id": ddef.get("id", ""),
				"defn": ddef,
				"range": [d_rmin, d_rmax],
			})
	return result


func _opponent_can_do_now(state: AIPlayer.AIGameState) -> Dictionary:
	if _opp_hand_analysis.has("current"):
		return _opp_hand_analysis["current"]
	var distance: int = _get_distance(state)
	var result = _analyze_opponent_at_distance(distance, state)
	_opp_hand_analysis["current"] = result
	return result


# ============================================================
# Reading Strategy -- Use Standard Focus to shut down ALL opponent normals
# ============================================================
# Tactical rationale:
#   Standard Focus boost (Reading) lets AI name ANY normal card.
#   Opponent's next strike MUST use the named card, or they reveal hand.
#   This creates several powerful scenarios:
#   1. Name opponent's Block -> they can't block (Strike with Block = 0 damage)
#   2. Name opponent's Focus -> they waste Focus on a suboptimal strike
#   3. Name opponent's only in-range normal -> opponent must use a
#      suboptimal card or move instead (effectively discarding their option)
#   4. Name opponent's fastest normal (Flying Kick/Raid) -> neutralizes threat
#   5. At long range (5): name gap-closer, then opponent advances into OUR range
#      for a slow card unilateral hit
#   Combined with Spike (penetrates armor+guard), the Reading immediate
#   strike follow-up is a GUARANTEED unblockable hit.

func _score_reading_target(_card_id: int, defn, in_hand: bool, distance: int, my_best_strike_defn = null) -> float:
	# Score a normal card as a Reading target based on per-distance matchup strategy.
	# Distance 1: name opponent's Spike (range 2-3, can't hit at distance 1) -> free hit
	# Distance 2: name Block/Focus -> hit with Spike (penetrates)
	# Distance 3: name Spike/throw vs Assault/FlyingKick; throw/Sweep/Focus vs FlyingKick;
	#      Focus/Sweep/Block vs Spike
	# Distance 4: name throw vs FlyingKick; name Assault vs Sweep
	# Distance 5+: name Assault/FlyingKick -> use slow card (opponent moves first into range)
	var s: float = 0.0
	var ctype = defn.get("type", "")
	if ctype != "normal":
		return -100.0  # Reading can ONLY name normals
	if not in_hand:
		return 0.0

	var def_id_lower = defn.get("id", "").to_lower()
	var rmin = defn.get("range_min", 1)
	if rmin is String: rmin = 1
	var rmax = defn.get("range_max", rmin + 3)
	if rmax is String: rmax = rmin + 3

	var power = defn.get("power", 0)
	var speed = defn.get("speed", 0)
	if power is String: power = 0
	if speed is String: speed = 20

	# Detect card types
	var is_block: bool = "block" in def_id_lower
	var is_focus: bool = "focus" in def_id_lower
	var is_spike: bool = _is_spike_like(def_id_lower)
	var is_throw: bool = "grasp" in def_id_lower
	var is_sweep: bool = "sweep" in def_id_lower
	var is_assault: bool = "assault" in def_id_lower
	var is_flying_kick: bool = ("flying" in def_id_lower or "kick" in def_id_lower or "raid" in def_id_lower)
	var has_ignore_guard: bool = _def_has_effect(defn, "ignore_guard")
	var has_ignore_armor: bool = _def_has_effect(defn, "ignore_armor")

	# Can named card hit at current distance?
	var named_can_hit: bool = rmin <= distance and distance <= rmax

	# Get my strike info for matchup analysis
	var my_speed = 0
	var my_power = 0
	var _my_is_spike: bool = false
	var my_can_hit: bool = false
	var my_has_ignore_armor: bool = false
	if my_best_strike_defn != null:
		my_speed = my_best_strike_defn.get("speed", 0)
		if my_speed is String: my_speed = 20
		my_power = my_best_strike_defn.get("power", 0)
		if my_power is String: my_power = 0
		_my_is_spike = _is_spike_like(my_best_strike_defn.get("id", "").to_lower())
		my_has_ignore_armor = _def_has_effect(my_best_strike_defn, "ignore_armor")
		var my_rmin = my_best_strike_defn.get("range_min", 1)
		if my_rmin is String: my_rmin = 1
		var my_rmax = my_best_strike_defn.get("range_max", my_rmin + 3)
		if my_rmax is String: my_rmax = my_rmin + 3
		my_can_hit = my_rmin <= distance and distance <= my_rmax

	# ================================================================
	# Per-distance strategy (user-specified matchups)
	# ================================================================

	if distance == 1:
		# Distance 1: prefer naming Spike -- Spike (range 2-3) can't hit at distance 1!
		if is_spike:
			s += 100.0  # Spike can NEVER hit at distance 1 — opponent wastes turn
		elif is_block:
			s += 80.0   # Block = 0 damage, still excellent
		elif is_focus:
			s += 60.0   # Focus at dist 1 = waste draw engine
		elif is_throw:
			s += 30.0   # Throw CAN hit at dist 1 — only name if no better option
		elif named_can_hit:
			s += 15.0   # In-range card — lower priority at distance 1
		else:
			s += 40.0   # Out-of-range card — decent but Spike is better

	elif distance == 2:
		# Distance 2: name Block/Focus -> hit with Spike
		if is_block:
			s += 100.0  # Block = guaranteed 0 damage
		elif is_focus:
			s += 90.0   # Focus = waste draw, perfect with Spike follow-up
		elif is_spike:
			s += 70.0   # Spike CAN hit at dist 2, decent target
		elif is_throw and not named_can_hit:
			s += 60.0   # Throw out of range at dist 2 (range gap = 1)
		elif is_sweep and not named_can_hit:
			s += 40.0   # Sweep out of range
		elif named_can_hit:
			s += 20.0   # In-range card — lower priority
		else:
			s += 35.0   # Other out-of-range

	elif distance == 3:
		# Distance 3: AI strike determines naming:
		#   AI attacks with Assault/FlyingKick -> name Spike or throw
		#   AI attacks with FlyingKick -> name throw/Sweep/Focus
		#   AI attacks with Spike -> name Focus/Sweep/Block

		var my_strike_id = ""
		if my_best_strike_defn != null:
			my_strike_id = my_best_strike_defn.get("id", "").to_lower()

		var my_is_assault_strike: bool = "assault" in my_strike_id
		var my_is_fk_strike: bool = ("flying" in my_strike_id or "kick" in my_strike_id or "raid" in my_strike_id)
		var my_is_spike_strike: bool = _is_spike_like(my_strike_id)

		if my_is_assault_strike or my_is_fk_strike:
			# AI attacks with Assault/FlyingKick -> name Spike or throw
			if is_spike:
				s += 90.0
			elif is_throw:
				s += 85.0
			elif is_block:
				s += 55.0
			elif is_focus:
				s += 50.0
			elif named_can_hit:
				s += 25.0
			else:
				s += 35.0
		elif my_is_spike_strike:
			# AI attacks with Spike -> name Focus/Sweep/Block
			if is_focus:
				s += 90.0
			elif is_sweep:
				s += 85.0
			elif is_block:
				s += 80.0
			elif is_throw:
				s += 55.0
			elif is_spike:
				s += 50.0
			elif named_can_hit:
				s += 25.0
			else:
				s += 30.0
		else:
			# Other strikes
			if is_block:
				s += 85.0
			elif is_focus:
				s += 75.0
			elif is_spike:
				s += 70.0
			elif is_throw:
				s += 65.0
			elif is_sweep:
				s += 55.0
			elif is_assault:
				s += 55.0
			elif named_can_hit:
				s += 20.0
			else:
				s += 30.0

	elif distance == 4:
		# Distance 4: AI strike determines naming:
		#   AI attacks with FlyingKick -> name throw
		#   AI attacks with Sweep -> name Assault

		var my_strike_id_d4 = ""
		if my_best_strike_defn != null:
			my_strike_id_d4 = my_best_strike_defn.get("id", "").to_lower()

		var my_is_fk_d4: bool = ("flying" in my_strike_id_d4 or "kick" in my_strike_id_d4)
		var my_is_sweep_d4: bool = "sweep" in my_strike_id_d4

		if my_is_fk_d4:
			# AI attacks with FlyingKick -> name throw
			if is_throw:
				s += 100.0
			elif is_block:
				s += 65.0
			elif is_focus:
				s += 55.0
			elif is_assault:
				s += 70.0
			elif named_can_hit:
				s += 25.0
			else:
				s += 35.0
		elif my_is_sweep_d4:
			# AI attacks with Sweep -> name Assault
			if is_assault:
				s += 100.0
			elif is_throw:
				s += 75.0
			elif is_block:
				s += 65.0
			elif is_focus:
				s += 60.0
			elif is_sweep:
				s += 55.0
			elif named_can_hit:
				s += 25.0
			else:
				s += 35.0
		else:
			# Other strikes
			if is_throw:
				s += 80.0
			elif is_assault:
				s += 70.0
			elif is_sweep:
				s += 60.0
			elif is_block:
				s += 75.0
			elif is_focus:
				s += 65.0
			elif is_flying_kick:
				s += 55.0
			elif is_spike:
				s += 50.0
			elif named_can_hit:
				s += 25.0
			else:
				s += 35.0

	else:  # distance >= 5
		# Distance 5+: name Assault/FlyingKick -> slow card (opponent moves into range first)

		if is_assault or is_flying_kick:
			s += 90.0
			if my_best_strike_defn != null and my_speed <= speed:
				s += 30.0
		elif is_throw:
			s += 70.0
		elif is_spike:
			s += 60.0
		elif is_sweep:
			s += 55.0
		elif is_block:
			s += 70.0
		elif is_focus:
			s += 60.0
		elif named_can_hit:
			s += 15.0
		else:
			s += 40.0

	# Universal modifiers (apply at all distances)
	# ================================================================

	# Speed trap bonus: if named card is FAST and our strike is SLOW
	# → opponent goes first → moves → enters our range → we hit them
	if my_best_strike_defn != null:
		if speed > my_speed and my_can_hit:
			s += 15.0  # Named faster than our strike — opponent goes first
		if speed > my_speed and distance >= 4:
			s += 20.0  # Long range speed trap: opponent moves into range

	# Named card can't hit: opponent wastes turn
	if not named_can_hit:
		var range_gap: int
		if rmax < 0: range_gap = 0  # Block special
		elif distance > rmax: range_gap = distance - rmax
		elif distance < rmin: range_gap = rmin - distance
		else: range_gap = 0
		s += min(range_gap * 8.0, 40.0)  # Bonus proportional to how far out of range

	# Block armor penalty: when naming a block, it's only worth it with ignore-armor or big damage;
	# otherwise hitting a block leaves only 0-1 after armor, very low value (e.g. grasp into block deals only 1).
	if is_block:
		var _blk_armor = defn.get("armor", 0)
		if _blk_armor is String: _blk_armor = 0
		var _my_block_dmg: int = my_power if my_has_ignore_armor else max(my_power - int(_blk_armor), 0)
		if _my_block_dmg <= 1:
			s -= 60.0   # hitting block leaves only 0-1, don't name it
		elif _my_block_dmg <= 2:
			s -= 25.0   # hitting block leaves only 2, low value
		# ignore-armor or big damage (>=3) is not penalized, naming block is worth it

	# Penetration shutdown
	if has_ignore_guard or has_ignore_armor:
		s += 15.0  # Shut down their armor/guard bypass

	# Card power/speed modifiers (secondary at long range)
	if power <= 3: s += 10.0  # Weak — if they hit it doesn't hurt
	if speed <= 2: s += 10.0  # Slow — we can out-speed them

	return s


func _try_reading_combo(state: AIPlayer.AIGameState, boost_actions: Array, strike_actions: Array):
	var distance: int = _get_distance(state)
	var opp_analysis = _opponent_can_do_now(state)

	# ================================================================
	# SAFETY CHECK 0: AI must have at least one strike that can hit
	# NO Reading if AI has no follow-up attack
	# ================================================================
	var ai_has_any_hitting_strike: bool = false
	for cid in state.my_state.hand:
		if can_card_hit(cid, -1, state):
			ai_has_any_hitting_strike = true
			break
	if not ai_has_any_hitting_strike:
		return null

	# Step 1: Find a Standard Focus boost card (Reading-capable)
	# A Reading boost with an auto-attack (attacks using the boost card itself) -- its range must cover the current distance
	var reading_boost = null
	for ba in boost_actions:
		if ba is AIPlayer.BoostAction:
			if _has_reading_boost(ba.card_id, state):
				var rb_defn = _get_def(ba.card_id, state)
				if rb_defn:
					var rb_rmin = rb_defn.get("range_min", 1)
					if rb_rmin is String: rb_rmin = 1
					var rb_rmax = rb_defn.get("range_max", rb_rmin + 3)
					if rb_rmax is String: rb_rmax = rb_rmin + 3
					if rb_rmin <= distance and distance <= rb_rmax:
						reading_boost = ba
						break
					else:
						return null
	if not reading_boost:
		return null

	# Step 2: Determine what strike to pair with Reading based on distance
	var best_strike = null
	var best_strike_score: float = -999.0
	var best_strike_defn = null

	for sa in strike_actions:
		if sa is AIPlayer.StrikeAction:
			var defn = _get_def(sa.card_id, state)
			if not defn: continue
			var rmin = defn.get("range_min", 1)
			if rmin is String: rmin = 1
			var rmax = defn.get("range_max", rmin + 3)
			if rmax is String: rmax = rmin + 3
			if rmin > distance or rmax < distance: continue

			var sc: float = 0.0
			var spd = _get_effective_speed(sa.card_id, state, defn)
			var pwr = _get_effective_power(sa.card_id, defn)
			var cid_lower = defn.get("id", "").to_lower()
			var is_spike = _is_spike_like(cid_lower)
			var is_penetrating = _is_penetrating_card(sa.card_id, state)

			if distance == 1:
				if is_spike:
					sc -= 100.0
				elif rmin <= 1 and rmax >= 1:
					sc += pwr * 3.0 + spd * 2.0
			elif distance == 2:
				if is_spike or is_penetrating:
					sc += 40.0 + pwr * 3.0 + spd * 2.0
				else:
					sc += pwr * 2.0 + spd * 1.5
			elif distance == 3:
				if is_spike or is_penetrating:
					sc += 30.0 + pwr * 3.0 + spd * 2.0
				else:
					sc += pwr * 2.5 + spd * 1.5
			elif distance == 4:
				if is_spike:
					sc -= 50.0
				elif rmax >= 4:
					sc += pwr * 3.0 + spd * 1.5
					if spd <= 2: sc += 20.0
				else:
					sc += pwr * 1.0
			else:  # distance >= 5
				if spd <= 3 and rmax >= distance - 1:
					sc += pwr * 3.0 + 20.0
				elif rmax >= distance:
					sc += pwr * 2.0 + spd * 1.0
				else:
					sc -= 50.0

			if sa.ex_card_id != -1: sc += 5.0
			if spd >= opp_analysis["max_speed"]: sc += 10.0

			if sc > best_strike_score:
				best_strike_score = sc
				best_strike = sa
				best_strike_defn = defn

	# ================================================================
	# SAFETY CHECK 1: AI's best strike must actually be VIABLE
	# ================================================================
	var min_strike_score: float = 0.0
	if distance == 1: min_strike_score = 5.0
	elif distance >= 4: min_strike_score = -10.0
	if best_strike_score < min_strike_score:
		return null
	if not best_strike:
		return null

	# Step 3: Score each opponent normal card with best strike context
	var best_target_score: float = -999.0
	var best_target_defn = null
	var best_target_can_hit: bool = false
	for cid in _visible_opponent_hand(state):
		var defn = _get_def(cid, state)
		if not defn: continue
		if defn.get("type", "") != "normal": continue
		var in_hand: bool = true
		var sc = _score_reading_target(cid, defn, in_hand, distance, best_strike_defn)
		if sc > best_target_score:
			best_target_score = sc
			best_target_defn = defn
			# Check if named card can hit at current distance
			var trmin = defn.get("range_min", 1)
			if trmin is String: trmin = 1
			var trmax = defn.get("range_max", trmin + 3)
			if trmax is String: trmax = trmin + 3
			best_target_can_hit = trmin <= distance and distance <= trmax

	# ================================================================
	# SAFETY CHECK 2: Named target must not let opponent hit us freely
	# ================================================================
	if best_target_defn and best_target_can_hit:
		var target_id_lower = best_target_defn.get("id", "").to_lower()
		var target_is_block: bool = "block" in target_id_lower
		var target_is_focus: bool = "focus" in target_id_lower

		if not target_is_block and not target_is_focus:
			# Value trade: our best attack vs the named card's real life exchange
			var exchange: int = _card_exchange_value(best_strike_defn, best_target_defn, distance)
			if exchange < 0:
				return null

	# Step 4: Decide threshold
	var threshold: float = 20.0
	if distance == 1:
		threshold = 35.0  # distance 1 requires better target
	elif distance >= 4:
		threshold = 15.0

	if best_target_score >= threshold:
		return reading_boost

	return null
