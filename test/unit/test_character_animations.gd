extends GutTest

# Characters and buddies get their on-board sprite from
# res://assets/character_animations/<animation_id>/animations.tres. A missing
# file is not an error at runtime: character.gd silently falls back to the
# generic "custom" art, so a character ships looking like a placeholder without
# anything failing. These tests make the fallback explicit instead.

const AnimationRoot = "res://assets/character_animations/%s/animations.tres"

func _animation_ids_for_deck(deck : Dictionary) -> Array:
	var ids = [deck['id']]
	if 'exceed_animation' in deck and deck['exceed_animation']:
		ids.append(deck['exceed_animation'])
	if 'buddy_card' in deck and deck['buddy_card']:
		ids.append(deck['buddy_card'])
	var skip_buddy_graphics = 'no_buddy_card_graphics' in deck and deck['no_buddy_card_graphics']
	if 'buddy_card_graphics_id' in deck and not skip_buddy_graphics:
		for graphic_id in deck['buddy_card_graphics_id']:
			if graphic_id:
				ids.append(graphic_id)
	return ids

func _all_required_animations() -> Dictionary:
	# animation_id -> the deck ids that need it.
	# Skin decks are excluded: they resolve art through CharSkinManager, which
	# deliberately falls back to the base character's folder.
	var required = {}
	for deck_id in CardDataManager.decks:
		var deck = CardDataManager.decks[deck_id]
		if not deck is Dictionary or not 'id' in deck:
			continue
		if deck.get('base_id', deck['id']) != deck['id']:
			continue
		for animation_id in _animation_ids_for_deck(deck):
			if not animation_id in required:
				required[animation_id] = []
			required[animation_id].append(deck_id)
	return required

func test_every_deck_has_its_character_animations():
	var required = _all_required_animations()
	assert_gt(required.size(), 100, "expected animations for the full roster")

	var missing = []
	for animation_id in required:
		if not ResourceLoader.exists(AnimationRoot % animation_id):
			missing.append("%s (needed by %s)" % [animation_id, str(required[animation_id])])
	assert_eq(missing, [], "decks referencing animations that do not exist")

func test_every_animation_loads_with_an_idle_animation():
	var broken = []
	for animation_id in _all_required_animations():
		var path = AnimationRoot % animation_id
		if not ResourceLoader.exists(path):
			continue
		var frames = load(path)
		if frames == null or not frames is SpriteFrames:
			broken.append("%s did not load as SpriteFrames" % animation_id)
			continue
		if not frames.has_animation("idle"):
			broken.append("%s has no 'idle' animation" % animation_id)
			continue
		if frames.get_frame_count("idle") <= 0:
			broken.append("%s idle animation has no frames" % animation_id)
			continue
		if frames.get_frame_texture("idle", 0) == null:
			broken.append("%s idle frame 0 has no texture" % animation_id)
	assert_eq(broken, [], "animation resources that fail to load correctly")

func test_ported_characters_do_not_fall_back_to_placeholder_art():
	# These shipped without animations.tres and rendered as the generic
	# placeholder character.
	var ported = ["meilien", "ulrik", "luciya", "minato", "pooky", "renea",
		"syrus", "tournelouse", "umina", "shovelknight"]
	var placeholder = load(AnimationRoot % "custom")
	assert_not_null(placeholder, "the placeholder animation should exist")

	for animation_id in ported:
		var path = AnimationRoot % animation_id
		assert_true(ResourceLoader.exists(path), "%s has no animations.tres" % animation_id)
		if not ResourceLoader.exists(path):
			continue
		var frames = load(path)
		assert_not_null(frames, "%s failed to load" % animation_id)
		if frames == null:
			continue
		var texture = frames.get_frame_texture("idle", 0)
		assert_not_null(texture, "%s has no idle texture" % animation_id)
		if texture != null and placeholder != null:
			assert_ne(texture.resource_path, placeholder.get_frame_texture("idle", 0).resource_path,
				"%s is still using the placeholder art" % animation_id)

func test_umina_dreamlands_buddy_has_its_own_art():
	var deck = CardDataManager.get_deck_from_str_id("umina")
	assert_eq(deck['buddy_card'], "umina_dreamlands")
	var frames = load(AnimationRoot % "umina_dreamlands")
	assert_not_null(frames, "the Dreamlands buddy needs its own animation")
	if frames != null:
		assert_not_null(frames.get_frame_texture("idle", 0))

func test_renea_briefcase_buddy_has_its_own_art():
	var deck = CardDataManager.get_deck_from_str_id("renea")
	assert_eq(deck['buddy_card'], "briefcase")
	var frames = load(AnimationRoot % "briefcase")
	assert_not_null(frames, "the Briefcase buddy needs its own animation")
	if frames != null:
		assert_not_null(frames.get_frame_texture("idle", 0))

func test_ported_character_textures_stay_within_a_reasonable_size():
	# Character art is held in VRAM for the whole match and the client targets
	# mobile web, so oversized source art is a real memory problem. A lot of
	# older art predates this concern; this guards the recently added set.
	var max_dimension = 1400
	var ported = ["meilien", "ulrik", "luciya", "minato", "pooky", "renea",
		"syrus", "tournelouse", "umina", "shovelknight", "umina_dreamlands", "briefcase"]

	var oversized = []
	for animation_id in ported:
		var path = AnimationRoot % animation_id
		if not ResourceLoader.exists(path):
			continue
		var frames = load(path)
		if frames == null or not frames.has_animation("idle"):
			continue
		var texture = frames.get_frame_texture("idle", 0)
		if texture == null:
			continue
		var size = texture.get_size()
		if size.x > max_dimension or size.y > max_dimension:
			oversized.append("%s is %dx%d" % [animation_id, size.x, size.y])
	assert_eq(oversized, [], "character art larger than %dpx" % max_dimension)
