extends Node2D

const StartingHandFirstPlayer = 5
const StartingHandSecondPlayer = 6
const MaxLife = 30
const MaxHandSize = 7
const MaxReshuffle = 1
const WildSwingCardId = 7
const MinArenaLocation = 1
const MaxArenaLocation = 9

var NextCardId = 1
var all_cards : Array = []
var game_over : bool = false
var active_strike : Strike = null
var decision_player : Player = null
var decision_type : DecisionType
var decision_choice

enum DecisionType {
	DecisionType_EffectChoice,
	DecisionType_PayStrikeCost,
	DecisionType_ForceForArmor,
}

enum GameState {
	GameState_NotStarted,
	GameState_PickAction,
	GameState_DiscardDownToMax,
	GameState_Strike_Opponent_Response,
	GameState_Strike_PlayerDecision,
}
var game_state : GameState = GameState.GameState_NotStarted

func change_game_state(new_state : GameState):
	printlog("game_state update from %s to %s" % [GameState.keys()[game_state], GameState.keys()[new_state]])
	game_state = new_state

enum EventType {
	EventType_AddToGauge,
	EventType_AddToDiscard,
	EventType_AdvanceTurn,
	EventType_Discard,
	EventType_Draw,
	EventType_GameOver,
	EventType_HandSizeExceeded,
	EventType_Move,
	EventType_ReshuffleDiscard,
	EventType_Strike_ArmorUp,
	EventType_Strike_DodgeAttacks,
	EventType_Strike_EffectChoice,
	EventType_Strike_ForceForArmor,
	EventType_Strike_GainAdvantage,
	EventType_Strike_GuardUp,
	EventType_Strike_IgnoredPushPull,
	EventType_Strike_Miss,
	EventType_Strike_PayCost,
	EventType_Strike_PowerUp,
	EventType_Strike_Response,
	EventType_Strike_Reveal,
	EventType_Strike_Started,
	EventType_Strike_Stun,
	EventType_Strike_TookDamage,
}

func printlog(text):
	print(text)

func create_event(event_type : EventType, event_player : Player, num : int):
	var card_name = get_card_name(num)
	printlog("Event %s %s %d (card=%s)" % [EventType.keys()[event_type], event_player.name, num, card_name])
	return {
		"event_type": event_type,
		"event_player": event_player,
		"number": num,
		"early_exit": event_type == EventType.EventType_GameOver
	}

func should_exit(events):
	return events[len(events) - 1]['early_exit']

enum StrikeState {
	StrikeState_Card1_PayCosts,
	StrikeState_Card2_PayCosts,
	StrikeState_DuringStrikeBonuses,
	StrikeState_Card1_Before,
	StrikeState_Card1_DetermineHit,
	StrikeState_Card1_Hit,
	StrikeState_Card1_ApplyDamage,
	StrikeState_Card1_After,
	StrikeState_Card2_Before,
	StrikeState_Card2_DetermineHit,
	StrikeState_Card2_Hit,
	StrikeState_Card2_ApplyDamage,
	StrikeState_Card2_After,
	StrikeState_Cleanup,
}

class Strike:
	var initiator : Player
	var defender : Player
	var initiator_card : Card
	var defender_card : Card
	var initiator_first : bool
	var strike_state
	var effects_resolved_in_state : int
	var player1_hit : bool = false
	var player1_stunned : bool = false
	var player2_hit : bool = false
	var player2_stunned : bool = false

	func get_card(num : int):
		if initiator_first:
			if num == 1: return initiator_card
			return defender_card
		else:
			if num == 1: return defender_card
			return initiator_card

	func get_player(num : int):
		if initiator_first:
			if num == 1: return initiator
			return defender
		else:
			if num == 1: return defender
			return initiator

	func get_player_card(performing_player : Player) -> Card:
		if performing_player == initiator:
			return initiator_card
		return defender_card

class Card:
	var id
	var definition
	var image

	func _init(card_id, card_def, card_image):
		id = card_id
		definition = card_def
		image = card_image

