extends Node

# Character skin (alternate-costume) registry and resolution helpers.
#
# Skins are purely cosmetic. A skin is identified by a deck id of the form
# "<base_character>_<index>" (e.g. "ryu_1"). That deck id is what flows through
# the normal game-start payload, so skins sync IMPLICITLY between clients with no
# network protocol change: the opponent simply receives the resolved skin deck id.
#
# This project imports the skin SYSTEM and the (cosmetic-only) skin deck JSON, but
# NOT the skin art (character animations / skin portraits). Every art lookup below
# is existence-guarded and degrades gracefully to the base character's assets when
# the skin art is absent, so a skin with missing art renders exactly like its base
# character and never crashes. Drop skin art into
# `res://assets/character_animations_skin/<deck_id>/animations.tres` and/or
# `res://assets/portraits_skin/<deck_id>.png` later to enable it.
#
# Registry entry flags (per skin index):
#   portraits_skin      - use a custom portrait (res://assets/portraits_skin/<deck_id>.png)
#                         instead of the base character portrait.
#   portraits_url       - explicit override path for the custom portrait.
#   animations_skin     - use res://assets/character_animations_skin/<deck_id>/animations.tres.
#   exceed_change_skin  - while exceeded, swap to the "<deck_id>_exceed" skin animations.
#   buddy_skin          - use matching skinned buddy graphics for buddy graphics ids.

const DEFAULT_SKIN_LABEL := "Original"
const DEFAULT_EXTRA_SKIN_LABEL := "Skin %d"
const FALLBACK_PORTRAIT_PATH := "res://assets/portraits/custom.png"

# Hand-maintained registry. Only characters whose cosmetic-only skin deck JSON was
# imported are listed. Skin art is not imported, so these degrade to base visuals.
var CHARACTER_SKINS := {
	"akuma": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"bison": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"cammy": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": false, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"carlswangee": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"chunli": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": false, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"cviper": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"dan": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": false, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"enchantress": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"guile": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": false, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"ino": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"jin": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"ken": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"noel": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"ragna": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"ryu": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"sagat": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": false, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"vega": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": true, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
	"zangief": {
		"count": 1,
		"skins": {
			1: { "label": "Skin 1", "portraits_skin": false, "portraits_url": "", "animations_skin": false, "exceed_change_skin": false, "buddy_skin": false },
		},
	},
}

func get_skin_count(char_id: String) -> int:
	var skin_info = _get_skin_info(char_id)
	return max(int(skin_info.get("count", 0)), 0)

func get_total_button_count(char_id: String) -> int:
	return get_skin_count(char_id) + 1

func get_button_label(char_id: String, skin_index: int) -> String:
	if skin_index <= 0:
		return DEFAULT_SKIN_LABEL

	var skin = _get_skin(char_id, skin_index)
	return str(skin.get("label", DEFAULT_EXTRA_SKIN_LABEL % skin_index))

func get_portrait_override_path(char_id: String, skin_index: int) -> String:
	if skin_index <= 0 or skin_index > get_skin_count(char_id):
		return ""

	var skin = _get_skin(char_id, skin_index)
	if skin.get("portraits_skin", false) != true:
		return ""
	var portrait_override = str(skin.get("portraits_url", ""))
	if portrait_override.is_empty():
		portrait_override = "res://assets/portraits_skin/%s.png" % get_skin_deck_id(char_id, skin_index)
	return portrait_override

func get_portrait_path(char_id: String, skin_index: int) -> String:
	var portrait_override = get_portrait_override_path(char_id, skin_index)
	if portrait_override and ResourceLoader.exists(portrait_override, "Texture2D"):
		return portrait_override
	return _get_existing_portrait_or_fallback(_local_portrait_path(char_id))

func get_base_character_id(deck_id: String) -> String:
	for char_id in CHARACTER_SKINS:
		for skin_index in range(1, get_skin_count(char_id) + 1):
			if get_skin_deck_id(char_id, skin_index) == deck_id:
				return char_id
	return deck_id

func get_portrait_override_path_for_deck_id(deck_id: String) -> String:
	for char_id in CHARACTER_SKINS:
		for skin_index in range(1, get_skin_count(char_id) + 1):
			if get_skin_deck_id(char_id, skin_index) == deck_id:
				return get_portrait_override_path(char_id, skin_index)
	return ""

func get_portrait_path_for_deck_id(deck_id: String) -> String:
	var split_index = deck_id.find("#")
	if split_index != -1:
		deck_id = deck_id.substr(split_index + 1)
	for char_id in CHARACTER_SKINS:
		for skin_index in range(1, get_skin_count(char_id) + 1):
			if get_skin_deck_id(char_id, skin_index) == deck_id:
				return get_portrait_path(char_id, skin_index)
	return _get_existing_portrait_or_fallback(_local_portrait_path(deck_id))

func load_portrait_texture_for_deck_id(deck_id: String) -> Texture2D:
	return load(get_portrait_path_for_deck_id(deck_id)) as Texture2D

func _local_portrait_path(character_id: String) -> String:
	return "res://assets/portraits/%s.png" % character_id

func _get_existing_portrait_or_fallback(portrait_path: String) -> String:
	if ResourceLoader.exists(portrait_path, "Texture2D"):
		return portrait_path
	return FALLBACK_PORTRAIT_PATH

