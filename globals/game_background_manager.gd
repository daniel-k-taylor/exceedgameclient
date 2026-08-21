extends RefCounted

# Personal display preference for the in-game arena background / map.
#
# This system is NOT network-synced: each player renders whichever background
# they have chosen locally (stored in GlobalSettings). The registry below is
# data-driven and tolerant of backgrounds whose image assets are not present in
# the project: any entry whose texture cannot be loaded resolves to `null`, and
# callers are expected to fall back to the classic board look. Additional
# backgrounds can be added later simply by dropping the matching art into
# `res://assets/ui/<url_id>/` and registering an entry here.
#
# Asset layout for a background with id `BGn`:
#   res://assets/ui/<url_id>/<image_id>              full-screen background image
#   res://assets/ui/<url_id>/arena/{B|R}{1..9}.png   per-space track tiles (when standard_arena == false)
# Backgrounds with `standard_arena == true` instead share the tile set at:
#   res://assets/ui/standard_arena/{B|R}{1..9}.png

const DEFAULT_BACKGROUND_ID := "classic"
const DEFAULT_MAIN_MENU_BACKGROUND_ID := "MP1"
const DEFAULT_MAIN_MENU_BACKGROUND_COLOR := Color(0, 0.482353, 0.482353)
const STANDARD_ARENA_DIRECTORY := "res://assets/ui/standard_arena"
const BACKGROUND_ROOT_DIRECTORY := "res://assets/ui"
const MAIN_MENU_BACKGROUND_ROOT_DIRECTORY := "res://assets/mainmenu_picture"

# NOTE: The main-menu picture assets are not imported into this project. Entries
# without art are retained so the system stays complete and data-driven, but only
# entries marked `available` are offered in the UI. An entry may render either a
# full-screen texture (`url_id` + `image_id`) or a flat `color`; solid colours
# need no art at all, so they are always safe to ship.
const MainMenu_BACKGROUNDS := {
	"MP1": {
		"label": "Solid Color 1",
		"color": Color(0, 0.482353, 0.482353),
		"available": true,
	},
	"MP7": {
		"label": "Solid Color 2",
		"color": Color(0.305882, 0.305882, 0.305882),
		"available": true,
	},
	"MP2": {
		"label": "Capcom Group",
		"url_id": "mp2",
		"image_id": "2_2.jpg",
	},
	"MP3": {
		"label": "Capcom 1",
		"url_id": "mp3",
		"image_id": "3.jpg",
	},
	"MP4": {
		"label": "Capcom 2",
		"url_id": "mp4",
		"image_id": "4.jpg",
	},
	"MP5": {
		"label": "Capcom 3",
		"url_id": "mp5",
		"image_id": "5.jpg",
	},
	"MP6": {
		"label": "Chun-Li 1",
		"url_id": "mp6",
		"image_id": "6.jpg",
	},
	"MP8": {
		"label": "Seventh Cross",
		"url_id": "mp8",
		"image_id": "8.jpg",
	},
	"MP9": {
		"label": "Chun-Li 2",
		"url_id": "mp9",
		"image_id": "9.jpg",
	},
	"MP10": {
		"label": "Chun-Li vs Cammy",
		"url_id": "mp10",
		"image_id": "10.jpg",
	},
}