class StrikeStatBoosts:
	var power : int = 0
	var armor : int = 0
	var guard : int = 0
	var dodge_attacks : bool = false
	var ignore_armor : bool = false
	var ignore_guard : bool = false
	var ignore_push_and_pull : bool = false
	var always_add_to_gauge : bool = false
	var when_hit_force_for_armor : bool = false

	func clear():
		power = 0
		armor = 0
		guard = 0
		dodge_attacks = false
		ignore_armor = false
		ignore_guard = false
		ignore_push_and_pull = false
		always_add_to_gauge = false
		when_hit_force_for_armor = false

class Player:
	var parent

	var name : String
	var life : int
	var hand : Array
	var deck : Array
	var discards : Array
	var deck_def : Dictionary
	var gauge : Array
	var boosts : Array
	var arena_location : int
	var reshuffle_remaining : int
	var exceeded : bool
	var exceed_cost : int
	var strike_stat_boosts : StrikeStatBoosts

	func _init(player_name, parent_ref, chosen_deck, card_start_id):
		name = player_name
		parent = parent_ref
		life = MaxLife
		hand = []
		deck_def = chosen_deck
		exceed_cost = deck_def['character']['exceed_cost']
		deck = []
		strike_stat_boosts = StrikeStatBoosts.new()
		for deck_card_def in deck_def['cards']:
			var card_def = CardDefinitions.get_card(deck_card_def['definition_id'])
			var card = Card.new(card_start_id, card_def, deck_card_def['image'])
			deck.append(card)
			card_start_id += 1
		deck.shuffle()
		gauge = []
		boosts = []
		discards = []
		reshuffle_remaining = MaxReshuffle
		exceeded = false

	func is_card_in_hand(id : int):
		for card in hand:
			if card.id == id:
				return true
		return false

	func remove_card_from_hand(id : int):
		for i in range(len(hand)):
			if hand[i].id == id:
				hand.remove_at(id)
				break

	func is_card_in_gauge(id : int):
		for card in gauge:
			if card.id == id:
				return true
		return false

	func draw(num_to_draw : int):
		var events : Array = []
		for i in range(num_to_draw):
			if len(deck) > 0:
				var card = deck[0]
				hand.append(card)
				deck.remove_at(0)
				events += [parent.create_event(EventType.EventType_Draw, self, card.id)]
			else:
				events += reshuffle_discard()
				if not parent.game_over:
					var card = deck[0]
					hand.append(card)
					deck.remove_at(0)
					events += [parent.create_event(EventType.EventType_Draw, self, card.id)]
		return events

	func reshuffle_discard():
		var events : Array = []
		if reshuffle_remaining == 0:
			# Game Over
			events += [parent.create_event(EventType.EventType_GameOver, self, 0)]
			parent.game_over = true
		else:
			# Put discard into deck, shuffle, subtract reshuffles
			deck += discards
			discards = []
			deck.shuffle()
			reshuffle_remaining -= 1
			events += [parent.create_event(EventType.EventType_ReshuffleDiscard, self, reshuffle_remaining)]
		return events

	func discard(card_ids : Array):
		var events = []
		for discard_id in card_ids:
			# From hand
			for i in range(len(hand)-1, -1, -1):
				var card = hand[i]
				if card.id == discard_id:
					discards.append(card)
					hand.remove_at(i)
					events += [parent.create_event(EventType.EventType_Discard, self, card.id)]
					break

			# From gauge
			for i in range(len(gauge)-1, -1, -1):
				var card = gauge[i]
				if card.id == discard_id:
					discards.append(card)
					gauge.remove_at(i)
					events += [parent.create_event(EventType.EventType_Discard, self, card.id)]
					break
		return events

	func discard_random(amount):
		var events = []
		for i in range(amount):
			if len(hand) > 0:
				var random_card_id = hand[randi() % len(hand)].id
				events += discard(random_card_id)
		return events

	func add_to_gauge(card):
		gauge.append(card)
		return [parent.create_event(EventType.EventType_AddToGauge, self, card.id)]

	func add_to_discards(card):
		discards.append(card)
		return [parent.create_event(EventType.EventType_AddToDiscard, self, card.id)]

	func get_available_force():
		var force = 0
		for card in hand:
			force += parent.get_card_force(card.id)
		for card in gauge:
			force += parent.get_card_force(card.id)
		return force

	func get_available_gauge():
		return len(gauge)

	func can_move_to(new_arena_location):
		if new_arena_location == arena_location: return false
		var other_player_loc = parent.other_player(self).arena_location
		if  other_player_loc == new_arena_location: return false
		var required_force = get_force_to_move_to(new_arena_location)
		return required_force <= get_available_force()

	func get_force_to_move_to(new_arena_location):
		var other_player_loc = parent.other_player(self).arena_location
		var required_force = abs(arena_location - new_arena_location)
		if ((arena_location < other_player_loc and new_arena_location > other_player_loc)
			or (new_arena_location < other_player_loc and arena_location > other_player_loc)):
			# No additional force needed because of abs calculation.
			#required_force += 1
			pass
		return required_force

	func move_to(new_arena_location):
		var events = []
		arena_location = new_arena_location
		events += [parent.create_event(EventType.EventType_Move, self, new_arena_location)]
		return events

	func close(amount):
		var events = []
		var other_location = parent.other_player(self).arena_location
		var new_location
		if arena_location < other_location:
			new_location = min(other_location-1, arena_location+amount)
		else:
			new_location = max(other_location+1, arena_location-amount)
		arena_location = new_location
		events += [parent.create_event(EventType.EventType_Move, self, new_location)]
		return events

	func advance(amount):
		var events = []
		var other_location = parent.other_player(self).arena_location
		var new_location
		if arena_location < other_location:
			new_location = arena_location + amount
			if new_location >= other_location:
				new_location += 1
			new_location = min(new_location, MaxArenaLocation)
		else:
			new_location = arena_location - amount
			if new_location <= other_location:
				new_location -= 1
			new_location = max(new_location, MinArenaLocation)

		arena_location = new_location
		events += [parent.create_event(EventType.EventType_Move, self, new_location)]

		return events

	func retreat(amount):
		var events = []
		var other_location = parent.other_player(self).arena_location
		var new_location
		if arena_location < other_location:
			new_location = arena_location - amount
			new_location = max(new_location, MinArenaLocation)
		else:
			new_location = arena_location + amount
			new_location = min(new_location, MaxArenaLocation)

		arena_location = new_location
		events += [parent.create_event(EventType.EventType_Move, self, new_location)]

		return events

	func push(amount):
		var events = []
		var other_player = parent.other_player(self)
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(EventType.EventType_Strike_IgnoredPushPull, other_player, 0)]
		else:
			var other_location = other_player.arena_location
			var new_location
			if arena_location < other_location:
				new_location = other_location + amount
				new_location = min(new_location, MaxArenaLocation)
			else:
				new_location = other_location - amount
				new_location = max(new_location, MinArenaLocation)

			other_player.arena_location = new_location
			events += [parent.create_event(EventType.EventType_Move, other_player, new_location)]

		return events

	func pull(amount):
		var events = []
		var other_player = parent.other_player(self)
		if other_player.strike_stat_boosts.ignore_push_and_pull:
			events += [parent.create_event(EventType.EventType_Strike_IgnoredPushPull, other_player, 0)]
		else:
			var other_location = other_player.arena_location
			var new_location
			if arena_location < other_location:
				new_location = other_location - amount
				if arena_location >= new_location:
					new_location -= 1
				new_location = max(new_location, MinArenaLocation)
			else:
				new_location = other_location + amount
				if arena_location <= new_location:
					new_location += 1
				new_location = min(new_location, MaxArenaLocation)

			other_player.arena_location = new_location
			events += [parent.create_event(EventType.EventType_Move, other_player, new_location)]

		return events

