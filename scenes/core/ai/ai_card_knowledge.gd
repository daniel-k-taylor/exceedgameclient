class_name AICardKnowledge
extends RefCounted

## Whole-card-pool + counter-relation engine (standalone, self-contained).
##
## The AI carries a built-in "knowledge base of every card":
##   1. Accesses every character's every card definition via CardDataManager.card_data;
##   2. Buckets each card into an archetype (block/focus/spike/throw/sweep/cross/assault/...);
##   3. For any two cards, computes "who counters whom, and why" for attack decisions.


# ============================================================
# Basic stat accessors (tolerant of dynamic String values)
# ============================================================

func _num(v) -> int:
	if v is String:
		return 20  # treat a dynamic speed as the fastest
	return int(v)


func speed_of(defn: Dictionary) -> int:
	return _num(defn.get("speed", 0))


func power_of(defn: Dictionary) -> int:
	var v = defn.get("power", 0)
	return 0 if v is String else int(v)


func guard_of(defn: Dictionary) -> int:
	var v = defn.get("guard", 0)
	return 0 if v is String else int(v)


func armor_of(defn: Dictionary) -> int:
	var v = defn.get("armor", 0)
	return 0 if v is String else int(v)


func has_effect(defn: Dictionary, effect_type: String) -> bool:
	for eff in defn.get("effects", []):
		if eff.get("effect_type") == effect_type:
			return true
		var and_eff = eff.get("and", {})
		if and_eff is Dictionary and and_eff.get("effect_type") == effect_type:
			return true
	return false


# ============================================================
# Card archetype classification
# ============================================================

## Bucket a card into an archetype, used for counter-relation checks and threat self-awareness.
func classify(defn: Dictionary) -> String:
	if defn.is_empty():
		return "unknown"
	var dl: String = str(defn.get("id", "")).to_lower()
	if "block" in dl:
		return "block"
	if "focus" in dl:
		return "focus"
	if "spike" in dl or dl == "gg_normal_dust":
		return "spike"
	if "throw" in dl or "grasp" in dl:
		return "throw"
	if "sweep" in dl:
		return "sweep"
	if "cross" in dl:
		return "cross"
	if "assault" in dl:
		return "assault"
	if "dive" in dl:
		return "dive"
	# Fall back to effect-based signatures
	var ig: bool = has_effect(defn, "ignore_guard")
	var ia: bool = has_effect(defn, "ignore_armor")
	if ig and ia:
		return "spike"
	if ig:
		return "guard_break"
	if ia:
		return "armor_break"
	if has_effect(defn, "stun"):
		return "stunner"
	if speed_of(defn) >= 7:
		return "fast"
	if guard_of(defn) >= 5:
		return "tank"
	return "standard"


## Which archetypes a given archetype counters (returns the list of archetypes it beats).
func counters_of(archetype: String) -> Array:
	match archetype:
		"spike", "guard_break":
			return ["block", "tank", "guard_break"]  # ignore-guard/penetrate beats high-guard and block
		"armor_break":
			return ["tank", "armored"]
		"throw":
			return ["tank", "block"]
		"fast":
			return ["sweep", "slow"]
		"block":
			return ["sweep", "throw"]  # block beats heavy, slow attacks
		"sweep":
			return ["block"]
		"stunner":
			return ["fast"]
		_:
			return []


## Which archetypes counter a given archetype.
func countered_by(archetype: String) -> Array:
	match archetype:
		"block", "tank":
			return ["spike", "guard_break", "armor_break"]
		"sweep":
			return ["fast", "block"]
		"throw":
			return ["block", "fast"]
		"focus":
			return ["spike"]
		_:
			return []


# ============================================================
# Two-card counter relation
# ============================================================

## Compute the counter relation of "my my_def vs opponent opp_def" (excluding movement dodges;
## the precise net exchange is computed separately by the policy's _eval_counter_response).
## Returns {label, reason, my_first, my_stuns, opp_stuns, my_win}.
func counter_relation(my_def: Dictionary, opp_def: Dictionary) -> Dictionary:
	var my_speed: int = speed_of(my_def)
	var opp_speed: int = speed_of(opp_def)
	var my_power: int = power_of(my_def)
	var opp_power: int = power_of(opp_def)
	var my_guard: int = guard_of(my_def)
	var opp_guard: int = guard_of(opp_def)
	var my_armor: int = armor_of(my_def)
	var opp_armor: int = armor_of(opp_def)
	var my_ig: bool = has_effect(my_def, "ignore_guard")
	var my_ia: bool = has_effect(my_def, "ignore_armor")
	var opp_ig: bool = has_effect(opp_def, "ignore_guard")
	var opp_ia: bool = has_effect(opp_def, "ignore_armor")

	# First-strike check: the initiator wins on equal speed
	var my_first: bool = my_speed >= opp_speed
	# Stun check: my power > opponent's effective guard (ignore-guard treats guard as 0)
	var my_stuns: bool = my_power > (0 if my_ig else opp_guard)
	var opp_stuns: bool = opp_power > (0 if opp_ig else my_guard)
	# Damage
	var my_dmg: int = max(my_power - (0 if my_ia else opp_armor), 0)
	var opp_dmg: int = max(opp_power - (0 if opp_ia else my_armor), 0)

	var label: String = "even"
	var reasons: Array = []

	if my_first and my_stuns:
		label = "counter"
		reasons.append("first-strike stun")
	elif not my_first and opp_stuns:
		label = "countered"
		reasons.append("stunned by first strike")
	elif my_ia and opp_armor > 0:
		label = "counter"
		reasons.append("ignore armor")
	elif opp_ia and my_armor > 0:
		label = "countered"
		reasons.append("armor ignored")
	elif my_ig and opp_guard >= 3:
		label = "counter"
		reasons.append("ignore guard")
	elif my_dmg - opp_dmg >= 3:
		label = "counter"
		reasons.append("net +%d life" % (my_dmg - opp_dmg))
	elif opp_dmg - my_dmg >= 3:
		label = "countered"
		reasons.append("net -%d life" % (opp_dmg - my_dmg))

	return {
		"label": label,
		"reason": ", ".join(reasons) if reasons.size() > 0 else "even",
		"my_first": my_first,
		"my_stuns": my_stuns,
		"opp_stuns": opp_stuns,
		"my_win": my_first and (my_stuns or my_dmg >= opp_dmg),
	}


# ============================================================
# Whole-pool queries
# ============================================================

## From the whole card pool (every card of every character), find the opponent card
## definition that best counters my_def. Used for threat self-awareness: knowing what
## this card of mine is afraid of.
func best_counter_in_pool(my_def: Dictionary) -> Dictionary:
	var pool: Dictionary = CardDataManager.card_data
	var best: Dictionary = {}
	var best_score: int = -999
	for def_id in pool:
		var opp_def: Dictionary = pool[def_id]
		if opp_def.get("type", "") != "normal" and opp_def.get("type", "") != "special":
			continue
		var rel: Dictionary = counter_relation(my_def, opp_def)
		var score: int = 0
		if rel["label"] == "countered":
			score = 10
		elif rel["opp_stuns"]:
			score = 8
		elif rel["label"] == "even":
			score = 1
		if score > best_score:
			best_score = score
			best = opp_def
	return best