# Only `classic` and `BG1` ship art in this project, so only those (plus `random`)
# are marked `available` and offered in the UI / picked by Random. The remaining
# entries are registered for completeness/forward-compatibility; drop the matching
# art into `res://assets/ui/<url_id>/` and flip `available` to enable them.
const BACKGROUNDS := {
	"random": {
		"label": "Random Each Match",
		"available": true,
	},
	"classic": {
		"label": "BG0 Classic",
		"url_id": "",
		"image_id": "",
		"standard_arena": false,
		"available": true,
	},
	"BG1": {
		"label": "BG1 Forest",
		"url_id": "BG1",
		"image_id": "BG1.jpg",
		"standard_arena": false,
		"available": true,
	},
	"BG2": {
		"label": "BG2 Ruins",
		"url_id": "BG2",
		"image_id": "BG2.jpg",
		"standard_arena": true,
	},
	"BG3": {
		"label": "BG3 Ruins 2",
		"url_id": "BG3",
		"image_id": "BG3.jpg",
		"standard_arena": true,
	},
	"BG4": {
		"label": "BG4 Canyon",
		"url_id": "BG4",
		"image_id": "BG4.jpg",
		"standard_arena": true,
	},
	"BG5": {
		"label": "BG5 Street",
		"url_id": "BG5",
		"image_id": "BG5.jpg",
		"standard_arena": true,
	},
	"BG6": {
		"label": "BG6 Night Harbor",
		"url_id": "BG6",
		"image_id": "BG6.jpg",
		"standard_arena": true,
	},
	"BG7": {
		"label": "BG7 Gate of the Dead",
		"url_id": "BG7",
		"image_id": "BG7.jpg",
		"standard_arena": true,
	},
	"BG8": {
		"label": "BG8 Secluded Valley",
		"url_id": "BG8",
		"image_id": "BG8.jpg",
		"standard_arena": true,
	},
	"BG9": {
		"label": "BG9 Street 2",
		"url_id": "BG9",
		"image_id": "BG9.jpg",
		"standard_arena": true,
	},
	"BG10": {
		"label": "BG10 Red Lotus Temple",
		"url_id": "BG10",
		"image_id": "BG10.jpg",
		"standard_arena": true,
	},
	"BG11": {
		"label": "BG11 Sanzu River (Fake)",
		"url_id": "BG11",
		"image_id": "BG11.jpg",
		"standard_arena": true,
	},
	"BG22": {
		"label": "BG22 Sanzu River (True)",
		"url_id": "BG22",
		"image_id": "BG22.jpg",
		"standard_arena": true,
	},
	"BG12": {
		"label": "BG12 Ruins 3",
		"url_id": "BG12",
		"image_id": "BG12.jpg",
		"standard_arena": true,
	},
	"BG13": {
		"label": "BG13 Deck",
		"url_id": "BG13",
		"image_id": "BG13.jpg",
		"standard_arena": true,
	},
	"BG14": {
		"label": "BG14 Stage",
		"url_id": "BG14",
		"image_id": "BG14.jpg",
		"standard_arena": true,
	},
	"BG15": {
		"label": "BG15 Lava",
		"url_id": "BG15",
		"image_id": "BG15.jpg",
		"standard_arena": true,
	},
	"BG16": {
		"label": "BG16 Street 3",
		"url_id": "BG16",
		"image_id": "BG16.jpg",
		"standard_arena": true,
	},
	"BG17": {
		"label": "BG17 Energy",
		"url_id": "BG17",
		"image_id": "BG17.jpg",
		"standard_arena": true,
	},
	"BG18": {
		"label": "BG18 Dojo",
		"url_id": "BG18",
		"image_id": "BG18.jpg",
		"standard_arena": true,
	},
	"BG19": {
		"label": "BG19 Snow Village",
		"url_id": "BG19",
		"image_id": "BG19.jpg",
		"standard_arena": true,
	},
	"BG20": {
		"label": "BG20 Arcade",
		"url_id": "BG20",
		"image_id": "BG20.jpg",
		"standard_arena": true,
	},
	"BG21": {
		"label": "BG21 Street 4",
		"url_id": "BG21",
		"image_id": "BG21.jpg",
		"standard_arena": true,
	},
}

static var _texture_cache := {}

static func is_random_background_id(background_id: String) -> bool:
	return background_id == "random"

static func is_main_menu_background_available(background_id: String) -> bool:
	var definition: Dictionary = MainMenu_BACKGROUNDS.get(background_id, {})
	return definition.get("available", false)

static func get_all_main_menu_background_ids() -> Array[String]:
	var background_ids: Array[String] = []
	for background_id in MainMenu_BACKGROUNDS:
		background_ids.append(background_id)
	return background_ids

static func get_main_menu_background_ids() -> Array[String]:
	# Only the entries whose assets ship with this project are offered.
	var background_ids: Array[String] = []
	for background_id in MainMenu_BACKGROUNDS:
		if is_main_menu_background_available(background_id):
			background_ids.append(background_id)
	return background_ids

static func normalize_main_menu_background_id(background_id: String) -> String:
	if is_main_menu_background_available(background_id):
		return background_id
	return DEFAULT_MAIN_MENU_BACKGROUND_ID

static func get_main_menu_background_definition(background_id: String) -> Dictionary:
	return MainMenu_BACKGROUNDS[normalize_main_menu_background_id(background_id)]

static func get_main_menu_background_label(background_id: String) -> String:
	return get_main_menu_background_definition(background_id).get("label", background_id)

static func get_main_menu_background_texture(background_id: String) -> Texture2D:
	var resource_path := get_main_menu_background_resource_path(background_id)
	return _load_texture(resource_path)

static func get_main_menu_background_color(background_id: String) -> Color:
	# Solid-colour menu backgrounds need no art; the menu paints this behind the
	# (optional) texture.
	var definition := get_main_menu_background_definition(background_id)
	return definition.get("color", DEFAULT_MAIN_MENU_BACKGROUND_COLOR)