var player : Player
var opponent : Player

var active_turn_player : Player
var next_turn_player : Player

func initialize_game(player_deck, opponent_deck):
	player = Player.new("Player", self, player_deck, 100)
	opponent = Player.new("Opponent", self, opponent_deck, 200)

	for card in player.deck:
		all_cards.append(card)
	for card in opponent.deck:
		all_cards.append(card)

	active_turn_player = player
	player.arena_location = 3
	next_turn_player = opponent
	opponent.arena_location = 7

	player.draw(StartingHandFirstPlayer)
	opponent.draw(StartingHandSecondPlayer)

	change_game_state(GameState.GameState_PickAction)

func get_card(id : int):
	for card in all_cards:
		if card.id == id:
			return card
	return null

func get_card_name(id : int):
	for card in all_cards:
		if card.id == id:
			return card.definition['id']
	return "MISSING CARD"

func get_card_force(id : int):
	var card = get_card(id)
	if card.definition['type'] == 'ultra':
		return 2
	return 1

func get_card_gauge_cost(id : int):
	var card = get_card(id)
	return card.definition['gauge_cost']

func get_card_effects(card : Card, effect_type):
	var relevant_effects = []
	for effect in card['definition']['effects']:
		if effect['timing'] == effect_type:
			relevant_effects.append(effect)
	return relevant_effects

