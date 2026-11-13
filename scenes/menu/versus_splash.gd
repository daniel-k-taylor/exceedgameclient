class_name VersusSplash
extends Node2D

var start_me_position = Vector2(-950,20)
var final_me_position = Vector2(50,20)

var start_you_position = Vector2(440 + 1000, 460)
var final_you_position = Vector2(440, 460)

var label_font_normal = 90
var label_font_small = 60
var label_length_threshold = 15

const tween_duration = 1.0

@onready var me_deck_label : Label = $MeNameBox/MeDeckHbox/MyDeckLabel
@onready var you_deck_label : Label = $YouNameBox/YouDeckHbox/YouDeckLabel
@onready var me_portrait : TextureRect = $MeNameBox/MeDeckHbox/MePortrait
@onready var you_portrait : TextureRect = $YouNameBox/YouDeckHbox/YouPortrait
@onready var loading_status_box : PanelContainer = $LoadingStatusBox
@onready var loading_status_label : Label = $LoadingStatusBox/MarginContainer/LoadingStatusLabel

func set_loading_status(status_text : String):
	loading_status_box.visible = true
	loading_status_label.text = status_text

# --- Phone (portrait) layout ---

func _phone_panel(tint : Color) -> Panel:
	var panel := Panel.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r, tint.g, tint.b, 0.22)
	sb.border_color = Color(tint.r, tint.g, tint.b, 0.75)
	sb.set_border_width_all(3)
	sb.set_corner_radius_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return panel