static func get_main_menu_background_resource_path(background_id: String) -> String:
	var definition := get_main_menu_background_definition(background_id)
	var url_id: String = definition.get("url_id", "")
	var image_id: String = definition.get("image_id", "")
	if url_id.is_empty() or image_id.is_empty():
		return ""
	return "%s/%s/%s" % [MAIN_MENU_BACKGROUND_ROOT_DIRECTORY, url_id, image_id]

static func is_background_available(background_id: String) -> bool:
	var definition: Dictionary = BACKGROUNDS.get(background_id, {})
	return definition.get("available", false)

static func get_all_background_ids() -> Array[String]:
	var background_ids: Array[String] = []
	for background_id in BACKGROUNDS:
		background_ids.append(background_id)
	return background_ids

static func get_background_ids() -> Array[String]:
	# Only the entries whose art ships with this project are offered.
	var background_ids: Array[String] = []
	for background_id in BACKGROUNDS:
		if is_background_available(background_id):
			background_ids.append(background_id)
	return background_ids

static func get_selectable_background_id(background_id: String) -> String:
	# What the settings UI should show for a stored id, which may name a
	# background that is registered but currently hidden.
	if is_background_available(background_id):
		return background_id
	return DEFAULT_BACKGROUND_ID

static func get_randomizable_background_ids() -> Array[String]:
	var background_ids: Array[String] = []
	for background_id in get_background_ids():
		if not is_random_background_id(background_id):
			background_ids.append(background_id)
	return background_ids

static func resolve_background_id(background_id: String) -> String:
	var normalized_id := normalize_background_id(background_id)
	if not is_background_available(normalized_id):
		# A previously-saved background whose art no longer ships.
		return DEFAULT_BACKGROUND_ID
	if not is_random_background_id(normalized_id):
		return normalized_id
	var randomizable_ids := get_randomizable_background_ids()
	if randomizable_ids.is_empty():
		return DEFAULT_BACKGROUND_ID
	return randomizable_ids.pick_random()

static func normalize_background_id(background_id: String) -> String:
	# Permissive on purpose: metadata for registered-but-hidden backgrounds still
	# resolves so art can be dropped in later. Availability is enforced by the UI
	# list and by `resolve_background_id` when a match actually renders.
	if BACKGROUNDS.has(background_id):
		return background_id
	return DEFAULT_BACKGROUND_ID

static func get_background_definition(background_id: String) -> Dictionary:
	return BACKGROUNDS[normalize_background_id(background_id)]

static func get_background_label(background_id: String) -> String:
	return get_background_definition(background_id).get("label", background_id)

static func uses_classic_arena(background_id: String) -> bool:
	var definition := get_background_definition(background_id)
	return definition.get("url_id", "").is_empty() or definition.get("image_id", "").is_empty()

static func get_background_texture(background_id: String) -> Texture2D:
	var resource_path := get_background_resource_path(background_id)
	return _load_texture(resource_path)

static func get_arena_texture(background_id: String, prefix: String, location: int) -> Texture2D:
	var resource_path := get_arena_resource_path(background_id, prefix, location)
	return _load_texture(resource_path, false)

static func get_background_resource_path(background_id: String) -> String:
	var definition := get_background_definition(background_id)
	var url_id: String = definition.get("url_id", "")
	var image_id: String = definition.get("image_id", "")
	if url_id.is_empty() or image_id.is_empty():
		return ""
	return "%s/%s/%s" % [BACKGROUND_ROOT_DIRECTORY, url_id, image_id]

static func get_arena_resource_path(background_id: String, prefix: String, location: int) -> String:
	if prefix != "B" and prefix != "R":
		return ""
	if location < 1 or location > 9:
		return ""
	var definition := get_background_definition(background_id)
	var arena_directory := STANDARD_ARENA_DIRECTORY
	if not definition.get("standard_arena", true):
		var url_id: String = definition.get("url_id", "")
		if url_id.is_empty():
			return ""
		arena_directory = "%s/%s/arena" % [BACKGROUND_ROOT_DIRECTORY, url_id]
	return "%s/%s%d.png" % [arena_directory, prefix, location]

static func clear_match_texture_cache():
	for resource_path in _texture_cache.keys():
		if resource_path.begins_with(BACKGROUND_ROOT_DIRECTORY + "/"):
			_texture_cache.erase(resource_path)

static func _load_texture(resource_path: String, keep_cached := true) -> Texture2D:
	if resource_path.is_empty() or not ResourceLoader.exists(resource_path):
		return null
	if not keep_cached:
		return load(resource_path) as Texture2D
	if not _texture_cache.has(resource_path):
		_texture_cache[resource_path] = load(resource_path) as Texture2D
	return _texture_cache[resource_path]