func other_player(test_player : Player) -> Player:
	if test_player == player:
		return opponent
	return player

func advance_to_next_turn():
	active_turn_player = next_turn_player
	next_turn_player = other_player(active_turn_player)
	change_game_state(GameState.GameState_PickAction)
	return [create_event(EventType.EventType_AdvanceTurn, active_turn_player, 0)]

func begin_resolve_strike():
	var events = []
	# Strike is just beginning.
	events += [create_event(EventType.EventType_Strike_Reveal, active_strike.initiator, 0)]

	active_strike.initiator.strike_stat_boosts.clear()
	active_strike.defender.strike_stat_boosts.clear()

	# Determine activation
	active_strike.initiator_first = active_strike.initiator_card.definition['speed'] >= active_strike.defender_card.definition['speed']
	active_strike.strike_state = StrikeState.StrikeState_Card1_PayCosts
	active_strike.effects_resolved_in_state = 0

	events = continue_strike_activation()
	return events

func is_effect_condition_met(effect, global_conditions : GlobalStrikeConditions, local_conditions : LocalStrikeConditions):
	if "condition" in effect:
		var condition = effect['condition']
		if condition == "initiated_strike" and global_conditions.initiated_strike:
			return true
		elif condition == "not_initiated_strike" and not global_conditions.initiated_strike:
			return true
		elif condition == "not_full_close" and not local_conditions.fully_closed:
			return true
		elif condition == "advanced_through" and local_conditions.advanced_through:
			return true
		elif condition == "not_full_push" and not local_conditions.fully_pushed:
			return true
		elif condition == "pulled_past" and local_conditions.pulled_past:
			return true
		# Unmet condition
		return false
	return true

class GlobalStrikeConditions:
	var initiated_strike : bool

class LocalStrikeConditions:
	var fully_closed : bool = false
	var fully_retreated : bool = false
	var fully_pushed : bool = false
	var advanced_through : bool = false
	var pulled_past : bool = false

func handle_strike_effect(effect, performing_player : Player, global_conditions : GlobalStrikeConditions):
	printlog("STRIKE: Handling effect %s" % [effect])
	var events = []
	var local_conditions = LocalStrikeConditions.new()
	var performing_start = performing_player.arena_location
	var opposing_player = other_player(performing_player)
	var other_start = opposing_player.arena_location
	match effect['effect_type']:
		"close":
			events += performing_player.close(effect['amount'])
			var new_location = performing_player.arena_location
			var close_amount = abs(performing_start - new_location)
			local_conditions.fully_closed = close_amount == effect['amount']
		"advance":
			events += performing_player.advance(effect['amount'])
			var new_location = performing_player.arena_location
			if (performing_start < other_start and new_location > other_start) or (performing_start > other_start and new_location < other_start):
				local_conditions.advanced_through = true
		"retreat":
			events += performing_player.retreat(effect['amount'])
			var new_location = performing_player.arena_location
			var retreat_amount = abs(performing_start - new_location)
			local_conditions.fully_retreated = retreat_amount == effect['amount']
		"push":
			events += performing_player.push(effect['amount'])
			var new_location = opposing_player.arena_location
			var push_amount = abs(other_start - new_location)
			local_conditions.fully_pushed = push_amount == effect['amount']
		"pull":
			events += performing_player.pull(effect['amount'])
			var new_location = opposing_player.arena_location
			if (other_start < performing_start and new_location > performing_start) or (other_start > performing_start and new_location < performing_start):
				local_conditions.pulled_past = true
		"gain_advantage":
			next_turn_player = performing_player
			events += [create_event(EventType.EventType_Strike_GainAdvantage, performing_player, 0)]
		"powerup":
			performing_player.strike_stat_boosts.power += effect['amount']
			events += [create_event(EventType.EventType_Strike_PowerUp, performing_player, effect['amount'])]
		"armorup":
			performing_player.strike_stat_boosts.armor += effect['amount']
			events += [create_event(EventType.EventType_Strike_ArmorUp, performing_player, effect['amount'])]
		"guardup":
			performing_player.strike_stat_boosts.guard += effect['amount']
			events += [create_event(EventType.EventType_Strike_GuardUp, performing_player, effect['amount'])]
		"draw":
			events += performing_player.draw(effect['amount'])
		"dodge_attacks":
			performing_player.strike_stat_boosts.dodge_attacks = true
			events += [create_event(EventType.EventType_Strike_DodgeAttacks, performing_player, effect['amount'])]
		"opponent_discard_random":
			events += opposing_player.discard_random(effect['amount'])
		"ignore_push_and_pull":
			performing_player.strike_stat_boosts.ignore_push_and_pull = true
		"ignore_guard":
			performing_player.strike_stat_boosts.ignore_guard = true
		"ignore_armor":
			performing_player.strike_stat_boosts.ignore_armor = true
		"when_hit_force_for_armor":
			performing_player.strike_stat_boosts.when_hit_force_for_armor = true
		"add_to_gauge":
			performing_player.strike_stat_boosts.always_add_to_gauge = true
		"choice":
			change_game_state(GameState.GameState_Strike_PlayerDecision)
			decision_type = DecisionType.DecisionType_EffectChoice
			decision_player = performing_player
			decision_choice = effect['choice']
			events += [create_event(EventType.EventType_Strike_EffectChoice, performing_player, 0)]

	if not game_state == GameState.GameState_Strike_PlayerDecision and "bonus_effect" in effect:
		var bonus_effect = effect['bonus_effect']
		if is_effect_condition_met(bonus_effect, global_conditions, local_conditions):
			events += handle_strike_effect(bonus_effect, performing_player, global_conditions)

	return events