func get_animation_path_for_deck_id(deck_id: String) -> String:
	return get_animation_path_for_deck_and_animation_id(deck_id, deck_id)

func get_animation_path_for_deck_and_animation_id(deck_id: String, animation_id: String) -> String:
	for char_id in CHARACTER_SKINS:
		for skin_index in range(1, get_skin_count(char_id) + 1):
			var skin_deck_id = get_skin_deck_id(char_id, skin_index)
			var skin = _get_skin(char_id, skin_index)
			var animations_skin_enabled = skin.get("animations_skin", false) == true
			var exceed_change = skin.get("exceed_change_skin", false) == true
			var buddy_skin = skin.get("buddy_skin", false) == true

			# Exceed-swap animation requested directly for this skin.
			if deck_id == skin_deck_id + "_exceed" and animations_skin_enabled and exceed_change:
				return _skin_animation_or_base(
					"res://assets/character_animations_skin/%s/animations.tres" % deck_id,
					char_id)
			if skin_deck_id != deck_id:
				continue

			# Buddy graphics id for a skin with matching skinned buddy resources.
			if animation_id != deck_id and animations_skin_enabled and buddy_skin:
				var buddy_candidates = [
					"res://assets/character_animations_skin/%s/animations.tres" % animation_id,
					"res://assets/character_animations_skin/%s_%d/animations.tres" % [animation_id, skin_index],
				]
				var normalized_buddy_id = _remove_skin_suffix_if_matches(animation_id, skin_index)
				if normalized_buddy_id != animation_id:
					buddy_candidates.append("res://assets/character_animations_skin/%s_%d/animations.tres" % [normalized_buddy_id, skin_index])
				for candidate in buddy_candidates:
					if ResourceLoader.exists(candidate, "SpriteFrames"):
						return candidate
				# Skin buddy art missing: fall through to base buddy folder below.

			if animations_skin_enabled:
				if animation_id == deck_id:
					return _skin_animation_or_base(
						"res://assets/character_animations_skin/%s/animations.tres" % deck_id,
						char_id)
				if animation_id == "%s_exceed" % deck_id:
					if exceed_change:
						return _skin_animation_or_base(
							"res://assets/character_animations_skin/%s/animations.tres" % animation_id,
							char_id)
					return _skin_animation_or_base(
						"res://assets/character_animations_skin/%s/animations.tres" % deck_id,
						char_id)

			if animation_id == deck_id:
				return "res://assets/character_animations/%s/animations.tres" % char_id
			var normalized_animation_id = _remove_skin_suffix_if_matches(animation_id, skin_index)
			return "res://assets/character_animations/%s/animations.tres" % normalized_animation_id
	var official_path = "res://assets/character_animations/%s/animations.tres" % animation_id
	if ResourceLoader.exists(official_path, "SpriteFrames"):
		return official_path
	var custom_path = "res://assets/character_animations_custom/%s/animations.tres" % animation_id
	if ResourceLoader.exists(custom_path, "SpriteFrames"):
		return custom_path
	return official_path

# Returns the skin animation path when its art is present, otherwise falls back
# to the base character's animation folder so a missing skin never breaks.
func _skin_animation_or_base(skin_path: String, base_char_id: String) -> String:
	if ResourceLoader.exists(skin_path, "SpriteFrames"):
		return skin_path
	return "res://assets/character_animations/%s/animations.tres" % base_char_id

func get_skin_index_for_deck_id(deck_id: String) -> int:
	for char_id in CHARACTER_SKINS:
		for skin_index in range(1, get_skin_count(char_id) + 1):
			if get_skin_deck_id(char_id, skin_index) == deck_id:
				return skin_index
	return 0

func uses_skin_animation_for_deck_id(deck_id: String) -> bool:
	for char_id in CHARACTER_SKINS:
		for skin_index in range(1, get_skin_count(char_id) + 1):
			if get_skin_deck_id(char_id, skin_index) == deck_id:
				return _get_skin(char_id, skin_index).get("animations_skin", false) == true
	return false

func exceed_changes_skin_for_deck_id(deck_id: String) -> bool:
	for char_id in CHARACTER_SKINS:
		for skin_index in range(1, get_skin_count(char_id) + 1):
			if get_skin_deck_id(char_id, skin_index) == deck_id:
				var skin = _get_skin(char_id, skin_index)
				return skin.get("animations_skin", false) == true and \
						skin.get("exceed_change_skin", false) == true
	return false

func get_skin_deck_id(char_id: String, skin_index: int) -> String:
	if skin_index <= 0:
		return char_id
	if char_id.begins_with("random") or char_id.begins_with("custom_"):
		return char_id
	if skin_index > get_skin_count(char_id):
		return char_id
	return "%s_%d" % [char_id, skin_index]

func _get_skin_info(char_id: String) -> Dictionary:
	return CHARACTER_SKINS.get(char_id, {})

func _get_skin(char_id: String, skin_index: int) -> Dictionary:
	var skins: Dictionary = _get_skin_info(char_id).get("skins", {})
	return skins.get(skin_index, {})

func _remove_skin_suffix_if_matches(animation_id: String, skin_index: int) -> String:
	var suffix = "_%d" % skin_index
	if animation_id.ends_with(suffix):
		return animation_id.substr(0, animation_id.length() - suffix.length())
	return animation_id