func _phone_style_label(label : Label, size : int) -> void:
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 8)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func _phone_layout() -> void:
	var cs := Vector2(get_window().content_scale_size)
	var W := cs.x
	var H := cs.y
	var pad := 36.0
	var box_w := W - pad * 2.0

	# Background: same red -> blue gradient, filling the whole portrait screen.
	var bg : TextureRect = $Background
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.position = Vector2.ZERO
	bg.size = cs + Vector2(0, 800) # overshoots the bottom so a late viewport resize can't uncover the game
	_phone_active = true
	_last_cs = cs
	var grad := bg.texture as GradientTexture2D
	if grad != null:
		grad = grad.duplicate()
		grad.fill_from = Vector2(0.1, 0.0)
		grad.fill_to = Vector2(0.9, 1.0)
		bg.texture = grad

	var blocks := []
	for entry in [
			[$MeNameBox, me_portrait, me_deck_label, $MeNameBox/MyNameLabel, Color(0.95, 0.2, 0.15)],
			[$YouNameBox, you_portrait, you_deck_label, $YouNameBox/YouNameLabel, Color(0.2, 0.4, 1.0)]]:
		var box : VBoxContainer = entry[0]
		var portrait : TextureRect = entry[1]
		var deck : Label = entry[2]
		var pname : Label = entry[3]
		box.set_anchors_preset(Control.PRESET_TOP_LEFT, false)
		box.grow_horizontal = Control.GROW_DIRECTION_END
		box.grow_vertical = Control.GROW_DIRECTION_END
		box.alignment = BoxContainer.ALIGNMENT_CENTER
		box.add_theme_constant_override("separation", 6)
		box.custom_minimum_size = Vector2(box_w - 48.0, 0)
		# Portrait on top, centered; deck name below it, then the player's name.
		if portrait.get_parent() != box:
			portrait.reparent(box, false)
			box.move_child(portrait, 0)
		portrait.custom_minimum_size = Vector2(240, 240)
		portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		portrait.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var deck_row : HBoxContainer = deck.get_parent()
		deck_row.alignment = BoxContainer.ALIGNMENT_CENTER
		deck.custom_minimum_size = Vector2(box_w - 48.0, 0)
		_phone_style_label(deck, 64 if deck.text.length() <= label_length_threshold else 46)
		_phone_style_label(pname, 34)
		pname.modulate = Color(1, 1, 1, 0.9)
		var panel := _phone_panel(entry[4])
		add_child(panel)
		move_child(panel, box.get_index())
		blocks.append({"box": box, "panel": panel})
		box.reset_size()

	await get_tree().process_frame

	# VS in the middle with a rule on each side.
	var vs : Label = $VSLabel
	_phone_style_label(vs, 130)
	vs.size = Vector2(W, 160)
	vs.position = Vector2(0, H / 2.0 - 80.0)
	vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	for rule_x in [pad, W / 2.0 + 110.0]:
		var rule := ColorRect.new()
		rule.color = Color(1, 1, 1, 0.45)
		rule.position = Vector2(rule_x, H / 2.0 - 2.0)
		rule.size = Vector2(W / 2.0 - 110.0 - pad, 4)
		rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(rule)

	# Player on top (slides in from the left), opponent below (from the right).
	var gap := 40.0
	var my_box : VBoxContainer = blocks[0]["box"]
	var op_box : VBoxContainer = blocks[1]["box"]
	var my_h : float = my_box.get_combined_minimum_size().y
	var op_h : float = op_box.get_combined_minimum_size().y
	var my_y : float = vs.position.y - gap - my_h
	var op_y : float = vs.position.y + vs.size.y + gap
	var box_x := (W - my_box.get_combined_minimum_size().x) / 2.0
	var targets := [Vector2(box_x, my_y), Vector2(box_x, op_y)]
	var heights := [my_h, op_h]
	var tween := get_tree().create_tween().set_parallel(true)
	for i in range(2):
		var box : Control = blocks[i]["box"]
		var panel : Panel = blocks[i]["panel"]
		var start_x : float = -W if i == 0 else W
		panel.size = Vector2(box.get_combined_minimum_size().x + 56.0, heights[i] + 44.0)
		var panel_offset := Vector2(-28.0, -22.0)
		box.position = Vector2(start_x, targets[i].y)
		panel.position = Vector2(start_x, targets[i].y) + panel_offset
		tween.tween_property(box, "position", targets[i], tween_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(panel, "position", targets[i] + panel_offset, tween_duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)

	# Loading status near the bottom, centered.
	loading_status_box.custom_minimum_size.x = minf(440.0, box_w)
	loading_status_box.position = Vector2((W - loading_status_box.custom_minimum_size.x) / 2.0, H - 170.0)

var _phone_active := false
var _last_cs := Vector2.ZERO

# The phone screen can finish rotating (and the viewport grow taller) after the splash laid
# itself out; keep the background and the loading box matched to the real viewport.
func _process(_delta : float) -> void:
	if not _phone_active:
		return
	var cs := Vector2(get_window().content_scale_size)
	if cs == _last_cs:
		return
	_last_cs = cs
	var bg : TextureRect = $Background
	bg.size = cs + Vector2(0, 800)
	loading_status_box.position = Vector2((cs.x - loading_status_box.custom_minimum_size.x) / 2.0, cs.y - 170.0)

func load_portrait_texture(texture_rect : TextureRect, random_tag : String, deck_id : String):
	match random_tag:
		"random":
			texture_rect.texture = load("res://assets/portraits/exceedrandom.png")
		"random_s1":
			texture_rect.texture = load("res://assets/portraits/redhorizon.png")
		"random_s2":
			texture_rect.texture = load("res://assets/portraits/sclogo.png")
		"random_s3":
			texture_rect.texture = load("res://assets/portraits/sflogo.png")
		"random_s4":
			texture_rect.texture = load("res://assets/portraits/sklogo.png")
		"random_s5":
			texture_rect.texture = load("res://assets/portraits/blazbluelogo2.png")
		"random_s6":
			texture_rect.texture = load("res://assets/portraits/unilogo.png")
		"random_s7":
			texture_rect.texture = load("res://assets/portraits/random.png")
		"random_s8":
			texture_rect.texture = load("res://assets/portraits/stlogo.png")
		_:
			if deck_id.begins_with("custom_") and deck_id in ImageCache.loaded_portraits:
				texture_rect.texture = ImageCache.loaded_portraits[deck_id]
			else:
				texture_rect.texture = load("res://assets/portraits/" + deck_id + ".png")
			# fallback
			if not texture_rect.texture:
				texture_rect.texture = load("res://assets/portraits/custom.png")

func set_info(vs_info):
	var my_char_name = vs_info['player_deck']['display_name']
	me_deck_label.text = my_char_name
	if len(my_char_name) <= label_length_threshold:
		me_deck_label.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		me_deck_label.set("theme_override_font_sizes/font_size", label_font_small)
	$MeNameBox/MyNameLabel.text = vs_info['player_name']

	var your_char_name = vs_info['opponent_deck']['display_name']
	you_deck_label.text = your_char_name
	if len(your_char_name) <= label_length_threshold:
		you_deck_label.set("theme_override_font_sizes/font_size", label_font_normal)
	else:
		you_deck_label.set("theme_override_font_sizes/font_size", label_font_small)
	$YouNameBox/YouNameLabel.text = vs_info['opponent_name']

	# Setup portraits
	var player_deck_id = vs_info['player_deck']['id']
	var player_random_tag = vs_info['player_random_tag']
	var opponent_deck_id = vs_info['opponent_deck']['id']
	var opponent_random_tag = vs_info['opponent_random_tag']
	load_portrait_texture(me_portrait, player_random_tag, player_deck_id)
	load_portrait_texture(you_portrait, opponent_random_tag, opponent_deck_id)

# Called when the node enters the scene tree for the first time.
func _ready():
	if CardBase.phone_mode:
		# Draw above every game UI layer (menu button, popouts, ...) while loading.
		z_index = 200
		# Portrait phone layout: laid out once set_info() has filled in the text.
		_phone_layout.call_deferred()
		return
	$MeNameBox.position = start_me_position
	$YouNameBox.position = start_you_position
	var me_tween = get_tree().create_tween()
	me_tween.tween_property($MeNameBox, "position", final_me_position, tween_duration)
	var you_tween = get_tree().create_tween()
	you_tween.tween_property($YouNameBox, "position", final_you_position, tween_duration)