func do_effects_for_state(state_name : String, performing_player : Player, card : Card, global_conditions : GlobalStrikeConditions, next_state):
	var events = []
	var effects = get_card_effects(card, state_name)
	for i in range(active_strike.effects_resolved_in_state, len(effects)):
		if is_effect_condition_met(effects[i], global_conditions, null):
			events += handle_strike_effect(effects[i], performing_player, global_conditions)
		active_strike.effects_resolved_in_state += 1
		if game_state == GameState.GameState_Strike_PlayerDecision:
			break

	# All before effects have been resolved.
	active_strike.strike_state = next_state
	active_strike.effects_resolved_in_state = 0
	return events

func in_range(atacking_player, defending_player, card):
	if defending_player.strike_stat_boosts.dodge_attacks:
		return false
	var min_range = card.definition['range_min']
	var max_range = card.definition['range_max']
	var distance = abs(atacking_player.arena_location - defending_player.arena_location)
	if min_range <= distance and distance <= max_range:
		return true
	return false

func apply_damage(offense_player : Player, defense_player : Player, offense_card : Card, defense_card : Card):
	var events = []
	var damage = offense_card.definition['power'] + offense_player.strike_stat_boosts.power
	var armor = defense_card.definition['armor'] + defense_player.strike_stat_boosts.armor
	var guard = defense_card.definition['guard'] + defense_player.strike_stat_boosts.guard

	if offense_player.strike_stat_boosts.ignore_guard:
		guard = 0
	if offense_player.strike_stat_boosts.ignore_armor:
		armor = 0

	var damage_after_armor = max(damage - armor, 0)
	defense_player.life -= damage_after_armor
	events += [create_event(EventType.EventType_Strike_TookDamage, defense_player, damage_after_armor)]
	if damage_after_armor > guard:
		events += [create_event(EventType.EventType_Strike_Stun, defense_player, damage_after_armor-guard)]

	if defense_player.life <= 0:
		events += [create_event(EventType.EventType_GameOver, defense_player, 0)]
		game_over = true
	return events

func ask_for_cost(performing_player, card, next_state):
	var events = []
	var gauge_cost = card.definition['gauge_cost']
	var force_cost = card.definition['force_cost']
	if gauge_cost == 0 and force_cost == 0:
		active_strike.strike_state = next_state
	else:
		change_game_state(GameState.GameState_Strike_PlayerDecision)
		decision_player = performing_player
		decision_type = DecisionType.DecisionType_PayStrikeCost

		if gauge_cost > 0:
			events += [create_event(EventType.EventType_Strike_PayCost, performing_player, card.id)]
		elif force_cost > 0:
			events += [create_event(EventType.EventType_Strike_PayCost, performing_player, card.id)]
	return events

func continue_strike_activation():
	# Activate 1
	# Activate 2 (if not stunned)
	# cleanup
	# End of turn

	# Active steps:
	# BEFORE triggers
	# Check range
	# Perform HIT triggers if range
	# Apply damage if range
	# AFTER triggers - always


	#TODO:

# "timing": "hit",
# "choice": [
# 	{ "effect_type": "push", "amount": 1 },
# 	{ "effect_type": "push", "amount": 2 },
# 	{ "effect_type": "pull", "amount": 1 },
# 	{ "effect_type": "pull", "amount": 2 }
# ]
#
# ],

	var events = []

	var card1 = active_strike.get_card(1)
	var card2 = active_strike.get_card(2)
	var player1 = active_strike.get_player(1)
	var player2 = active_strike.get_player(2)

	var global_conditions = GlobalStrikeConditions.new()
	global_conditions.initiated_strike = active_strike.initiator_first

	while true:
		if game_state == GameState.GameState_Strike_PlayerDecision:
			printlog("STRIKE: Breaking for decision %s %s" % [decision_player.name, DecisionType.keys()[decision_type]])
			break

		printlog("STRIKE: processing state %s " % [StrikeState.keys()[active_strike.strike_state]])
		match active_strike.strike_state:
			StrikeState.StrikeState_Card1_PayCosts:
				events += ask_for_cost(player1, card1, StrikeState.StrikeState_Card2_PayCosts)
			StrikeState.StrikeState_Card2_PayCosts:
				events += ask_for_cost(player2, card2, StrikeState.StrikeState_DuringStrikeBonuses)
			StrikeState.StrikeState_DuringStrikeBonuses:
				events += do_effects_for_state("during_strike", player1, card1, global_conditions, StrikeState.StrikeState_DuringStrikeBonuses)
				events += do_effects_for_state("during_strike", player2, card2, global_conditions, StrikeState.StrikeState_Card1_Before)
				active_strike.strike_state = StrikeState.StrikeState_Card1_Before
			StrikeState.StrikeState_Card1_Before:
				events += do_effects_for_state("before", player1, card1, global_conditions, StrikeState.StrikeState_Card1_DetermineHit)
			StrikeState.StrikeState_Card1_DetermineHit:
				if in_range(player1, player2, card1):
					active_strike.player1_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card1_Hit
				else:
					events += [create_event(EventType.EventType_Strike_Miss, player1, 0)]
					active_strike.strike_state = StrikeState.StrikeState_Card1_After
			StrikeState.StrikeState_Card1_Hit:
				events += do_effects_for_state("hit", player1, card1, global_conditions, StrikeState.StrikeState_Card1_ApplyDamage)
				if player2.strike_stat_boosts.when_hit_force_for_armor:
					change_game_state(GameState.GameState_Strike_PlayerDecision)
					decision_player = player2
					decision_type = DecisionType.DecisionType_ForceForArmor
					events += [create_event(EventType.EventType_Strike_ForceForArmor, decision_player, 0)]
			StrikeState.StrikeState_Card1_ApplyDamage:
				events += apply_damage(player1, player2, card1, card2)
				active_strike.strike_state = StrikeState.StrikeState_Card1_After
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card1_After:
				events += do_effects_for_state("after", player1, card1, global_conditions, StrikeState.StrikeState_Card2_Before)
			StrikeState.StrikeState_Card2_Before:
				if active_strike.player2_stunned:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
				else:
					events += do_effects_for_state("before", player2, card2, global_conditions, StrikeState.StrikeState_Card2_DetermineHit)
			StrikeState.StrikeState_Card2_DetermineHit:
				if in_range(player2, player1, card2):
					active_strike.player2_hit = true
					active_strike.strike_state = StrikeState.StrikeState_Card2_Hit
				else:
					events += [create_event(EventType.EventType_Strike_Miss, player2, 0)]
					active_strike.strike_state = StrikeState.StrikeState_Card2_After
			StrikeState.StrikeState_Card2_Hit:
				events += do_effects_for_state("hit", player2, card2, global_conditions, StrikeState.StrikeState_Card2_ApplyDamage)
			StrikeState.StrikeState_Card2_ApplyDamage:
				events += apply_damage(player2, player1, card2, card1)
				active_strike.strike_state = StrikeState.StrikeState_Card2_After
				if game_over:
					active_strike.strike_state = StrikeState.StrikeState_Cleanup
			StrikeState.StrikeState_Card2_After:
				events += do_effects_for_state("after", player2, card2, global_conditions, StrikeState.StrikeState_Cleanup)
			StrikeState.StrikeState_Cleanup:
				# If hit, move card to gauge, otherwise move to discard.
				if active_strike.player1_hit or player1.strike_stat_boosts.always_add_to_gauge:
					events += player1.add_to_gauge(card1)
				else:
					events += player1.add_to_discards(card1)

				if active_strike.player2_hit or player2.strike_stat_boosts.always_add_to_gauge:
					events += player2.add_to_gauge(card2)
				else:
					events += player2.add_to_discards(card2)

				events += advance_to_next_turn()
				break
	return events

func can_do_prepare(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	return true

func can_do_move(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	# Check if the player can generate force (2 if cornered)
	var force_needed = 1
	if ((performing_player.arena_location == 1 and other_player(performing_player).arena_location == 2)
		or (performing_player.arena_location == 9 and other_player(performing_player).arena_location == 8)):
		force_needed = 2
		pass

	var force_available = performing_player.get_available_force()
	if force_available >= force_needed:
		return true
	return false

func can_do_change(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	var force_available = performing_player.get_available_force()
	return force_available > 0

func can_do_exceed(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	if performing_player.exceeded:
		return false

	var gauge_available = len(performing_player.gauge)
	return gauge_available >= performing_player.exceed_cost

func can_do_reshuffle(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false
	if len(performing_player.discards) == 0:
		return false
	return performing_player.reshuffle_remaining > 0

func can_do_boost(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	var force_available = performing_player.get_available_force()
	for card in performing_player.hand:
		if card.definition['boost']['force_cost'] <= force_available:
			return true

	return false

func can_do_strike(performing_player : Player):
	if game_state != GameState.GameState_PickAction:
		return false
	if active_turn_player != performing_player:
		return false

	# Can always wild swing!

	return true

func do_prepare(performing_player):
	if not can_do_prepare(performing_player):
		print("ERROR: Tried to Prepare but can't.")
		return []

	var events : Array = performing_player.draw(2)
	if len(performing_player.hand) > MaxHandSize:
		change_game_state(GameState.GameState_DiscardDownToMax)
		events += [create_event(EventType.EventType_HandSizeExceeded, performing_player, len(performing_player.hand) - MaxHandSize)]
	else:
		events += advance_to_next_turn()

	return events

func do_discard_to_max(performing_player : Player, card_ids):
	if performing_player != active_turn_player:
		print("ERROR: Tried to discard for wrong player.")
		return []
	if game_state != GameState.GameState_DiscardDownToMax:
		print("ERROR: Tried to discard wrong game state.")
		return []

	for id in card_ids:
		if not performing_player.is_card_in_hand(id):
			# Card not found, error
			print("ERROR: Tried to discard cards that aren't in hand.")
			return []

	if len(performing_player.hand) - len(card_ids) > MaxHandSize:
		print("ERROR: Not discarding enough cards")
		return []

	var events = performing_player.discard(card_ids)
	events += advance_to_next_turn()

	return events

func do_move(performing_player : Player, card_ids, new_arena_location):
	if not can_do_move(performing_player):
		print("ERROR: Cannot perform the move action for this player.")
		return []

	if not performing_player.can_move_to(new_arena_location):
		print("ERROR: Unable to move to that arena location.")
		return []

	# Ensure cards are in hand/gauge
	for id in card_ids:
		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			print("ERROR: Tried to discard cards that aren't in hand/gauge.")
			return []

	# Ensure cards generate enough force.
	var required_force = performing_player.get_force_to_move_to(new_arena_location)
	var generated_force = 0
	for id in card_ids:
		generated_force += get_card_force(id)

	if generated_force < required_force:
		print("ERROR: Not enough force with these cards to move there.")
		return []

	var events = performing_player.discard(card_ids)
	events += performing_player.move_to(new_arena_location)
	events += performing_player.draw(1)
	events += advance_to_next_turn()
	return events

func do_change(performing_player : Player, card_ids):
	if not can_do_change(performing_player):
		print("ERROR: Cannot do change action for this player.")
		return []

	for id in card_ids:
		if not performing_player.is_card_in_hand(id) and not performing_player.is_card_in_gauge(id):
			# Card not found, error
			print("ERROR: Tried to discard cards that aren't in hand or gauge.")
			return []

	var num_cards = len(card_ids)
	var events = performing_player.discard(card_ids)
	events += performing_player.draw(num_cards + 1)
	if len(performing_player.hand) > MaxHandSize:
		change_game_state(GameState.GameState_DiscardDownToMax)
		events += [create_event(EventType.EventType_HandSizeExceeded, performing_player, len(performing_player.hand) - MaxHandSize)]
	else:
		events += advance_to_next_turn()

	return events

func do_strike(performing_player : Player, card_id : int):
	printlog("Starting strike player %s card %d" % [performing_player.name, get_card_name(card_id)])
	if game_state == GameState.GameState_PickAction:
		if performing_player != active_turn_player:
			print("ERROR: Tried to strike but not current player")
			return []
	elif game_state == GameState.GameState_Strike_Opponent_Response:
		if performing_player != other_player(active_turn_player):
			print("ERROR: Strike response from wrong player.")
			return []

	if not performing_player.is_card_in_hand(card_id):
		print("ERROR: Tried to strike with a card not in hand.")
		return []

	# Begin the strike
	var events = []

	# Lay down the strike
	if game_state == GameState.GameState_PickAction:
		active_strike = Strike.new()
		active_strike.initiator = performing_player
		active_strike.initiator_card = get_card(card_id)
		active_strike.defender = other_player(performing_player)
		performing_player.remove_card_from_hand(card_id)
		events += [create_event(EventType.EventType_Strike_Started, performing_player, card_id)]
		change_game_state(GameState.GameState_Strike_Opponent_Response)
	elif game_state == GameState.GameState_Strike_Opponent_Response:
		active_strike.defender_card = get_card(card_id)
		performing_player.remove_card_from_hand(card_id)
		events += [create_event(EventType.EventType_Strike_Response, performing_player, card_id)]
		events += begin_resolve_strike()
	return events

func do_pay_strike_costs(performing_player : Player, card_ids : Array):
	if game_state != GameState.GameState_Strike_PlayerDecision:
		print("ERROR: Tried to pay costs but not in decision state.")
		return []
	if decision_type != DecisionType.DecisionType_PayStrikeCost:
		print("ERROR: Tried to pay costs but not in pay costs decision.")
		return []
	if performing_player != decision_player:
		print("ERROR: Tried to pay costs for wrong player.")
		return []

	var card = active_strike.get_player_card(performing_player)
	var force_cost = card.definition['force_cost']
	var gauge_cost = card.definition['gauge_cost']
	if force_cost > 0:
		var force_generated = 0
		for card_id in card_ids:
			if performing_player.is_card_in_hand(card_id) or performing_player.is_card_in_gauge(card_id):
				force_generated += get_card_force(card_id)
			else:
				print("ERROR: Tried to use force card not in hand or gauge.")
				return []
		if force_generated < force_cost:
			print("ERROR: Not generating enough force for this strike.")
			return []
	elif gauge_cost > 0:
		var gauge_generated = 0
		for card_id in card_ids:
			if performing_player.is_card_in_gauge(card_id):
				gauge_generated += 1
			else:
				print("ERROR: Tried to use card not in gauge.")
				return []
		if gauge_generated < gauge_cost:
			print("ERROR: Not generating enough gauge for this strike.")
			return []

	# Discard cards
	var events = []
	events += performing_player.discard(card_ids)

	# Continue strike
	match active_strike.strike_state:
		StrikeState.StrikeState_Card1_PayCosts:
			active_strike.strike_state = StrikeState.StrikeState_Card2_PayCosts
		StrikeState.StrikeState_Card2_PayCosts:
			active_strike.strike_state = StrikeState.StrikeState_DuringStrikeBonuses

	events += continue_strike_activation()

	return events


