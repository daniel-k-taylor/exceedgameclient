class_name PhoneLayout
extends Node

# Portrait "phone" layout for the game scene. Created by Game._ready() when
# GlobalSettings.PhoneLayoutEnabled is true. It does not replace any game
# logic: it creates the portrait backdrop (top bar, stage, gauge strips, arena
# strip, hand area, bottom bar) and re-positions the existing game nodes into
# it, so cards/characters keep animating to the same zone nodes they always did.
#
#  top bar    life bars, clocks, menu button
#  stage      P1 sprite (left / "red"), P2 sprite (right / "blue"), strike
#             cards, focused-card preview, action menu overlaid at the top
#  gauge      6 slots per player showing the card-type icon of each gauge card
#  arena      9 squares with small character icons showing arena positions
#  hand       player's hand, overlapping, rightmost card on top
#  bottom     sealed | character ability text | deck | discard

# Flip to true to paint the wireframe colours from the design mock-ups
# (lime top bar, red/blue stage halves, pink hand area).
const DEBUG_ZONE_COLORS := false

const DESIGN_W := 720
const DESIGN_H := 1560
const CARD_W := 250.0
const CARD_H := 350.0
const OFFSCREEN := Vector2(-1000, -1000)

var game
var W : float = DESIGN_W
var H : float = DESIGN_H
var top_h : float
var stage_y : float
var stage_h : float
var stage_full_h : float # the stage plus the opponent bar's height (sizes kept from when the bar sat at the stage's bottom)
var opp_bar_y : float
var opp_bar_h : float
var gauge_y : float
var gauge_h : float
var arena_y : float
var arena_h : float
var sq : float
var hand_y : float
var hand_h : float
var bottom_y : float
var bottom_h : float
var band_h : float
var hand_scale : float = 1.0

var _saved_scale_size : Vector2i
var _saved_aspect : int
var _restored := false
var _built := false

var backdrop : Node2D
var panels := {}
var square_styles : Array[StyleBoxFlat] = []
var gauge_nodes : Array[Node2D] = [null, null]
var gauge_center : Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var p1_icon : TextureRect
var p2_icon : TextureRect
var aux_markers := {}
var char_stage_pos := {}
var p1_loc := 0
var p2_loc := 0

var focused_card = null
var _selecting : bool = false
var preview_button : Button
var preview_hint : Button
var menu_panel : PanelContainer
var menu_button : Button
var save_replay_menu_button : Button

var sealed_rect : TextureRect
var deck_rect : TextureRect
var discard_rect : TextureRect
var sealed_label : Label
var deck_label : Label
var discard_label : Label
var ability_label : RichTextLabel
var overdrive_buttons : Array[Button] = [null, null]
var opp_sealed_button : Button
# Opponent deck / discard / sealed icons (above their gauge) and the player name.
var hand_icons : Array = [null, null]
var hand_labels : Array = [null, null]
var osealed_rect : TextureRect
var odeck_rect : TextureRect
var hand_pile_rects : Array = [null, null] # [you, opponent]
var hand_pile_glyphs : Array = [null, null]
var hand_pile_labels : Array = [null, null]
var odiscard_rect : TextureRect
var osealed_label : Label
var odeck_label : Label
var odiscard_label : Label
var player_name_label : Label
var star_buttons : Array[Button] = [null, null]
var ability_text := ""
var exceed_ability_text := ""

var grey_shader : Shader

# --------------------------------------------------------------------------
# Setup / teardown
# --------------------------------------------------------------------------

var _saved_orientation : int = DisplayServer.SCREEN_LANDSCAPE  # restored on exit

func setup(game_node) -> void:
	game = game_node
	name = "PhoneLayout"
	CardBase.phone_mode = true
	CardBase.phone_anim_pace = ANIM_PACE
	var win := get_window()
	_saved_scale_size = win.content_scale_size
	_saved_aspect = win.content_scale_aspect
	# On a real phone, turn the screen to portrait while the phone UI is active, following the
	# phone's rotation sensor (either way up; the layout itself is portrait only).
	if OS.has_feature("mobile"):
		_saved_orientation = DisplayServer.screen_get_orientation()
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_PORTRAIT)
	_configure_window()
	win.size_changed.connect(_on_window_size_changed)
	_compute_rects()
	_build_ui()
	_built = true
	strike_stage = load("res://scenes/game/strike_stage.gd").new()
	strike_stage.name = "StrikeStage"
	add_child(strike_stage)
	strike_stage.setup(self, game)

var strike_stage

# Both strike cards are set: staged reveal (cards off screen, STRIKE! banner, metal plate).
# Returns the event's duration in seconds.
func strike_reveal() -> float:
	return strike_stage.play_reveal()

func strike_cards_sent_away(card = null) -> void:
	if strike_stage == null:
		return
	# An EX strike's extra copy goes to the discard pile when costs are paid, long before
	# the strike ends: that one doesn't open the plate.
	if card != null and is_instance_valid(card) and card.has_meta("ex_hidden"):
		strike_stage.release_ex_card(card)
		return
	# A boost played mid-strike (e.g. Ukemi) waits among the strike cards while it resolves,
	# then goes to the discard pile / boost area: the strike goes on, so the plate stays closed.
	if card != null and is_instance_valid(card) and card.has_meta("phone_boost_hidden"):
		return
	# An invalid attack is discarded and replaced by a wild swing mid-strike: the strike goes
	# on, so the plate stays closed.
	for ev in game.events_ahead:
		# (also when the attack is invalidated by choice, e.g. not paying for an Ultra: the
		# wild swing follows right behind the discard)
		if ev is Dictionary and ev.get("event_type", -1) in [Enums.EventType.EventType_Strike_PayCost_Unable, Enums.EventType.EventType_Strike_WildStrike]:
			return
	strike_stage.strike_card_sent_away()

func strike_end() -> void:
	if strike_stage != null:
		strike_stage.end_strike()

func _exit_tree() -> void:
	restore()

func restore() -> void:
	if _restored:
		return
	_restored = true
	CardBase.phone_mode = false
	CardBase.phone_anim_pace = 1.0
	if OS.has_feature("mobile"):
		DisplayServer.screen_set_orientation(_saved_orientation)
	var win := get_window()
	if win == null:
		return
	if win.size_changed.is_connected(_on_window_size_changed):
		win.size_changed.disconnect(_on_window_size_changed)
	win.content_scale_size = _saved_scale_size
	win.content_scale_aspect = _saved_aspect as Window.ContentScaleAspect

# Tall (phone) windows get a viewport of exactly the window's aspect with a
# fixed 720 width; anything wider (desktop test windows) gets 720x1560 with
# letter/pillar-boxing.
func _configure_window() -> bool:
	var win := get_window()
	var ws := Vector2(win.size)
	var aspect := ws.x / maxf(ws.y, 1.0)
	var target := Vector2i(DESIGN_W, DESIGN_H)
	if aspect < 0.62 and aspect > 0.3:
		target = Vector2i(DESIGN_W, clampi(roundi(DESIGN_W / aspect), 1100, 2000))
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	if win.content_scale_size != target:
		win.content_scale_size = target
		return true
	return false

func _on_window_size_changed() -> void:
	if not _built or _restored:
		return
	if _configure_window():
		game._refresh_viewport_layout_metrics(true)

func _compute_rects() -> void:
	var cs := get_window().content_scale_size
	W = float(cs.x)
	H = float(cs.y)
	top_h = roundf(H * 0.054)
	bottom_h = roundf(H * 0.072)
	hand_h = roundf(H * 0.335)
	arena_h = roundf(H * 0.052)
	gauge_h = roundf(H * 0.036)
	sq = minf(W / 9.0, arena_h - 2.0)
	stage_y = top_h
	# The opponent's bar (sealed / hand / deck / discard) sits below the gauge and arena strips,
	# right above the hand area.
	opp_bar_h = _bottom_slot_size().y + 16.0
	stage_full_h = H - top_h - bottom_h - hand_h - arena_h - gauge_h
	stage_h = stage_full_h - opp_bar_h
	# Boost windows sit in this band at the bottom of the stage (it used to include the bar).
	band_h = roundf(stage_full_h * 0.26) - opp_bar_h
	gauge_y = stage_y + stage_h
	arena_y = gauge_y + gauge_h
	opp_bar_y = arena_y + arena_h
	hand_y = opp_bar_y + opp_bar_h
	bottom_y = hand_y + hand_h

	# Hand cards are as big as cards set in a strike (see strike_s below), as far as the
	# hand area's height allows.
	hand_scale = minf((W / 2.0 - 44.0) / CARD_W, (hand_h - 16.0) / CARD_H)
	var preview_s := minf((W - 24.0) / CARD_W, (stage_full_h - 24.0) / CARD_H)
	CardBase.phone_focus_scale = Vector2(preview_s, preview_s)
	CardBase.phone_focus_center = Vector2(W / 2.0, stage_y + stage_full_h / 2.0)
	# Strike cards sit on the metal plate's halves (over the hand area): as large as lets the card's
	# yellow highlight (275 x 375 at scale 1, the card being 250 x 350) just touch the inside of the
	# plate's metal border (14 px), whichever of width / height comes first.
	const PLATE_BORDER := 14.0
	var strike_s := minf((W / 2.0 - PLATE_BORDER * 2.0) / 275.0, (hand_h - PLATE_BORDER * 2.0) / 375.0)
	CardBase.phone_strike_scale = Vector2(strike_s, strike_s)
	var discard_s := _bottom_slot_size().x / CARD_W
	CardBase.phone_discard_scale = Vector2(discard_s, discard_s)

func _bottom_slot_size() -> Vector2:
	var h := bottom_h - 12.0
	return Vector2(roundf(h * CARD_W / CARD_H), h)

# --------------------------------------------------------------------------
# UI construction (done once)
# --------------------------------------------------------------------------

func _style(color : Color, border : Color = Color(0, 0, 0, 0), border_w : int = 0, radius : int = 0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	if border_w > 0:
		sb.border_color = border
		sb.set_border_width_all(border_w)
	if radius > 0:
		sb.set_corner_radius_all(radius)
	return sb

func _panel(parent : Node, key : String, color : Color) -> Panel:
	var p := Panel.new()
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", _style(color))
	parent.add_child(p)
	panels[key] = p
	return p

const BUTTON_STATES : Array[String] = ["normal", "hover", "pressed", "focus", "disabled"]

# A button that draws nothing in any state: only a tap area.
func _invisible_button() -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	var empty := StyleBoxEmpty.new()
	for state in BUTTON_STATES:
		b.add_theme_stylebox_override(state, empty)
	return b

func _flat_button(parent : Node, callback : Callable) -> Button:
	var b := _invisible_button()
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _text_button(parent : Node, text : String, callback : Callable, font_size : int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font_size)
	b.pressed.connect(callback)
	parent.add_child(b)
	return b

func _count_label(parent : Node) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l

func _build_ui() -> void:
	grey_shader = Shader.new()
	grey_shader.code = "shader_type canvas_item;\nuniform float brightness = 1.0;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tfloat g = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(vec3(g * brightness), c.a);\n}\n"

	backdrop = Node2D.new()
	backdrop.name = "PhoneBackdrop"
	game.add_child(backdrop)
	game.move_child(backdrop, 2) # above Background + BackgroundImage

	var dbg := DEBUG_ZONE_COLORS
	_panel(backdrop, "top", Color(0.65, 1.0, 0.35) if dbg else Color(0.10, 0.13, 0.17, 0.96))
	_panel(backdrop, "stage_l", Color(0.91, 0.18, 0.12) if dbg else Color(0.85, 0.15, 0.10, 0.20))
	_panel(backdrop, "stage_r", Color(0.0, 0.0, 1.0) if dbg else Color(0.10, 0.20, 0.95, 0.20))
	_panel(backdrop, "gauge", Color(0.12, 0.12, 0.14))
	_panel(backdrop, "hand", Color(0.76, 0.50, 0.65) if dbg else Color(0.22, 0.12, 0.20, 0.92))
	_panel(backdrop, "bottom", Color(0.12, 0.14, 0.30))
	_panel(backdrop, "opp_bar", Color(0.12, 0.14, 0.30))
	# Both icon bars are metal plates (gradient, bevelled edge, corner screws).
	for bar_key in ["bottom", "opp_bar"]:
		var mb : Control = load("res://scenes/game/metal_bar.gd").new()
		mb.name = "Metal"
		panels[bar_key].add_child(mb)
		mb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		var sc : Control = load("res://scenes/game/metal_bar.gd").new()
		sc.name = "Screws"
		sc.screws_only = true
		sc.z_as_relative = false
		# Player bar: above the island overlay (z 70) and its buttons, below the action popup (80).
		# Opponent bar: low, so focused / huge cards (z 20) draw over it.
		sc.z_index = 75 if bar_key == "bottom" else 9
		panels[bar_key].add_child(sc)
		sc.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	for i in range(9):
		var sb := _style(Color(0.42, 0.42, 0.42), Color(0.15, 0.15, 0.15), 2, 6)
		var p := Panel.new()
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		p.add_theme_stylebox_override("panel", sb)
		backdrop.add_child(p)
		panels["sq%d" % i] = p
		square_styles.append(sb)

	p1_icon = _make_icon(Color(0.95, 0.25, 0.2))
	p2_icon = _make_icon(Color(0.25, 0.35, 1.0))

	for side in range(2):
		gauge_nodes[side] = Node2D.new()
		backdrop.add_child(gauge_nodes[side])

	panels["hand_dismiss"] = _flat_button(backdrop, clear_focus)
	panels["gauge_btn_p"] = _flat_button(backdrop, func():
		# While gauge is being picked, a tap on the strip (e.g. its very edge) picks the
		# nearest gauge box instead of opening the gauge window.
		if GlobalSettings.phone_controls_active() and _gauge_selectable():
			var near = _nearest_gauge_card(panels["gauge_btn_p"].get_global_mouse_position())
			if near != null:
				_gauge_slot_tap(near)
				return
		_manual_gauge_open = true
		_toggle_popout(game.CardPopoutType.CardPopoutType_GaugePlayer, game._on_player_gauge_gauge_clicked)
		_manual_gauge_open = false)
	panels["gauge_btn_o"] = _flat_button(backdrop, func(): _toggle_popout(game.CardPopoutType.CardPopoutType_GaugeOpponent, game._on_opponent_gauge_gauge_clicked))
	panels["stage_btn_p"] = _flat_button(backdrop, func(): _toggle_popout(game.CardPopoutType.CardPopoutType_ReferencePlayer, game._on_player_reference_button_pressed))
	panels["stage_btn_o"] = _flat_button(backdrop, func(): _toggle_popout(game.CardPopoutType.CardPopoutType_ReferenceOpponent, game._on_opponent_reference_button_pressed))

	# Bottom bar: sealed | ability text | deck | discard
	sealed_rect = _card_back_rect(0.38)
	deck_rect = _card_back_rect(-1.0)
	discard_rect = _card_back_rect(1.25)
	sealed_label = _count_label(backdrop)
	deck_label = _count_label(backdrop)
	discard_label = _count_label(backdrop)
	# Opponent's icons mirror the player's (same card-back look and shading).
	osealed_rect = _card_back_rect(0.38)
	odeck_rect = _card_back_rect(-1.0)
	odiscard_rect = _card_back_rect(1.25)
	osealed_label = _count_label(backdrop)
	odeck_label = _count_label(backdrop)
	odiscard_label = _count_label(backdrop)
	# Hand icons (next to each deck): a card back with a hand on it and the hand size.
	var hand_glyph_tex : Texture2D = _hand_glyph_texture()
	for side in range(2):
		var hr := _card_back_rect(-1.0)
		var glyph := TextureRect.new()
		glyph.texture = hand_glyph_tex
		glyph.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		glyph.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		glyph.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glyph.modulate = Color(1, 1, 1, 0.92)
		backdrop.add_child(glyph)
		hand_pile_rects[side] = hr
		hand_pile_glyphs[side] = glyph
		hand_pile_labels[side] = _count_label(backdrop)
	ability_label = RichTextLabel.new()
	ability_label.bbcode_enabled = true
	ability_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ability_label.add_theme_font_size_override("normal_font_size", 19)
	ability_label.add_theme_font_size_override("italics_font_size", 19)
	ability_label.add_theme_font_size_override("bold_font_size", 19)
	ability_label.scroll_active = false
	backdrop.add_child(ability_label)
	panels["ability_btn"] = _flat_button(backdrop, func(): _toggle_popout(game.CardPopoutType.CardPopoutType_ReferencePlayer, game._on_player_reference_button_pressed))
	# Sealed icons: a tap or a long press opens the sealed window (even while it is empty).
	var open_sealed_p := func(): _toggle_popout(game.CardPopoutType.CardPopoutType_SealedPlayer, game._on_player_sealed_clicked)
	panels["sealed_btn"] = _flat_button(backdrop, open_sealed_p)
	_wire_tap_hold(panels["sealed_btn"], open_sealed_p, open_sealed_p)
	# Deck icons open the deck reference (yours at the bottom, theirs top-right).
	panels["deck_btn_p"] = _flat_button(backdrop, func(): _toggle_popout(game.CardPopoutType.CardPopoutType_ReferencePlayer, game._on_player_reference_button_pressed))
	panels["deck_btn_o"] = _flat_button(backdrop, func(): _toggle_popout(game.CardPopoutType.CardPopoutType_ReferenceOpponent, game._on_opponent_reference_button_pressed))
	var open_sealed_o := func(): _toggle_popout(game.CardPopoutType.CardPopoutType_SealedOpponent, game._on_opponent_sealed_clicked)
	panels["osealed_btn"] = _flat_button(backdrop, open_sealed_o)
	_wire_tap_hold(panels["osealed_btn"], open_sealed_o, open_sealed_o)
	# Hand icons: yours Prepares (phone controls only; without them, Prepare comes from the
	# action menu), theirs opens their revealed cards while any of their hand is known.
	panels["hand_btn_p"] = _flat_button(backdrop, func():
		if GlobalSettings.phone_controls_active():
			_menu_action("Prepare"))
	panels["hand_btn_o"] = _flat_button(backdrop, func():
		if not _reveal_info(1)["hand"].is_empty():
			_toggle_revealed_box(1))

	# Overdrive / opponent sealed shortcuts (only shown when relevant).
	overdrive_buttons[0] = _text_button(backdrop, "Overdrive", func(): _toggle_popout(game.CardPopoutType.CardPopoutType_OverdrivePlayer, game._on_player_overdrive_gauge_clicked), 18)
	overdrive_buttons[1] = _text_button(backdrop, "Overdrive", func(): _toggle_popout(game.CardPopoutType.CardPopoutType_OverdriveOpponent, game._on_opponent_overdrive_gauge_clicked), 18)
	opp_sealed_button = _text_button(backdrop, "Sealed", func(): _toggle_popout(game.CardPopoutType.CardPopoutType_SealedOpponent, game._on_opponent_sealed_clicked), 18)
	for b in [overdrive_buttons[0], overdrive_buttons[1], opp_sealed_button]:
		b.visible = false

	# Extra-cards buttons: a card back the size of the deck icon, with a bold asterisk on it and
	# a pulsing neon frame (yours above your sealed icon, theirs left of their hand icon).
	var star_font = load("res://scenes/game/badge_font.gd").make_font()
	for side in range(2):
		var sb := _flat_button(backdrop, func():
			if side == 0:
				_toggle_popout(game.CardPopoutType.CardPopoutType_BuddyPlayer, game._on_player_buddy_button_pressed)
			else:
				_toggle_popout(game.CardPopoutType.CardPopoutType_BuddyOpponent, game._on_opponent_buddy_button_pressed))
		sb.z_index = 12
		sb.visible = false
		# The glow sits behind the card (a StyleBoxFlat shadow fills under the whole box, so it
		# must not be on top), the bright tube border on top of it.
		var glow := Panel.new()
		glow.name = "Glow"
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		glow.set_anchors_preset(Control.PRESET_FULL_RECT)
		var gs := StyleBoxFlat.new()
		gs.bg_color = Color(0.05, 0.02, 0.1)
		gs.set_corner_radius_all(6)
		gs.shadow_color = Color(1.0, 0.2, 0.85, 0.8)
		gs.shadow_size = 8
		glow.add_theme_stylebox_override("panel", gs)
		sb.add_child(glow)
		var back := TextureRect.new()
		back.name = "Back"
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_SCALE
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.modulate = Color(0.75, 0.75, 0.85)
		sb.add_child(back)
		var tint := ColorRect.new()
		tint.name = "Tint"
		tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tint.set_anchors_preset(Control.PRESET_FULL_RECT)
		tint.color = Color(0.45, 0.0, 0.7, 0.12)
		sb.add_child(tint)
		var star := Label.new()
		star.name = "Star"
		star.text = "*"
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		star.set_anchors_preset(Control.PRESET_FULL_RECT)
		star.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		star.add_theme_font_override("font", star_font)
		star.add_theme_font_size_override("font_size", 64)
		star.add_theme_color_override("font_color", Color(1, 1, 1))
		star.add_theme_color_override("font_outline_color", Color(1.0, 0.25, 0.85))
		star.add_theme_constant_override("outline_size", 10)
		sb.add_child(star)
		var frame := Panel.new()
		frame.name = "Neon"
		frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.set_anchors_preset(Control.PRESET_FULL_RECT)
		var fs := StyleBoxFlat.new()
		fs.bg_color = Color(0, 0, 0, 0)
		fs.set_border_width_all(3)
		fs.border_color = Color(0.2, 1.0, 1.0)
		fs.set_corner_radius_all(6)
		frame.add_theme_stylebox_override("panel", fs)
		sb.add_child(frame)
		star_buttons[side] = sb

	# Focused card preview: tap the big card to select / deselect it.
	preview_button = _flat_button(backdrop, _on_preview_tap)
	preview_button.z_index = 11
	if GlobalSettings.phone_controls_active():
		CardBase.phone_long_press_handler = _on_card_long_press
		preview_button.button_down.connect(_on_preview_down)
		preview_button.button_up.connect(func(): _preview_press_token += 1)
	else:
		CardBase.phone_long_press_handler = Callable()
	preview_button.visible = false
	CardBase.phone_zone_flight_hook = _on_card_zone_flight
	preview_hint = _text_button(backdrop, "Select", _on_select_pressed, 28)
	preview_hint.z_index = 11
	preview_hint.visible = false

	_build_menu()
	_rewire_popout_buttons()
	if GlobalSettings.phone_controls_active():
		_build_island()
		_wire_phone_controls()

	# Choosing any action unfocuses the previewed card.
	for menu in game.action_menu_container.find_children("*", "ActionMenu", true, false):
		menu.choice_selected.connect(func(_index): clear_focus())
		menu.choice_selected.connect(_on_action_menu_choice)

	# Move the underboost info buttons out of the (hidden) zones panels.
	for zone_name in ["PlayerZones", "OpponentZones"]:
		var container = game.get_node_or_null("%s/BoostInfoContainer" % zone_name)
		if container != null:
			container.reparent(game)

func _make_icon(border_color : Color) -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	backdrop.add_child(r)
	var frame := Panel.new()
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), border_color, 4, 4))
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.name = "Frame"
	r.add_child(frame)
	r.set_meta("border_color", border_color)
	r.z_index = 4 # (its border over the gold turn frame, z 3, which ends at the arena's top edge)
	return r

func _card_back_rect(brightness : float) -> TextureRect:
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	if brightness > 0.0:
		var mat := ShaderMaterial.new()
		mat.shader = grey_shader
		mat.set_shader_parameter("brightness", brightness)
		r.material = mat
	backdrop.add_child(r)
	return r

func _build_menu() -> void:
	menu_button = _text_button(backdrop, "=", func(): menu_panel.visible = not menu_panel.visible, 26)
	menu_button.z_index = 40
	menu_panel = PanelContainer.new()
	menu_panel.z_index = 40
	menu_panel.visible = false
	var vb := VBoxContainer.new()
	menu_panel.add_child(vb)
	backdrop.add_child(menu_panel)
	var entries := [
		["Combat Log", "_on_combat_log_button_pressed"],
		["Emote", "_on_emote_button_pressed"],
		["Save Replay", "_on_save_replay_button_pressed"],
		["Exit to Menu", "_on_exit_to_menu_pressed"],
	]
	for entry in entries:
		var method : String = entry[1]
		var b := _text_button(vb, entry[0], func():
			menu_panel.visible = false
			game.call(method), 24)
		b.custom_minimum_size = Vector2(230, 56)
		if method == "_on_save_replay_button_pressed":
			save_replay_menu_button = b
		if method == "_on_emote_button_pressed":
			b.set_meta("hide_in_observer", true)
	_build_speed_menu(vb)

# ---- Animation speed (hamburger menu) ---------------------------------------------------------
# "Animation Speed" opens a sub-list (1/4x ... 2x) that sets Engine.time_scale, which scales every
# animation, tween and timer in the game. It lasts for the session (not saved).
const ANIM_SPEEDS := [[0.25, "1/4x"], [0.5, "1/2x"], [0.75, "3/4x"], [1.0, "Normal (1x)"], [1.5, "1.5x"], [2.0, "2x"]]
var _speed_button : Button = null
var _speed_list : VBoxContainer = null

func _speed_label() -> String:
	for sp in ANIM_SPEEDS:
		if is_equal_approx(Engine.time_scale, sp[0]):
			return "Animation Speed: %s" % ("1x" if sp[0] == 1.0 else sp[1])
	return "Animation Speed: %sx" % str(Engine.time_scale)

func _build_speed_menu(vb : VBoxContainer) -> void:
	_speed_button = _text_button(vb, _speed_label(), func():
		_speed_list.visible = not _speed_list.visible, 22)
	_speed_button.custom_minimum_size = Vector2(230, 56)
	_speed_list = VBoxContainer.new()
	_speed_list.visible = false
	vb.add_child(_speed_list)
	for sp in ANIM_SPEEDS:
		var val : float = sp[0]
		var b := _text_button(_speed_list, "   " + str(sp[1]), func():
			Engine.time_scale = val
			_speed_button.text = _speed_label()
			_speed_list.visible = false
			menu_panel.visible = false, 22)
		b.custom_minimum_size = Vector2(230, 48)

# --------------------------------------------------------------------------
# Layout (re-run whenever the viewport changes)
# --------------------------------------------------------------------------

func apply(_viewport_size : Vector2) -> void:
	if not _built:
		return
	_compute_rects()
	_layout_backdrop()
	_layout_game_nodes()
	_snap_icons = true # layout changed: place icons instantly
	refresh_all()
	_snap_icons = false

func _sq_pos(i : int) -> Vector2:
	return Vector2((W - sq * 9.0) / 2.0 + (i - 1) * sq, arena_y + (arena_h - sq) / 2.0)

func _set_rect(node : Control, rect : Rect2) -> void:
	node.position = rect.position
	node.size = rect.size

func _layout_backdrop() -> void:
	_set_rect(panels["top"], Rect2(0, 0, W, top_h))
	_set_rect(panels["stage_l"], Rect2(0, stage_y, W / 2.0, stage_h))
	_set_rect(panels["stage_r"], Rect2(W / 2.0, stage_y, W / 2.0, stage_h))
	_set_rect(panels["gauge"], Rect2(0, gauge_y, W, gauge_h))
	_set_rect(panels["hand"], Rect2(0, hand_y, W, hand_h))
	_set_rect(panels["bottom"], Rect2(0, bottom_y, W, bottom_h))
	# Bar behind the opponent's sealed / hand / deck / discard, like the player's bottom bar.
	_set_rect(panels["opp_bar"], Rect2(0, opp_bar_y, W, opp_bar_h))
	for i in range(9):
		_set_rect(panels["sq%d" % i], Rect2(_sq_pos(i + 1), Vector2(sq, sq)))
	_set_rect(panels["hand_dismiss"], Rect2(0, hand_y, W, hand_h))
	_set_rect(panels["gauge_btn_p"], Rect2(0, gauge_y, W / 2.0, gauge_h))
	_set_rect(panels["gauge_btn_o"], Rect2(W / 2.0, gauge_y, W / 2.0, gauge_h))
	_set_rect(panels["stage_btn_p"], Rect2(0, stage_y, W / 2.0, stage_h))
	_set_rect(panels["stage_btn_o"], Rect2(W / 2.0, stage_y, W / 2.0, stage_h))
	_set_rect(preview_button, Rect2(0, stage_y, W, stage_h))
	# Select button: centered on the card, just above the effect text box.
	var pv_s : float = CardBase.phone_focus_scale.x
	var pv_c : Vector2 = CardBase.phone_focus_center
	var pv_h := CARD_H * pv_s
	_set_rect(preview_hint, Rect2(pv_c.x - 95.0, pv_c.y - pv_h / 2.0 + 0.595 * pv_h - 28.0, 190, 56))

	var slot := _bottom_slot_size()
	var slot_y := bottom_y + (bottom_h - slot.y) / 2.0
	var sealed_pos := Vector2(8, slot_y)
	var discard_pos := Vector2(W - 8 - slot.x, slot_y)
	var deck_pos := Vector2(discard_pos.x - 8 - slot.x, slot_y)
	var hand_pos := Vector2(deck_pos.x - 8 - slot.x, slot_y)
	_set_rect(sealed_rect, Rect2(sealed_pos, slot))
	_set_rect(deck_rect, Rect2(deck_pos, slot))
	_set_rect(discard_rect, Rect2(discard_pos, slot))
	for pair in [[sealed_label, sealed_pos], [deck_label, deck_pos], [discard_label, discard_pos]]:
		var l : Label = pair[0]
		l.position = pair[1] + Vector2(0, slot.y - 30)
		l.size = Vector2(slot.x, 28)
	var text_x := sealed_pos.x + slot.x + 10.0
	var text_w := hand_pos.x - 10.0 - text_x
	_ability_box = Rect2(text_x, bottom_y + 4, text_w, bottom_h - 8)
	_ability_box_full = _ability_box
	_ability_btn_full = Rect2(text_x, bottom_y, text_w, bottom_h)
	_set_rect(ability_label, _ability_box)
	_set_rect(panels["ability_btn"], _ability_btn_full)
	if _multi_split:
		_apply_action_split(true, true)
	island_rect = Rect2(text_x, bottom_y, text_w, bottom_h)
	_layout_island()
	_set_rect(panels["sealed_btn"], Rect2(sealed_pos, slot))
	_set_rect(panels["deck_btn_p"], Rect2(deck_pos, slot))
	_layout_hand_pile(0, hand_pos, slot)
	_set_rect(panels["hand_btn_p"], Rect2(hand_pos, slot))
	_layout_hand_pile(1, _opp_hand_icon_pos(), slot)
	_set_rect(panels["hand_btn_o"], Rect2(_opp_hand_icon_pos(), slot))
	# Opponent icons: sealed | deck | discard, right above their gauge.
	for trio in [[osealed_rect, 0, osealed_label], [odeck_rect, 1, odeck_label], [odiscard_rect, 2, odiscard_label]]:
		var ipos := _opp_icon_pos(trio[1])
		_set_rect(trio[0], Rect2(ipos, slot))
		var ilabel : Label = trio[2]
		ilabel.position = ipos + Vector2(0, slot.y - 30)
		ilabel.size = Vector2(slot.x, 28)
	_set_rect(panels["deck_btn_o"], Rect2(_opp_icon_pos(1), slot))
	_set_rect(panels["osealed_btn"], Rect2(_opp_icon_pos(0), slot))
	# Cards sealed (and cards leaving a sealed area) fly to / from the sealed icons, not the
	# hidden zone panels.
	for sp in [["PlayerZones/PlayerSealed", Rect2(sealed_pos, slot)], ["OpponentZones/OpponentSealed", Rect2(_opp_icon_pos(0), slot)]]:
		var spanel = game.get_node_or_null(sp[0])
		if spanel != null and "center_override" in spanel:
			spanel.center_override = (sp[1] as Rect2).get_center()
	# Asterisk (extra cards) icons: yours just above your sealed icon, theirs left of their hand icon.
	_set_rect(star_buttons[0], Rect2(Vector2(sealed_pos.x, bottom_y - slot.y), slot))
	_set_rect(star_buttons[1], Rect2(_opp_hand_icon_pos() - Vector2(8.0 + slot.x, 0.0), slot))

	# Menu button: dead center of the top bar, on the clock row between the two timers.
	# A tall rectangle filling the gap between the two turn markers, top edge to stage.
	menu_button.position = Vector2(W / 2.0 - 30.0, 2.0)
	menu_button.size = Vector2(60, top_h + 32.0 - 2.0) # runs down to the bottom of the player name text
	menu_button.add_theme_font_size_override("font_size", 34)
	# Keep the "=" in the lower part of the rectangle, clear of a phone's status bar / camera cutout.
	for sb_name in BUTTON_STATES:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.22, 0.22, 0.3, 0.9) if sb_name != "pressed" else Color(0.4, 0.4, 0.55, 0.95)
		sb.set_border_width_all(2)
		sb.border_color = Color(1, 1, 1, 0.55)
		sb.set_corner_radius_all(8)
		sb.content_margin_top = 70.0
		sb.content_margin_bottom = 2.0
		menu_button.add_theme_stylebox_override(sb_name, sb)
	menu_panel.position = Vector2(W / 2.0 - 115.0, top_h + 32.0 + 4.0)

func _layout_game_nodes() -> void:
	var g = game
	var vp := Vector2(W, H)

	g.get_node("Background").size = vp
	g.get_node("Background").color = Color(0.09, 0.10, 0.13)
	var bi : TextureRect = g.background_image
	bi.position = Vector2(0, stage_y)
	bi.size = Vector2(W, stage_full_h) # (the gauge / arena strips cover its bottom, as the bar did)
	bi.clip_contents = true
	hide_unused_arena_art()

	for node_path in ["PlayerZones", "OpponentZones", "ExitToMenu", "EmoteButton",
			"PlayerDeck/PlayerCharacterCard", "OpponentDeck/OpponentCharacterCard",
			"PlayerDeck/Discard", "OpponentDeck/Discard"]:
		var n = g.get_node_or_null(node_path)
		if n != null:
			n.visible = false

	# Arena strip: the existing click buttons sit exactly on top of my squares.
	var an : Node2D = g.get_node("ArenaNode")
	an.position = Vector2(0, arena_y)
	var rb : HBoxContainer = g.arena_layout
	rb.add_theme_constant_override("separation", 0)
	rb.custom_minimum_size = Vector2(sq * 9.0, sq)
	for child in rb.get_children():
		child.custom_minimum_size = Vector2(sq, sq)
		child.get_node("Button").custom_minimum_size = Vector2(sq, sq)
		# Selectable-space highlight: a yellow outline with a faint fill instead of the
		# stock opaque yellow square (which made the whole arena look solid yellow).
		var sel_btn : TextureButton = child.get_node("Button")
		sel_btn.texture_normal = null
		sel_btn.texture_hover = null
		sel_btn.texture_pressed = null
		if sel_btn.get_node_or_null("PhoneHighlight") == null:
			var hl := Panel.new()
			hl.name = "PhoneHighlight"
			hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hl.set_anchors_preset(Control.PRESET_FULL_RECT)
			var hl_style := StyleBoxFlat.new()
			hl_style.bg_color = Color(1.0, 0.9, 0.2, 0.14)
			hl_style.border_color = Color(1.0, 0.9, 0.2, 1.0)
			hl_style.set_border_width_all(3)
			hl.add_theme_stylebox_override("panel", hl_style)
			sel_btn.add_child(hl)
	rb.position = Vector2((W - sq * 9.0) / 2.0, (arena_h - sq) / 2.0)
	rb.size = Vector2(sq * 9.0, sq)
	var rl : Control = an.get_node("RowLightningInfoButtons")
	rl.scale = Vector2(0.55, 0.55)
	rl.custom_minimum_size.x = W / 0.55
	rl.size.x = W / 0.55
	rl.position = Vector2(0, arena_h - 2)

	# Characters on the stage.
	_place_main_character(g.get_node("PlayerCharacter"), true)
	_place_main_character(g.get_node("OpponentCharacter"), false)

	# Top bar: life bars (layout depends on whether timers are in use).
	_layout_life()

	# Opponent name / hand / piles (top right of the blue half).
	var name_label : Label = g.opponent_name_label
	name_label.add_theme_font_size_override("font_size", 24)
	name_label.position = Vector2(W - 334, stage_y + 2)
	name_label.size = Vector2(328, 32)
	var thinking : Control = g.get_node("OpponentDeck/ThinkingIndicator")
	thinking.position = Vector2(W / 2.0 + 6, stage_y + stage_h - band_h - 70)
	thinking.scale = Vector2(0.8, 0.8)
	var hand_spawn : Control = g.get_node("OpponentHand/HandSpawn")
	hand_spawn.scale = Vector2(0.4, 0.4)
	hand_spawn.position = _opp_hand_center() - hand_spawn.size * hand_spawn.scale / 2.0
	# The hand count now lives in the top bar.
	g.get_node("OpponentHand/OpponentHandBox").visible = false

	# Player name: top-left, mirroring the opponent's name.
	if player_name_label == null:
		player_name_label = Label.new()
		player_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		g.add_child(player_name_label)
	player_name_label.add_theme_font_size_override("font_size", 24)
	player_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	player_name_label.position = Vector2(6, stage_y + 2)
	player_name_label.size = Vector2(328, 32)

	# Opponent's deck / discard piles sit with their sealed icon above their gauge.
	var opp_w := _bottom_slot_size().x
	_place_pile(g.get_node("OpponentDeck/DeckButton"), _opp_icon_pos(1), opp_w)
	_place_pile(g.get_node("AllCards/OpponentDiscardButton"), _opp_icon_pos(2), opp_w)
	_place_pile(g.get_node("OpponentDeck/Discard"), _opp_icon_pos(2), opp_w)

	# Player's deck / discard sit in the bottom bar slots.
	var slot := _bottom_slot_size()
	var slot_y := bottom_y + (bottom_h - slot.y) / 2.0
	var discard_pos := Vector2(W - 8 - slot.x, slot_y)
	var deck_pos := Vector2(discard_pos.x - 8 - slot.x, slot_y)
	_place_pile(g.get_node("PlayerDeck/DeckButton"), deck_pos, slot.x)
	_place_pile(g.get_node("AllCards/PlayerDiscardButton"), discard_pos, slot.x)
	_place_pile(g.get_node("PlayerDeck/Discard"), discard_pos, slot.x)

	# Extra-card (buddy) buttons.
	for pair in [["PlayerDeck/PlayerBuddyCharacterCard", Vector2(4, stage_y + stage_full_h * 0.42)],
			["OpponentDeck/OpponentBuddyCharacterCard", Vector2(W - 4 - 66, stage_y + stage_full_h * 0.42)]]:
		var buddy_card = g.get_node_or_null(pair[0])
		if buddy_card != null:
			# The card itself is replaced by an asterisk button: keep it in the tree
			# (the game still toggles/updates it) but invisible and unclickable.
			buddy_card.scale = Vector2(0.26, 0.26)
			buddy_card.position = Vector2(-2000, -2000)
			buddy_card.modulate = Color(1, 1, 1, 0)
	# Asterisk buttons: bottom-left (player) / bottom-right (opponent), just above the boost boxes.
	opp_sealed_button.visible = false # replaced by the opponent sealed icon
	# (vertical positions of the asterisks / overdrive buttons / bonus panels follow
	# the boost boxes: see _update_boost_layout)

	# Strike zones + bonus panels.
	# Strike cards hang from the name labels: their top edge borders the names.
	var center_y := stage_y + 34.0 + CARD_H * CardBase.phone_strike_scale.y / 2.0
	_place_strike_zone(g.get_node("PlayerStrike/StrikeZone"), Vector2(W * 0.25, center_y))
	_place_strike_zone(g.get_node("OpponentStrike/StrikeZone"), Vector2(W * 0.75, center_y))
	for pair in [["PlayerStrike/CharBonusPanel", 6.0], ["OpponentStrike/CharBonusPanel", W / 2.0 + 6.0]]:
		var bp : Control = g.get_node(pair[0])
		bp.scale = Vector2.ONE
		# Bonus-effect popup: a dark, cracked block of ice with white text (like the boost boxes).
		bp.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		if bp.get_node_or_null("Ice") == null: # (the layout can run more than once)
			var ice : Control = load("res://scenes/game/ice_block.gd").new()
			ice.name = "Ice"
			# See-through, so the character sprite behind it stays visible (the text isn't faded).
			ice.modulate.a = 0.88
			bp.add_child(ice)
			bp.move_child(ice, 0)
		var ab : RichTextLabel = bp.get_node("MarginContainer/VBox/AbilityLabel")
		ab.add_theme_color_override("default_color", Color.WHITE)
		# Same footprint as a collapsed boost window: the title and the game's own bullet
		# list are hidden, and a single-line summary of the effects takes their place.
		bp.get_node("MarginContainer/VBox/UniqueLabel").visible = false
		ab.visible = false
		var mc : MarginContainer = bp.get_node("MarginContainer")
		for side in ["margin_left", "margin_right"]:
			mc.add_theme_constant_override(side, 8)
		for side in ["margin_top", "margin_bottom"]:
			mc.add_theme_constant_override(side, 3)
		# (The layout runs again when the screen size changes, e.g. on the phone; the label must
		# only be made once, or a second, empty one adds a blank line under the text.)
		if bp.get_node_or_null("MarginContainer/VBox/BonusText") != null:
			bp.custom_minimum_size = Vector2(W / 2.0 - 8.0, 39.0)
			continue
		var bt := Label.new()
		bt.name = "BonusText"
		bt.add_theme_font_size_override("font_size", BONUS_FONT_MAX)
		bt.add_theme_color_override("font_color", Color.WHITE)
		bt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		bt.add_theme_constant_override("outline_size", 6)
		bt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		# (If the box ever comes out taller than its text, the text stays centered in it.)
		bt.size_flags_vertical = Control.SIZE_EXPAND_FILL
		bt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		bt.custom_minimum_size = Vector2(W / 2.0 - 8.0 - 16.0, 0.0)
		bp.get_node("MarginContainer/VBox").add_child(bt)
		bp.custom_minimum_size = Vector2(W / 2.0 - 8.0, 39.0)

	# Boost windows: as short as the "BOOSTS" title by default, growing upward as
	# boost text is added (see _update_boost_layout).
	var zone_y := stage_y + stage_h - band_h
	var zone_w := W / 2.0 - 8.0
	for pair in [["PlayerBoostZone", 4.0], ["OpponentBoostZone", W / 2.0 + 4.0]]:
		var zone = g.get_node(pair[0])
		zone.fill_mode = false
		zone.max_effects_height = stage_full_h * 0.4
		zone.scale = Vector2.ONE
		var om : MarginContainer = zone.get_node("OuterMargin")
		om.custom_minimum_size = Vector2(zone_w, 0)
		om.size = Vector2(zone_w, 0)
		# The tap-target button's texture size must not set the box's minimum height.
		om.get_node("Focus").ignore_texture_size = true
		zone.get_node("OuterMargin/BoostPanel/InnerMargin/BoostVBox/BoostLabel").add_theme_font_size_override("font_size", 30)
		var fx : RichTextLabel = zone.get_node("OuterMargin/BoostPanel/InnerMargin/BoostVBox/BoostEffects")
		for font_key in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
			fx.add_theme_font_size_override(font_key, 25)
		zone._update_effects_height()
		# Wood / embers / fire backdrop behind the text; the stock panel look goes away.
		zone.get_node("OuterMargin/BoostPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		if zone.get_node_or_null("BoostFire") == null: # (the layout can run more than once)
			var fire : Control = load("res://scenes/game/boost_fire.gd").new()
			fire.name = "BoostFire"
			zone.add_child(fire)
			zone.move_child(fire, 0)
		# Outlined text stays readable over the wood and flames.
		var bl : Label = zone.get_node("OuterMargin/BoostPanel/InnerMargin/BoostVBox/BoostLabel")
		bl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		bl.add_theme_constant_override("outline_size", 6)
		fx.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		fx.add_theme_constant_override("outline_size", 6)
	var pbi = g.get_node_or_null("BoostInfoContainer")
	if pbi != null:
		pbi.position = Vector2(6, zone_y - 44)

	# Action menu (mulligan / choose an action): sits directly above the character
	# ability box at the bottom; _place_action_menu keeps it there as it resizes.
	var amc : Control = g.action_menu_container
	amc.scale = Vector2(0.72, 0.72)
	amc.z_index = 80 # always above popups, previews and everything else
	_place_action_menu()

	# Misc buttons / labels.
	g.choice_popout_button.scale = Vector2(0.8, 0.8)
	g.choice_popout_button.position = Vector2(W / 2.0 - 106, stage_y + stage_h - band_h - 110)
	g.choice_popout_button.z_index = 12
	g.observer_next_button.scale = Vector2(0.7, 0.7)
	g.observer_next_button.position = Vector2(W - 150, stage_y + 150)
	g.observer_play_to_live_button.scale = Vector2(0.7, 0.7)
	g.observer_play_to_live_button.position = Vector2(W - 150, stage_y + 200)
	g.game_over_label.position = Vector2(W / 2.0 - 114, stage_y + stage_full_h * 0.4)
	g.game_over_label.z_index = 50

	# Full-screen dialogs.
	for dlg_name in ["CombatLog", "EmoteDialog", "ModalDialog"]:
		var dlg : Control = g.get_node_or_null(dlg_name)
		if dlg != null:
			dlg.offset_right = W
			dlg.offset_bottom = H
	if g.rotation_layout_overlay:
		g.rotation_layout_overlay.size = vp

	if save_replay_menu_button != null:
		save_replay_menu_button.visible = g.replay_saving_enabled
	for b in menu_panel.get_child(0).get_children():
		if b.has_meta("hide_in_observer"):
			b.visible = not g.observer_mode

var _last_timers_enabled = null

# The enforce-timer setting arrives with the game start message (after the
# initial layout), so watch for it changing.
# Slot 0 = sealed, 1 = deck, 2 = discard (rightmost): the opponent's icon row sits
# just above their gauge, at the right edge of the stage.
# --------------------------------------------------------------------------
# Phone controls: the "dynamic island" (the character-ability box turns into
# cancel / confirm buttons whenever the game is waiting for a confirmation).
# --------------------------------------------------------------------------
var island_root : Control
var island_red : Button
var island_green : Button
var island_tab : PanelContainer
var island_tab_label : Label
var island_rect : Rect2
var _island_vis : float = 0.0
var _island_split : float = 0.5 # fraction of the width taken by the red box
var _island_want : bool = false
var _island_split_target : float = -1.0
var _island_title : String = ""
var _island_vis_tween : Tween
var _island_split_tween : Tween
var _menu_sig : String = ""

func _island_button(txt : String, col : Color) -> Button:
	var b := Button.new()
	b.text = txt
	b.focus_mode = Control.FOCUS_NONE
	_style_island_button(b, col)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_outline_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.add_theme_constant_override("outline_size", 8) # extra weight
	b.clip_text = true
	# A glossy highlight over the top of the button.
	var gloss := Panel.new()
	gloss.name = "Gloss"
	gloss.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var gsb := StyleBoxFlat.new()
	gsb.bg_color = Color(1, 1, 1, 0.16)
	gsb.corner_radius_top_left = 12
	gsb.corner_radius_top_right = 12
	gloss.add_theme_stylebox_override("panel", gsb)
	b.add_child(gloss)
	gloss.anchor_right = 1.0
	gloss.anchor_bottom = 0.45
	gloss.offset_left = 4
	gloss.offset_top = 3
	gloss.offset_right = -4
	return b

func _build_island() -> void:
	island_root = Control.new()
	island_root.z_index = 70
	island_root.visible = false
	island_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.add_child(island_root)
	island_red = _island_button("X", Color(0.78, 0.14, 0.16))
	island_green = _island_button("O", Color(0.16, 0.62, 0.26))
	island_red.pressed.connect(func(): _island_press(false))
	island_green.pressed.connect(func(): _island_press(true))
	island_root.add_child(island_red)
	island_root.add_child(island_green)
	# Effect options: the island's own row can split into a third button (island_b3), and a second
	# row of up to three (island_x3 / x4 / x5) hangs above it. Each extra button presses the option
	# it was last laid out for (its "choice_idx" meta, see _update_choice_buttons).
	island_b3 = _island_button("", _CHOICE_COLORS[2])
	island_x3 = _island_button("", _CHOICE_COLORS[3])
	island_x4 = _island_button("", _CHOICE_COLORS[4])
	island_x5 = _island_button("", _CHOICE_COLORS[5])
	for xb in [island_b3, island_x3, island_x4, island_x5]:
		xb.visible = false
		var xb_ref : Button = xb
		xb.pressed.connect(func():
			var ci := int(xb_ref.get_meta("choice_idx", -1))
			if ci >= 0:
				_choice_press(ci))
		island_root.add_child(xb)
	_island_sparkle = load("res://scenes/game/island_sparkle.gd").new()
	island_tab = PanelContainer.new()
	island_tab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tsb := StyleBoxFlat.new()
	tsb.bg_color = Color(0.08, 0.09, 0.14, 0.96)
	tsb.border_color = Color(1, 1, 1, 0.55)
	tsb.set_border_width_all(2)
	tsb.border_width_bottom = 0
	tsb.corner_radius_top_left = 10
	tsb.corner_radius_top_right = 10
	tsb.content_margin_left = 14
	tsb.content_margin_right = 14
	tsb.content_margin_top = 3
	tsb.content_margin_bottom = 3
	island_tab.add_theme_stylebox_override("panel", tsb)
	island_tab_label = Label.new()
	island_tab_label.add_theme_font_size_override("font_size", 22)
	island_tab_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	island_tab_label.clip_text = true
	island_tab.add_child(island_tab_label)
	island_root.add_child(island_tab)
	island_root.add_child(_island_sparkle) # (last: drawn over the buttons)
	_layout_island()

func _layout_island() -> void:
	if island_root == null:
		return
	island_root.position = island_rect.position
	island_root.size = island_rect.size
	var fs := int(island_rect.size.y * 0.75)
	island_red.add_theme_font_size_override("font_size", fs)
	island_green.add_theme_font_size_override("font_size", fs)
	if _island_sparkle != null:
		_island_sparkle.position = Vector2(-24, -24)
		_island_sparkle.size = island_rect.size + Vector2(48, 48)
		_island_sparkle.inner = Rect2(Vector2(24, 24), island_rect.size)
	_apply_island()

func _apply_island() -> void:
	if island_root == null:
		return
	var w := island_rect.size.x
	var h := island_rect.size.y
	island_root.visible = _island_vis > 0.01
	island_root.modulate.a = _island_vis
	var cols := _choice_cols(_choice_n) if _choice_mode else 2
	var two_rows : bool = _choice_mode and _choice_n > cols
	if _choice_mode and cols == 3:
		# Three options to a row: the island splits into thirds.
		var bottom : Array = [island_red, island_green, island_b3]
		for k in range(3):
			var cb : Button = bottom[k]
			cb.visible = true
			cb.position = Vector2(w * k / 3.0, 0.0)
			cb.size = Vector2(maxf(w / 3.0 - (3.0 if k < 2 else 0.0), 0.0), h)
	else:
		var rw := w * _island_split
		island_red.visible = _island_split > 0.01
		island_red.position = Vector2.ZERO
		island_red.size = Vector2(maxf(rw - (3.0 if _island_split < 0.99 else 0.0), 0.0), h)
		island_green.visible = _island_split < 0.99
		island_green.position = Vector2(rw, 0.0)
		island_green.size = Vector2(maxf(w - rw, 0.0), h)
		island_b3.visible = false
	var th := island_tab.size.y
	var extra_h : float = (h + 4.0) if two_rows else 0.0
	# The second row, above the island: as many columns as the island's row (an unused slot is an
	# inert grey "-").
	var top : Array = [island_x3, island_x4, island_x5]
	for k in range(3):
		var tb : Button = top[k]
		tb.visible = two_rows and k < cols
		tb.position = Vector2(w * k / float(cols), -h - 4.0)
		tb.size = Vector2(maxf(w / float(cols) - (3.0 if k < cols - 1 else 0.0), 0.0), h)
	# The label tab rests right on the top edge of the bar's border below it (no gap).
	island_tab.position = Vector2((w - island_tab.size.x) / 2.0, -th - extra_h + (1.0 - _island_vis) * (th + extra_h))
	ability_label.visible = _island_vis < 0.05

# What the game is currently asking for, as an OK / Cancel pair (or {} if nothing).
var island_b3 : Button # (the island's third button, when it splits in three)
var island_x3 : Button
var island_x4 : Button
var island_x5 : Button
var _island_sparkle : Control
var _choice_mode : bool = false
var _choice_n : int = 0
var _choice_key : String = ""
const _CHOICE_COLORS := [Color(0.15, 0.40, 0.80), Color(0.55, 0.30, 0.78), Color(0.88, 0.60, 0.10),
		Color(0.40, 0.48, 0.60), Color(0.10, 0.56, 0.52), Color(0.78, 0.26, 0.46)]
const _CHOICE_FILLER_COLOR := Color(0.45, 0.47, 0.52)
# The most effect options shown as island buttons (two rows of three); more keep the popup.
const MAX_ISLAND_CHOICES := 6

# Buttons to a row for `n` options: 2 and 4 options pair up (one row / two rows of two); 3, 5 and 6
# go three to a row (5: the last slot is an inert grey "-").
static func _choice_cols(n : int) -> int:
	return 2 if n <= 2 or n == 4 else 3

# "Select which effect to resolve first" with 2-6 options: they become island buttons
# (no popup). Returns the option count, or 0 when this doesn't apply (7+ keeps the popup).
func _choice_count() -> int:
	if _topdeck_picking():
		# A top-of-deck card is selected: its options (Boost / Strike / Pass...) are the buttons.
		if game.selected_cards.size() != 1:
			return 0
		var opts := _topdeck_options()
		return opts.size() if opts.size() >= 2 and opts.size() <= MAX_ISLAND_CHOICES else 0
	var n := _order_choice_count()
	if n > 0:
		return n
	# Any other effect choice with 2-6 options (Possession: Draw 1 / Advance 2, Unholy Diver:
	# Boost and Sustain / Pass...) too, unless it's a movement choice (tap a highlighted
	# space) or a revealed-card pick (tap the card): those have their own controls.
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_MakeChoice:
		return 0
	if not g.action_menu_container.visible or not g.action_menu.visible:
		return 0
	var di = g.game_wrapper.get_decision_info()
	if di == null or di.type != Enums.DecisionType.DecisionType_EffectChoice:
		return 0
	if not _gauge_pass_info().is_empty():
		return 0 # (a plain O / X: "Add X to Gauge?")
	n = g.current_action_menu_choices.size()
	if n < 2 or n > MAX_ISLAND_CHOICES:
		return 0
	if not _move_choice_map().is_empty() or not _reveal_pick_info().is_empty():
		return 0
	return n

# An effect choice that is just "add a card to Gauge" or Pass: the island asks "Add X to
# Gauge?" with its green O (add) and red X (pass). Returns {ok, cancel, title} or {}.
func _gauge_pass_info() -> Dictionary:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_MakeChoice:
		return {}
	if not g.action_menu_container.visible:
		return {}
	var di = g.game_wrapper.get_decision_info()
	if di == null or di.type != Enums.DecisionType.DecisionType_EffectChoice or not (di.choice is Array):
		return {}
	var choices : Array = g.current_action_menu_choices
	if choices.size() != 2 or di.choice.size() != 2:
		return {}
	var pass_i := -1
	var gauge_i := -1
	for i in range(2):
		var e = di.choice[i]
		if not (e is Dictionary):
			return {}
		if str(e.get("effect_type", "")) == "pass":
			pass_i = i
		elif _choice_clean(str(choices[i].get("text", ""))).to_lower().contains("to gauge") and not e.has("and"):
			gauge_i = i
	if pass_i < 0 or gauge_i < 0:
		return {}
	# What is added: the card the option names, else the card the choice comes from.
	var what := ""
	var e2 : Dictionary = di.choice[gauge_i]
	if e2.has("card_name"):
		what = str(e2["card_name"])
	if what == "":
		var m := RegEx.create_from_string("(?i)^add (.+?) to gauge").search(_choice_clean(str(choices[gauge_i].get("text", ""))))
		if m != null and not (m.get_string(1).to_lower() in ["card", "this", "this card", "it", "the card"]):
			what = m.get_string(1)
	if what == "" and di.choice_card_id >= 0:
		var lc = g.game_wrapper.get_card_database().get_card(di.choice_card_id)
		if lc != null:
			what = str(lc.definition.get("display_name", ""))
	if what == "":
		what = "this card"
	return {"ok": gauge_i, "cancel": pass_i, "title": "Add %s to Gauge?" % what}

# "Select which effect to resolve first" prompts only (2-6 options).
func _order_choice_count() -> int:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_MakeChoice:
		return 0
	if not g.action_menu_container.visible or not g.action_menu.visible:
		return 0
	if g.action_menu.instructions_label.text.findn("resolve first") == -1:
		return 0
	var n : int = g.current_action_menu_choices.size()
	return n if n >= 2 and n <= MAX_ISLAND_CHOICES else 0

func _choice_press(i : int) -> void:
	if _choice_count() <= i:
		return
	if _topdeck_picking():
		var opt : Dictionary = _topdeck_options()[i]
		if int(opt["ok"]) >= 0:
			game._on_instructions_ok_button_pressed(int(opt["ok"]))
		else:
			game._on_instructions_cancel_button_pressed()
		return
	game.action_menu._on_choice_pressed(i)

# The island's buttons in choice mode: [{text, disabled}].
func _island_choice_list() -> Array:
	if _topdeck_picking():
		return _topdeck_options()
	return game.current_action_menu_choices

func _choice_clean(t : String) -> String:
	t = t.replace("[lb]", "@@LB@@").replace("[rb]", "@@RB@@")
	var re := RegEx.new()
	re.compile("\\[[^\\]]*\\]")
	t = re.sub(t, "", true).strip_edges()
	return t.replace("@@LB@@", "[").replace("@@RB@@", "]").replace("\n", " ")

func _style_island_button(b : Button, col : Color) -> void:
	# Rounded, with a bright rim, a darker base edge and a soft drop shadow; pressing pushes
	# the button down (a smaller shadow, darker face).
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		var face : Color = col.lightened(0.15) if st == "hover" else (col.darkened(0.2) if st == "pressed" else col)
		sb.bg_color = face
		sb.set_corner_radius_all(14)
		sb.border_color = face.lightened(0.45)
		sb.set_border_width_all(2)
		sb.border_width_bottom = 5
		sb.border_color = face.lightened(0.4)
		sb.shadow_color = Color(0, 0, 0, 0.45)
		sb.shadow_size = 3 if st == "pressed" else 7
		sb.shadow_offset = Vector2(0, 1 if st == "pressed" else 3)
		b.add_theme_stylebox_override(st, sb)

# Wraps (by hand, so the button can't grow) and sizes the text to fit its button.
func _set_choice_button(b : Button, txt : String, bw : float, bh : float, col : Color, disabled : bool) -> void:
	_style_island_button(b, col)
	var font : Font = b.get_theme_font("font")
	var fs := 22
	var wrapped := txt
	while fs >= 11:
		var lines : Array[String] = []
		var cur := ""
		for word in txt.split(" ", false):
			var trial : String = word if cur == "" else cur + " " + word
			if cur != "" and font.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > bw - 16.0:
				lines.append(cur)
				cur = word
			else:
				cur = trial
		lines.append(cur)
		wrapped = "\n".join(lines)
		if float(lines.size()) * float(fs) * 1.25 <= bh - 8.0:
			break
		fs -= 1
	b.autowrap_mode = TextServer.AUTOWRAP_OFF
	b.clip_text = true
	b.add_theme_constant_override("outline_size", 0)
	b.add_theme_font_size_override("font_size", fs)
	b.text = wrapped
	b.disabled = disabled

func _update_choice_buttons() -> void:
	var n := _choice_count()
	var was := _choice_mode
	_choice_mode = n > 0
	_choice_n = n
	if not _choice_mode:
		if was:
			_choice_key = ""
			_style_island_button(island_red, Color(0.78, 0.14, 0.16))
			_style_island_button(island_green, Color(0.16, 0.62, 0.26))
			island_red.text = "X"
			island_green.text = "O"
			island_red.disabled = false
			island_green.disabled = false
			island_red.add_theme_constant_override("outline_size", 8)
			island_green.add_theme_constant_override("outline_size", 8)
			_layout_island()
		return
	var choices : Array = _island_choice_list()
	var texts : Array = []
	for c in choices:
		texts.append(_choice_clean(str(c.get("text", ""))) + ("|d" if c.get("disabled", false) else ""))
	var key : String = "|".join(texts) + "|" + str(island_rect.size)
	if key == _choice_key and was:
		return
	_choice_key = key
	var w := island_rect.size.x
	var h := island_rect.size.y
	# Slots in option order: the island's row left to right, then the row above it.
	# (The red / green buttons press options 0 / 1 through _island_press; the others carry
	# their option's index.)
	var cols := _choice_cols(n)
	var rows := 1 if n <= cols else 2
	var bottom : Array = [island_red, island_green, island_b3]
	var top : Array = [island_x3, island_x4, island_x5]
	var slots : Array = bottom.slice(0, cols) + (top.slice(0, cols) if rows == 2 else [])
	for b in [island_b3, island_x3, island_x4, island_x5]:
		b.set_meta("choice_idx", -1)
		b.mouse_filter = Control.MOUSE_FILTER_STOP
	var bw := w / float(cols) - 3.0
	for i in range(slots.size()):
		var b : Button = slots[i]
		if i < n:
			_set_choice_button(b, _choice_clean(str(choices[i].get("text", ""))), bw, h,
					_CHOICE_COLORS[i], bool(choices[i].get("disabled", false)))
			if b != island_red and b != island_green:
				b.set_meta("choice_idx", i)
		else:
			# An unused slot (5 options): greyed out with a big, bold "-".
			_style_island_button(b, _CHOICE_FILLER_COLOR)
			b.text = "-"
			b.disabled = false
			b.mouse_filter = Control.MOUSE_FILTER_IGNORE
			b.add_theme_constant_override("outline_size", 16)
			b.add_theme_font_size_override("font_size", int(island_rect.size.y * 0.75))
	_apply_island()

# Walks `n` spaces in direction `d` from `start`, stopping at the walls and hopping over
# `skip_loc` (a character's space can't be landed on).
func _step_move(start : int, d : int, n : int, skip_loc : int) -> int:
	var loc := start
	for _i in range(n):
		var nl := loc + d
		if nl == skip_loc:
			nl += d
		if nl < 1 or nl > 9:
			break
		loc = nl
	return loc

# Close: up to `n` spaces toward the opponent, stopping next to them (never passing them).
func _close_move(start : int, opp : int, n : int) -> int:
	var d := 1 if opp > start else -1
	var loc := start
	for _i in range(n):
		if loc + d == opp:
			break
		loc += d
	return loc

# An effect choice made only of push / pull / advance / retreat / close options (Grasp, Area Shift,
# Respect...): each option's landing space, so the options can be picked by tapping the
# arena. {} when it doesn't apply or can't be shown that way (the popup stays).
# Result: {"dest": {space: choice_index}, "pass": index or -1}.
func _move_choice_map() -> Dictionary:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_MakeChoice or not g.action_menu_container.visible:
		return {}
	if _order_choice_count() > 0:
		return {}
	var di = g.game_wrapper.get_decision_info()
	if di == null or di.type != Enums.DecisionType.DecisionType_EffectChoice:
		return {}
	var ch : Array = di.choice
	var menu : Array = g.current_action_menu_choices
	if ch.is_empty() or menu.size() < ch.size():
		return {}
	var m : int = g.game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player)
	var o : int = g.game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Opponent)
	var d : int = 1 if o > m else -1
	var dest := {}
	var pass_idx := -1
	var opp_moves := 0
	var self_moves := 0
	for i in range(ch.size()):
		var e = ch[i]
		var et : String = str(e.get("effect_type", ""))
		if et == "pass":
			pass_idx = i
			continue
		if menu[i].get("disabled", false):
			continue
		var amt = e.get("amount", null)
		if not (amt is int or amt is float):
			return {}
		var n : int = int(amt)
		if et == "push" or et == "pull":
			opp_moves += 1
		else:
			self_moves += 1
		var land : int
		match et:
			"push": land = _step_move(o, d, n, -1)
			"pull": land = _step_move(o, -d, n, m)
			"advance": land = _step_move(m, d, n, o)
			"retreat": land = _step_move(m, -d, n, -1)
			"close": land = _close_move(m, o, n)
			_: return {}
		# An option that can't move its character (a wall, a corner...) lands on that
		# character's own space, which is then the tappable choice. Options that end on the
		# same space do the same thing: the first one stands.
		if land in dest:
			continue
		dest[land] = i
	if dest.is_empty():
		return {}
	return {"dest": dest, "pass": pass_idx, "moves_opponent": opp_moves > 0 and self_moves == 0}

var _dash_on : bool = false

# Nothing to confirm (the choice is made by tapping the arena): the island's O becomes a
# grey, inert "-".
func _update_dash_button(on : bool) -> void:
	if on:
		island_green.modulate = Color.WHITE
	if on == _dash_on:
		return
	_dash_on = on
	if on:
		_style_island_button(island_green, Color(0.45, 0.47, 0.52))
		island_green.text = "-"
		island_green.add_theme_constant_override("outline_size", 16)
	else:
		_style_island_button(island_green, Color(0.16, 0.62, 0.26))
		island_green.text = "O"
		island_green.add_theme_constant_override("outline_size", 8)

func _island_info() -> Dictionary:
	var g = game
	if not g.action_menu_container.visible or not g.action_menu.visible:
		return {}
	var gp := _gauge_pass_info()
	if not gp.is_empty():
		return {"ok": gp["ok"], "cancel": gp["cancel"], "ok_disabled": false}
	if _choice_count() > 0:
		return {"ok": 1, "cancel": 0, "ok_disabled": false}
	if _topdeck_picking() and g.selected_cards.size() == 1 and _topdeck_options().size() == 1:
		# One thing to do with the selected card (e.g. Faust's Exceed action: boost it): O does it.
		return {"ok": int(_topdeck_options()[0]["ok"]), "cancel": -1, "ok_disabled": false}
	if _topdeck_picking():
		# Nothing selected yet: the prompt, with X to pass (when allowed) and a dimmed O.
		var di = g.game_wrapper.get_decision_info()
		return {"ok": -1, "cancel": -1, "ok_disabled": true, "topdeck_pass": di != null and di.can_pass}
	var rpi := _reveal_pick_info()
	if not rpi.is_empty():
		return {"ok": rpi["discard"], "cancel": rpi["pass"], "ok_disabled": not _reveal_pick_selected}
	var mcm := _move_choice_map()
	if not mcm.is_empty():
		return {"ok": -1, "cancel": mcm["pass"], "ok_disabled": true}
	var ok_idx := -1
	var cancel_idx := -1
	var ok_disabled := false
	var choices : Array = g.current_action_menu_choices
	for i in range(choices.size()):
		var t : String = str(choices[i].get("text", ""))
		if t == "OK" or t == "Confirm":
			ok_idx = i
			ok_disabled = bool(choices[i].get("disabled", false))
		elif t.begins_with("Cancel") and cancel_idx == -1:
			cancel_idx = i
		elif t == "Pass" and cancel_idx == -1 and (ok_idx != -1 or g.ui_sub_state == g.UISubState.UISubState_SelectCards_Mulligan or g.ui_state == g.UIState.UIState_SelectArenaLocation):
			cancel_idx = i # "Pass" next to an OK (mulligan, cancelling a boost...) is the cancel
	# The wild swing picked with the deck: O wild swings, X lets it go (see _island_press).
	if _ws_pending_live():
		for i in range(choices.size()):
			if str(choices[i].get("text", "")) == "Wild Swing":
				return {"ok": i, "cancel": cancel_idx, "ok_disabled": false, "ws_pending": true}
	# Paying for an attack (e.g. an Ultra drawn by a wild swing) that may be invalidated instead:
	# X wild swings instead of paying.
	if _is_cost_wild():
		for i in range(choices.size()):
			if str(choices[i].get("text", "")) == "Wild Swing":
				cancel_idx = i
	if ok_idx == -1 and cancel_idx == -1:
		# Choosing a strike card: the island just carries the prompt (dimmed O).
		if _is_strike_pick():
			return {"ok": -1, "cancel": -1, "ok_disabled": true}
		return {}
	return {"ok": ok_idx, "cancel": cancel_idx, "ok_disabled": ok_disabled}

# Paying an attack's Gauge / Force cost with the option to invalidate it (wild swing instead).
func _is_cost_wild() -> bool:
	var g = game
	if g.ui_state != g.UIState.UIState_SelectCards:
		return false
	if not (g.ui_sub_state in [g.UISubState.UISubState_SelectCards_StrikeGauge, g.UISubState.UISubState_SelectCards_StrikeForce]):
		return false
	for c in g.current_action_menu_choices:
		if str(c.get("text", "")) == "Wild Swing":
			return true
	return false

# Picking a card to strike (or respond to a strike) with.
func _is_strike_pick() -> bool:
	var g = game
	if g.ui_state != g.UIState.UIState_SelectCards:
		return false
	var subs := [g.UISubState.UISubState_SelectCards_StrikeCard, g.UISubState.UISubState_SelectCards_StrikeResponseCard,
			g.UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeCard, g.UISubState.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard]
	if not (g.ui_sub_state in subs):
		return false
	for c in g.current_action_menu_choices:
		if str(c.get("text", "")) == "Wild Swing":
			return true
	return false

# The action chosen from the turn menu (Exceed, Change Cards, ...), remembered so the island
# can name it while its cost is being paid.
var _choice_snapshot : Array = []
var _pending_action : String = ""
var _pending_time : int = 0

const _ACTION_COST_SUBSTATES := [
	"UISubState_SelectCards_Exceed", "UISubState_SelectCards_CharacterAction_Force",
	"UISubState_SelectCards_CharacterAction_Gauge", "UISubState_SelectCards_ForceForChange",
	"UISubState_SelectCards_ForceForBoost", "UISubState_SelectCards_GaugeForBoost",
	"UISubState_SelectCards_MoveActionGenerateForce",
]

func _track_pending_action() -> void:
	var g = game
	if g.ui_state == g.UIState.UIState_PickTurnAction:
		if g.action_menu_container.visible:
			_choice_snapshot = []
			for c in g.current_action_menu_choices:
				_choice_snapshot.append(str(c.get("text", "")))
		if Time.get_ticks_msec() - _pending_time > 500:
			_pending_action = ""

func _on_action_menu_choice(index : int) -> void:
	if game.ui_state != game.UIState.UIState_PickTurnAction:
		return
	if index < 0 or index >= _choice_snapshot.size():
		return
	var t : String = _choice_snapshot[index]
	if t == "" or t.begins_with("Deselect") or t == "OK" or t == "Cancel" or t == "Pass":
		return
	_pending_action = t
	_pending_time = Time.get_ticks_msec()

func _with_action_name(title : String) -> String:
	var g = game
	if _pending_action == "" or g.ui_state != g.UIState.UIState_SelectCards:
		return title
	var sub_ok := false
	for n in _ACTION_COST_SUBSTATES:
		if g.ui_sub_state == g.UISubState[n]:
			sub_ok = true
	if not sub_ok or title.findn(_pending_action) != -1:
		return title
	return "%s: %s" % [_pending_action, title]

# The player's active bonus effect(s), as shown in the ice popup, on one line ("" if none).
func _bonus_effect_text() -> String:
	return _bonus_effect_text_for(0)

var _ability_box := Rect2()

# Vertically centres the character ability text in its box (a RichTextLabel has no vertical
# alignment, so the space above is made with the label's top content margin).
func _center_ability_text(al : RichTextLabel) -> void:
	if _ability_box.size.y <= 1.0:
		return
	# Shrink the label to its text and centre that inside the ability box (no margin tricks:
	# those drifted to bottom-aligned on the phone).
	al.fit_content = true
	al.remove_theme_stylebox_override("normal")
	var h : float = minf(al.get_content_height(), _ability_box.size.y)
	if h <= 1.0:
		return
	al.size = Vector2(_ability_box.size.x, h)
	al.position = Vector2(_ability_box.position.x, _ability_box.position.y + floorf((_ability_box.size.y - h) / 2.0))

var _bonus_forced : bool = false
var _ability_overridden : bool = false
var _ability_orig : String = ""
var _ability_glow : Panel

# On the player's turn, before a strike is set: the bonus effect(s) their character ability
# will add to the strike once it is set (e.g. Sol: canceled this turn -> +Power). "" if none.
func _pending_bonus_text() -> String:
	var g = game
	if g.observer_mode or g.game_wrapper == null:
		return ""
	if g.game_wrapper.get_active_player() != Enums.PlayerId.PlayerId_Player or g.game_wrapper.has_active_strike():
		return ""
	var p = g.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	if p == null:
		return ""
	var parts : Array[String] = []
	for e in p.get_character_effects_at_timing("set_strike"):
		if str(e.get("condition", "")) == "used_character_action" and str(p.deck_def.get("id", "")) in ACTION_PREVIEW_CHARACTERS:
			if _action_effect_applies(p, e):
				var line : String = ACTION_PREVIEW_TEXT.get(str(p.deck_def.get("id", "")), _effect_line(e))
				if line != "":
					parts.append(line)
			continue
		if str(e.get("effect_type", "")) != "add_attack_effect" or not e.has("added_effect"):
			continue
		var cond := str(e.get("condition", ""))
		var met := false
		if cond == "canceled_this_turn":
			met = p.canceled_this_turn
		elif cond == "not_canceled_this_turn":
			met = not p.canceled_this_turn
		if not met:
			continue
		var t : String = str(GameStrings.get_effect_text(e["added_effect"], false, true, true, "", true))
		t = t.replace("\n", " ").strip_edges()
		if t != "":
			parts.append(t)
	return "; ".join(parts)

# Shows the ice bonus box early and lights up the character ability box while a bonus is
# waiting for the strike.
func _update_bonus_preview() -> void:
	var pend := _pending_bonus_text()
	var panel = game.player_bonus_panel
	var al : RichTextLabel = ability_label
	if al == null:
		return
	_center_ability_text(al)
	if pend != "":
		if not panel.visible:
			# The game only clears the panel's old text when it shows the panel itself. Since
			# the panel is shown early here, clear it now, or the real bonus effect would be
			# appended to the previous strike's leftovers (showing the bonus twice).
			(game.player_bonus_label as RichTextLabel).text = ""
			panel.visible = true
		_bonus_forced = true
		var want := "[center][color=#ffd86b][b]Bonus Effect active this strike[/b][/color]\n%s[/center]" % pend
		if al.text != want:
			if not _ability_overridden:
				_ability_orig = al.text
			_ability_overridden = true
			al.text = want
		if _ability_glow == null:
			_ability_glow = Panel.new()
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(1.0, 0.8, 0.3, 0.10)
			sb.border_color = Color(1.0, 0.78, 0.25, 0.95)
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(10)
			sb.shadow_color = Color(1.0, 0.7, 0.2, 0.5)
			sb.shadow_size = 10
			_ability_glow.add_theme_stylebox_override("panel", sb)
			_ability_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			_ability_glow.z_index = 9
			al.get_parent().add_child(_ability_glow)
		_ability_glow.visible = true
		_ability_glow.position = _ability_box.position - Vector2(3, 3)
		_ability_glow.size = _ability_box.size + Vector2(6, 6)
		_ability_glow.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 1000.0 * 4.0)
	else:
		if _ability_glow != null:
			_ability_glow.visible = false
		if _bonus_forced:
			_bonus_forced = false
			# Never confirmed by a strike (turn ended...): take the early box away again.
			if game.player_bonus_label.get_parsed_text().strip_edges() == "":
				panel.visible = false
		if _ability_overridden:
			_ability_overridden = false
			al.text = _ability_orig
	_update_permanent_bonus()
	_update_exceed_note()
	_update_action_glow(pend != "")

# ---- "When you Exceed" effects ------------------------------------------------------------------
# They're left out of the character action box. Instead, on your turn while you have the gauge to
# exceed (and aren't exceeded or striking), the line shows in your bonus box as a reminder.
var _exceed_note : String = ""       # your "When you Exceed" line(s), plain text
var _exceed_note_shown : String = "" # the line currently in your bonus box ("" none)
var _exceed_tag_re : RegEx

func _plain(text : String) -> String:
	if _exceed_tag_re == null:
		_exceed_tag_re = RegEx.new()
		_exceed_tag_re.compile("\\[[^\\]]*\\]")
	return _exceed_tag_re.sub(text, "", true).strip_edges()

func _is_exceed_line(line : String) -> bool:
	return _plain(line).to_lower().begins_with("when you exceed")

# `text` without its "When you Exceed" lines.
func _without_exceed_lines(text : String) -> String:
	var keep : Array[String] = []
	for ln in text.split("\n", false):
		if not _is_exceed_line(ln):
			keep.append(ln)
	return "\n".join(keep).strip_edges()

# Just the "When you Exceed" lines of `text`, as one plain line.
func _exceed_lines_of(text : String) -> String:
	var parts : Array[String] = []
	for ln in text.split("\n", false):
		if _is_exceed_line(ln):
			parts.append(_plain(ln))
	return " ".join(parts)

func _exceed_note_wanted() -> String:
	var g = game
	var gw = g.game_wrapper
	if _exceed_note == "" or g.observer_mode or gw == null or gw.current_game == null:
		return ""
	var me := Enums.PlayerId.PlayerId_Player
	if gw.is_player_exceeded(me) or not _side_turn(0) or gw.has_active_strike():
		return ""
	var cost := int(gw.get_player_exceed_cost(me))
	if cost < 0 or int(gw.get_player_gauge_size(me)) < cost:
		return ""
	return _exceed_note

func _update_exceed_note() -> void:
	var want := _exceed_note_wanted()
	var panel = game.player_bonus_panel
	# (the game hides the box between strikes and turns, clearing it: then it's no longer there.
	# The box being up again doesn't mean it is back: a character's always-shown line (Giovanna's)
	# may have been put back on its own, so look for the line itself.)
	var present : bool = _exceed_note_shown != "" and panel.visible and _bonus_box_has_line(0, _exceed_note_shown)
	if want == _exceed_note_shown and (want == "" or present):
		return
	if present:
		_remove_bonus_line(0, _exceed_note_shown)
	_exceed_note_shown = want
	if want != "":
		game._add_bonus_label_text(Enums.PlayerId.PlayerId_Player, want, true)

# The lines in a side's bonus box, as plain text (the "* " bullets and wrapping undone).
func _bonus_box_lines(side : int) -> Array[String]:
	var label = game.player_bonus_label if side == 0 else game.opponent_bonus_label
	var out : Array[String] = []
	var raw : String = label.get_parsed_text()
	raw = raw.replace(" \n    ", " ").replace("\n    ", " ")
	for ln in raw.split("\n", false):
		var t := ln.strip_edges()
		if t.begins_with("*"):
			t = t.substr(1).strip_edges()
		if t != "":
			out.append(t)
	return out

func _bonus_box_has_line(side : int, line : String) -> bool:
	var want := _norm_bonus(line)
	for t in _bonus_box_lines(side):
		if _norm_bonus(t) == want:
			return true
	return false

# Takes one line out of a side's bonus box, keeping the others (the box is hidden if none are left).
func _remove_bonus_line(side : int, line : String) -> void:
	var pid := Enums.PlayerId.PlayerId_Player if side == 0 else Enums.PlayerId.PlayerId_Opponent
	var panel = game.player_bonus_panel if side == 0 else game.opponent_bonus_panel
	var keep : Array[String] = []
	var gone := _norm_bonus(line)
	for t in _bonus_box_lines(side):
		if _norm_bonus(t) != gone:
			keep.append(t)
	panel.visible = false
	for t in keep:
		game._add_bonus_label_text(pid, t, true)

# The character action box, highlighted and pulsing while your character action can be used (your
# turn to pick an action). The gold bonus glow takes precedence while a bonus is pending.
var _action_glow : Panel
const ACTION_GLOW_COLOR := Color(0.25, 1.0, 0.55)

func _update_action_glow(bonus_glow_on : bool) -> void:
	var al : RichTextLabel = ability_label
	var want : bool = not bonus_glow_on and al != null and al.visible and _character_action_available()
	if not want:
		if _action_glow != null:
			_action_glow.visible = false
		return
	if _action_glow == null:
		# Just a border (no fill, no glow spilling out), lying against the inside edge of the
		# bar's metal bevel.
		_action_glow = Panel.new()
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0, 0, 0)
		sb.border_color = ACTION_GLOW_COLOR
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(2)
		sb.anti_aliasing = false # (crisp against the bevel's straight inner edge)
		_action_glow.add_theme_stylebox_override("panel", sb)
		_action_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_action_glow.z_index = 9
		al.get_parent().add_child(_action_glow)
	_action_glow.visible = true
	# Top and bottom: the inside edge of the metal bevel (MetalBar.edge, capped as it draws it).
	# Sides: the action box's own area between the icons (the right part when the multi-action
	# box takes its left half).
	var bar : Control = panels["bottom"]
	var metal = bar.get_node_or_null("Metal")
	var e : float = minf(float(metal.edge) if metal != null else 7.0, bar.size.y * 0.2)
	var btn : Control = panels["ability_btn"]
	_action_glow.position = Vector2(btn.position.x, bar.position.y + e)
	_action_glow.size = Vector2(btn.size.x, bar.size.y - 2.0 * e)
	# Only the border's brightness pulses (its size stays put).
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 4.5)
	_action_glow.modulate.a = 0.45 + 0.55 * pulse

# Can you use a character action right now (your turn, choosing an action)?
func _character_action_available() -> bool:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_PickTurnAction:
		return false
	var gw = g.game_wrapper
	if gw.get_active_player() != Enums.PlayerId.PlayerId_Player:
		return false
	for i in range(gw.get_player_character_action_count(Enums.PlayerId.PlayerId_Player)):
		if gw.can_do_character_action(Enums.PlayerId.PlayerId_Player, i):
			return true
	return false

# Characters whose ability is always in effect (e.g. Testament: Hit with a normal -> Push 1 /
# Pull 1): its text stays in that player's bonus effect box (yours or the opponent's) at all
# times as a reminder, with any other strike
# bonuses listed under it. Add a character's deck id to do the same for another.
const PERMANENT_BONUS_CHARACTERS := ["testament", "nago", "happychaos", "millia", "zato", "chipp", "axl", "leo", "anji"]
# Characters whose ability only works on their own turn (Giovanna: only a strike she starts): the
# box shows it during that character's turns only, for either player.
const TURN_BONUS_CHARACTERS := ["giovanna", "potemkin", "may", "ramlethal"]
# The ability box's text when it differs from the bonus box's, [front side, exceeded side].
# (Characters without an entry show their PERMANENT_BONUS_TEXT there too. A null side keeps the
# text the game generates.)
const PRINTED_ABILITY_TEXT := {
	"axl": ["When you Exceed, draw 2 and Retreat up to 2", null],
	"potemkin": ["When you Exceed, close 2", null],
	"may": ["When you Exceed, draw 2 and Strike", null],
	"leo": [null, "When you end a turn without Striking, revert"],
	"ramlethal": ["When you Exceed, draw 3", null],
	"anji": ["When you Exceed, draw 1 and Strike", null],
	"faust": [
		"[b]Action:[/b] Boost with the top card of your deck and Strike",
		"[b]Action:[/b] Reveal the top 2 cards of your deck. Boost with one and discard the other, then Strike",
	],
	"jacko": [
		"When you Exceed, draw 3\n[b]Action:[/b] Spend 1 Force to play a Continuous Boost from your hand, then Strike",
		"[b]Action:[/b] Spend 1 Force to play a Continuous Boost from your hand or Gauge, then Strike",
	],
	"baiken": [
		"[b]Action:[/b] Spend 1 Gauge to pull 2 up to you and Strike",
		"[b]Action:[/b] Spend 1 Gauge to pull 2 and Strike with +1 Power",
	],
	"zato": [
		"Your Normals have \"[b]After:[/b] You may place Eddie in a space within this attack's Range.\"",
		"Your Normals have \"[b]After:[/b] You may place Eddie in any space.\"",
	],
	"happychaos": [
		"When you Exceed, Strike with Deus Ex Machina. Revert during cleanup.",
		"When you Exceed, Strike with Deus Ex Machina. Revert during cleanup.",
	],
	"ino": [
		"[b]1 Force ACTION:[/b] Advance 2. Strike.",
		"[b]1 Force ACTION:[/b] Advance 2. Strike; [b][color=#ff4040]+1 Power[/color][/b].",
	],
	"chipp": [
		"[b]After:[/b] You may Advance 1 or Retreat 1.",
		"When you Cancel, you may Draw 1.",
	],
	"nago": [
		"When you Reshuffle, Exceed at end of turn.",
		"Your Specials are invalid.",
	],
}
# The wording printed on the character card, [front side, exceeded side]. Characters without an
# entry use the ability text that the game generates.
const PERMANENT_BONUS_TEXT := {
	"axl": [
		"Your Normals have +0-2 Range, -1 Speed",
		"+0-2 Range",
	],
	"potemkin": [
		"Set, Range 1: +1 Power, +1 Armor",
		"Set, Range 1: +2 Power, +2 Armor",
	],
	"may": [
		"You may spend 1 Force for +1 Power",
		"You may spend 1 Force for +2 Power",
	],
	"ramlethal": [
		"You may spend 2 Force for +0-1 Range",
		"You may spend 2 Force for +0-1 Range, +1 Power",
	],
	"anji": [
		"You may spend 1 Force for -1 Speed, +2 Guard",
		"You may spend 1 Force for -1 Speed, +2 Armor",
	],
	"leo": [
		"After: If the opponent is stunned, Exceed for free",
		"Your Wild Swings have +1 Power, +1 Speed",
	],
	"millia": [
		"After: If the opponent is stunned, you may draw 1, Advance 2, or Retreat 2.",
		"After: If the opponent is stunned, you may draw 1, Advance 2, Retreat 2, or gain Advantage.",
	],
	"chipp": [
		"After: You may Advance 1 or Retreat 1.",
		"After: You may Advance 1 or Retreat 1.",
	],
	"giovanna": [
		"Hit: You may draw 1.",
		"You may spend 1 Gauge for +1 Power and \"Hit: Draw 2\"",
	],
	"happychaos": [
		"HIT: You may seal an Ultra from your hand. If you do, +1 Power and gain Advantage.",
		"",
	],
	"nago": [
		"Your Specials have: \"Cleanup: Draw 4. Discard 2.\"",
		"Your Normals have +1 Power and \"Cleanup: Take 2 non-lethal damage.\"",
	],
	"testament": [
		"Your Normals have \"Hit: You may Push or Pull 1.\"",
		"Your Normals have \"Hit: Draw 1. You may Push or Pull 1.\"",
	],
}
# The game's own strike-bonus lines that a character's always-shown line already covers.
const BONUS_LINES_COVERED := {
	"giovanna": ["Hit: Draw 1", "Hit: Draw 2"],
}

var _norm_re : RegEx
func _norm_bonus(t : String) -> String:
	if _norm_re == null:
		_norm_re = RegEx.new()
		_norm_re.compile("\\[[^\\]]*\\]|[^a-z0-9+\\- ]")
	var n := _norm_re.sub(t.to_lower(), "", true)
	while n.contains("  "):
		n = n.replace("  ", " ")
	return n.strip_edges()

# True when the game's own bonus line `t` only repeats what the always-shown line says (or is the
# character's always-shown line for its other side).
func _covered_by_permanent(side : int, t : String) -> bool:
	var did := _side_deck_id(side)
	if t in BONUS_LINES_COVERED.get(did, []):
		return true
	var printed = PERMANENT_BONUS_TEXT.get(did)
	if printed != null and t in printed:
		return true
	var nt := _norm_bonus(t)
	return nt.length() >= 6 and _norm_bonus(_perm_lines[side]).contains(nt)

func hides_character_effect_lines(player) -> bool:
	var side := 0 if int(player) == int(Enums.PlayerId.PlayerId_Player) else 1
	return _perm_lines[side] != ""

func _side_deck_id(side : int) -> String:
	return str((game.player_deck if side == 0 else game.opponent_deck).get("id", ""))

var _perm_lines : Array = ["", ""] # the always-shown line in each side's box (player, opponent)

func _side_turn(side : int) -> bool:
	var turn : int = _ui_turn
	if turn < 0:
		turn = int(game.game_wrapper.get_active_player())
	return turn == int(Enums.PlayerId.PlayerId_Player if side == 0 else Enums.PlayerId.PlayerId_Opponent)

func _permanent_bonus_line(side : int = 0) -> String:
	var deck : Dictionary = game.player_deck if side == 0 else game.opponent_deck
	var did := str(deck.get("id", ""))
	if did in TURN_BONUS_CHARACTERS:
		if not _side_turn(side):
			return ""
	elif not did in PERMANENT_BONUS_CHARACTERS:
		return "" # (for either player: the opponent's box is a reminder of what they can do)
	var pid := Enums.PlayerId.PlayerId_Player if side == 0 else Enums.PlayerId.PlayerId_Opponent
	var exceeded : bool = game.game_wrapper.is_player_exceeded(pid)
	if did == "zato":
		return _zato_bonus_line(pid, exceeded)
	var printed = PERMANENT_BONUS_TEXT.get(did)
	if printed != null:
		return printed[1 if exceeded else 0]
	var key := "ability_effects"
	if deck.has("exceed_ability_effects") and exceeded:
		key = "exceed_ability_effects"
	# The same wording as the ability box ("Hit: If you strike with a normal, Choose: ..."),
	# as one plain line.
	if _perm_tag_re == null:
		_perm_tag_re = RegEx.new()
		_perm_tag_re.compile("\\[[^\\]]*\\]")
	var raw : String = _perm_tag_re.sub(str(GameStrings.get_effects_text(deck.get(key, []))), "", true)
	var lines : Array[String] = []
	for ln in raw.split("\n", false):
		var t : String = ln.strip_edges()
		if t != "":
			lines.append(t)
	return " ".join(lines)

# Zato: what Eddie does for him depends on whether Eddie is on the board.
func _zato_bonus_line(pid, exceeded : bool) -> String:
	var eddie_in_play := false
	var pl = game.game_wrapper._get_player(pid)
	if pl != null and pl.has_method("is_buddy_in_play") and not pl.buddy_id_to_index.is_empty():
		eddie_in_play = pl.is_buddy_in_play()
	if eddie_in_play:
		return "Specials and Ultras have \"HIT: Gain Advantage\" and come from Eddie"
	if exceeded:
		return "Normal attacks have \"AFTER: You may place Eddie in any space\""
	return "Normal attacks have \"AFTER: You may place Eddie in this attacks range\""

func _update_permanent_bonus() -> void:
	if game.observer_mode or game.game_wrapper == null or game.game_wrapper.current_game == null:
		return
	for side in range(2):
		_update_permanent_bonus_side(side)

func _update_permanent_bonus_side(side : int) -> void:
	var pid := Enums.PlayerId.PlayerId_Player if side == 0 else Enums.PlayerId.PlayerId_Opponent
	var line := _permanent_bonus_line(side)
	var panel = game.player_bonus_panel if side == 0 else game.opponent_bonus_panel
	var label = game.player_bonus_label if side == 0 else game.opponent_bonus_label
	if line == "":
		if _perm_lines[side] != "":
			# The always-shown line no longer applies (e.g. Happy Chaos while exceeded, or
			# Giovanna's turn is over): take it out of the box, keeping any other bonuses there.
			var old : String = _perm_lines[side]
			_perm_lines[side] = ""
			if panel.visible:
				var keep : Array[String] = []
				var raw : String = label.get_parsed_text()
				raw = raw.replace(" \n    ", " ").replace("\n    ", " ")
				for ln in raw.split("\n", false):
					var t := ln.strip_edges()
					if t.begins_with("*"):
						t = t.substr(1).strip_edges()
					if t != "" and t != old:
						keep.append(t)
				panel.visible = false
				for t in keep:
					game._add_bonus_label_text(pid, t, true)
		return
	var keep_lines : Array[String] = []
	if line != _perm_lines[side]:
		# Rebuilt below with the new text (e.g. after exceeding, or Zato's Eddie coming into or
		# leaving play), keeping any strike bonuses already listed under it.
		var old_line : String = _perm_lines[side]
		_perm_lines[side] = line
		if panel.visible:
			var raw : String = label.get_parsed_text()
			raw = raw.replace(" \n    ", " ").replace("\n    ", " ")
			for ln in raw.split("\n", false):
				var t := ln.strip_edges()
				if t.begins_with("*"):
					t = t.substr(1).strip_edges()
				if t != "" and t != old_line and t != line:
					keep_lines.append(t)
		panel.visible = false
	if not panel.visible:
		# The game hides the box between strikes and turns: bring it straight back with the
		# ability on its first line (the game adds strike bonuses below it).
		game._add_bonus_label_text(pid, line, true)
		for t in keep_lines:
			game._add_bonus_label_text(pid, t, true)

# Same, for either side (0 = player, 1 = opponent). The always-shown ability line (see
# PERMANENT_BONUS_CHARACTERS) is only included when `include_permanent` is set.
func _bonus_effect_text_for(side : int, include_permanent : bool = false) -> String:
	if side == 0:
		var pend := _pending_bonus_text()
		if pend != "":
			return pend
	var panel = game.player_bonus_panel if side == 0 else game.opponent_bonus_panel
	var label = game.player_bonus_label if side == 0 else game.opponent_bonus_label
	if panel == null or not panel.visible:
		return ""
	var raw : String = label.get_parsed_text()
	raw = raw.replace(" \n    ", " ").replace("\n    ", " ")
	var parts : Array[String] = []
	for line in raw.split("\n", false):
		var t := line.strip_edges()
		if t.begins_with("*"):
			t = t.substr(1).strip_edges()
		# The always-shown ability line isn't a bonus for this strike.
		# (A strike bonus the always-shown line already describes isn't listed twice, nor is a
		# leftover always-shown line from the character's other side.)
		if _perm_lines[side] != "" and t != _perm_lines[side] and _covered_by_permanent(side, t):
			continue
		# (nor is your "When you Exceed" reminder, though it is shown in the box itself)
		if side == 0 and not include_permanent and _exceed_note_shown != "" and t == _exceed_note_shown:
			continue
		if t != "" and (include_permanent or t != _perm_lines[side]):
			parts.append(t)
	return "; ".join(parts)

# Characters whose set-strike effect depends on having used their character action (the
# strike comes from it): the effect is listed in the bonus effect box from the moment the
# strike is being chosen, like Sol's. Add a character's deck id to do the same for another.
const ACTION_PREVIEW_CHARACTERS := ["ino"]
# Characters whose action bonus only shows once the action itself is confirmed (its cost paid),
# not from the moment the action box is tapped.
const ACTION_PREVIEW_AFTER_CONFIRM := ["ino"]
# The bonus box wording for a character's action bonus, when it differs from the game's.
const ACTION_PREVIEW_TEXT := {
	"ino": "+1 Power",
}
var _perm_tag_re : RegEx

# True when an "used_character_action" effect of this player applies right now.
func _action_effect_applies(p, e) -> bool:
	# Tapping the action box already starts choosing the strike card; the game only counts
	# the action as used once that card is confirmed.
	if game.preparing_character_action and not str(p.deck_def.get("id", "")) in ACTION_PREVIEW_AFTER_CONFIRM:
		return true
	var cg = game.game_wrapper.current_game
	var lg = cg if cg is LocalGame else cg.get("local_game")
	return lg != null and lg.is_effect_condition_met(p, e, LocalStrikeConditions.new())

# The rules text of one effect, plain, on one line.
func _effect_line(e) -> String:
	if _perm_tag_re == null:
		_perm_tag_re = RegEx.new()
		_perm_tag_re.compile("\\[[^\\]]*\\]")
	var raw : String = _perm_tag_re.sub(str(GameStrings.get_effect_text(e, false, true, true, "", true)), "", true)
	var lines : Array[String] = []
	for ln in raw.split("\n", false):
		var t : String = ln.strip_edges()
		if t != "":
			lines.append(t)
	return "; ".join(lines)

func _update_island() -> void:
	if island_root == null:
		return
	_track_pending_action()
	var info := _island_info()
	var red_on : bool = not info.is_empty() and (info["cancel"] >= 0 or info.get("topdeck_pass", false))
	var green_on : bool = not info.is_empty() and info["ok"] >= 0 and not info["ok_disabled"]
	# A mandatory prompt (e.g. discarding down to the hand size) has an OK that is not
	# yet available and no cancel: the island still shows, with a dimmed O, so the
	# player sees what is being asked.
	var waiting : bool = not info.is_empty() and not red_on and not green_on
	var want : bool = red_on or green_on or waiting
	island_green.disabled = waiting
	island_green.modulate = Color(0.5, 0.5, 0.5, 1.0) if waiting else Color.WHITE
	_update_choice_buttons()
	_update_dash_button(waiting and not _move_choice_map().is_empty())
	if want:
		var tag_re := RegEx.new()
		tag_re.compile("\\[[^\\]]*\\]")
		var title : String = tag_re.sub(game.action_menu.instructions_label.text, "", true).strip_edges()
		# The island does its own wrapping: the prompt's own line breaks would stack on top of it
		# (e.g. "0" alone on a line above "force generated").
		title = title.replace("\n", " ")
		title = _with_action_name(title)
		if _topdeck_picking():
			title = _topdeck_title()
		var gauge_pass := _gauge_pass_info()
		if not gauge_pass.is_empty():
			title = gauge_pass["title"]
		var move_map := _move_choice_map()
		if not move_map.is_empty():
			title = "Tap a highlighted space to move there"
			# Pushes / pulls (Area Shift, Grasp...) move the opponent: say who.
			if move_map.get("moves_opponent", false):
				var opp_name : String = str(game.opponent_name_label.text).strip_edges()
				if opp_name != "":
					title = "Tap a highlighted space to move %s" % opp_name
		if not _reveal_pick_info().is_empty():
			title = "Select the revealed card to discard it, or X to pass"
		if _is_cost_wild():
			title += " (X: Wild Swing instead)"
		if _is_strike_pick():
			if _ws_pending_live():
				title = "Strike with a Wild Swing? (Tap the deck again to cancel)"
			elif game.ui_sub_state == game.UISubState.UISubState_SelectCards_StrikeCard:
				title = "Strike: Select a card, two copies to EX, or tap the deck to Wild Swing"
			else:
				title += " (Tap the deck to Wild Swing)"
			var bonus := _bonus_effect_text()
			if bonus != "":
				title += " [Bonus Effect active: %s]" % bonus
		# A card is picked for a boost: word the prompt like the "select a card, then tap
		# the red area" confirmation.
		if green_on and game.ui_state == game.UIState.UIState_SelectCards \
				and game.ui_sub_state == game.UISubState.UISubState_SelectCards_PlayBoost:
			title = "Are you sure you want to Boost?"
			var sel : Array = game.selected_cards
			if sel.size() == 1 and sel[0] != null:
				var lc = game.game_wrapper.get_card_database().get_card(sel[0].card_id)
				if lc != null:
					var bname := str(lc.definition["boost"]["display_name"])
					if bname != "":
						title += " (%s)" % bname
		# Island not laid out yet (width ~0): wrapping now would stack the text into a
		# tall narrow column. Wait for a real width.
		if title != _island_title and island_rect.size.x - 28.0 >= 120.0:
			_island_title = title
			# Manual wrapping (no autowrap: it can measure at width 0 and grow huge).
			island_tab_label.autowrap_mode = TextServer.AUTOWRAP_OFF
			island_tab_label.clip_text = false
			island_tab_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			var avail : float = island_rect.size.x - 28.0
			var tfont : Font = island_tab_label.get_theme_font("font")
			var tfs := 22
			while tfs > 15 and tfont.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x + 4.0 > avail:
				tfs -= 1
			# Greedy word wrap into at most 2 lines at this size.
			var lines : Array[String] = []
			var cur := ""
			for word in title.split(" ", false):
				var trial : String = word if cur == "" else cur + " " + word
				if cur != "" and tfont.get_string_size(trial, HORIZONTAL_ALIGNMENT_LEFT, -1, tfs).x + 4.0 > avail and lines.size() < (2 if title.contains("[Bonus Effect active") else 1):
					lines.append(cur)
					cur = word
				else:
					cur = trial
			lines.append(cur)
			var wrapped := "\n".join(lines)
			island_tab_label.text = wrapped
			island_tab_label.add_theme_font_size_override("font_size", tfs)
			island_tab_label.custom_minimum_size = Vector2.ZERO
			island_tab.custom_minimum_size = Vector2.ZERO
			island_tab.reset_size()
			_apply_island.call_deferred()
		var split_t := 0.5
		if red_on and not green_on:
			split_t = 1.0
		elif (green_on or waiting) and not red_on:
			split_t = 0.0
		if not is_equal_approx(split_t, _island_split_target):
			var first := _island_split_target < 0.0 or not _island_want
			_island_split_target = split_t
			if _island_split_tween != null and _island_split_tween.is_valid():
				_island_split_tween.kill()
			if first:
				_island_split = split_t
				_apply_island()
			else:
				_island_split_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
				_island_split_tween.tween_method(func(v : float): _island_split = v; _apply_island(), _island_split, split_t, 0.25)
	_update_confirm_banner(want)
	if want != _island_want:
		_island_want = want
		if want and _island_sparkle != null:
			_island_sparkle.burst() # draw the eye to the buttons as the island appears
		if _island_vis_tween != null and _island_vis_tween.is_valid():
			_island_vis_tween.kill()
		_island_vis_tween = create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		_island_vis_tween.tween_method(func(v : float): _island_vis = v; _apply_island(), _island_vis, 1.0 if want else 0.0, 0.25)
		if not want:
			_island_split_target = -1.0

func _island_press(confirm : bool) -> void:
	var info := _island_info()
	if info.is_empty():
		return
	if info.get("topdeck_pass", false) and not confirm:
		game._on_instructions_cancel_button_pressed()
		return
	if info.get("ws_pending", false):
		_ws_pending = false
		if not confirm:
			game._update_buttons() # (X: the wild swing is let go; still choosing)
			return
	if _topdeck_picking():
		if _choice_count() > 0:
			_choice_press(1 if confirm else 0) # the selected card's first two options
		elif confirm and int(info["ok"]) >= 0:
			game._on_instructions_ok_button_pressed(int(info["ok"]))
		return
	var idx : int = info["ok"] if confirm else info["cancel"]
	if idx >= 0:
		game.action_menu._on_choice_pressed(idx)

# Phone controls: the action menu starts minimized (just the eye icon + prompt)
# whenever it is a plain "choose an action" list or an OK / Cancel prompt; real
# decisions (effect choices etc.) keep it expanded so nothing is hidden.
func _update_menu_minimize() -> void:
	var g = game
	var am : ActionMenu = g.action_menu
	if not g.action_menu_container.visible:
		_menu_sig = ""
		return
	var texts : Array = []
	for c in g.current_action_menu_choices:
		texts.append(str(c.get("text", "")))
	var sig : String = am.instructions_label.text + "|" + "|".join(texts) + "|" + str(g.ui_state)
	if sig == _menu_sig:
		return
	_menu_sig = sig
	var minimize : bool = g.ui_state == g.UIState.UIState_PickTurnAction
	if not minimize:
		minimize = true
		for t in texts:
			var is_mulligan_pass : bool = t == "Pass" and ("OK" in texts or g.ui_sub_state == g.UISubState.UISubState_SelectCards_Mulligan or g.ui_state == g.UIState.UIState_SelectArenaLocation)
			var is_wild : bool = t == "Wild Swing" and (_is_strike_pick() or _is_cost_wild())
			if not (t == "OK" or t == "Confirm" or t.begins_with("Cancel") or is_mulligan_pass or is_wild):
				minimize = false
		if am.number_panel.visible:
			minimize = false
		if _choice_count() > 0 or not _move_choice_map().is_empty() or not _reveal_pick_info().is_empty() \
				or _topdeck_picking() or not _gauge_pass_info().is_empty():
			minimize = true # effect options live in the island / on the arena instead
	if minimize == am.showing:
		am._on_show_hide_button_pressed()

# The hand icon in white with dark outlines (around the hand and between the fingers), so it
# reads as a hand, not a flat silhouette. The stock icon is pale gold with darker gold
# outlines: map its brightness from outline (dark) to fill (white).
func _hand_glyph_texture() -> Texture2D:
	var img : Image = (load("res://assets/icons/hand.png") as Texture2D).get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var outline := Color(0.08, 0.08, 0.14)
	var w := img.get_width()
	var h := img.get_height()
	# Brightness 0 (outline) .. 1 (fill) for every visible pixel.
	var tv := PackedFloat32Array()
	tv.resize(w * h)
	for py in h:
		for px in w:
			var c := img.get_pixel(px, py)
			var lum := 0.299 * c.r + 0.587 * c.g + 0.114 * c.b
			tv[py * w + px] = clampf((lum - 0.66) / (0.88 - 0.66), 0.0, 1.0) if c.a > 0.0 else 1.0
	# The finger lines are a single pixel wide; widen them sideways so they stay visible when
	# the icon is drawn small.
	var out := tv.duplicate()
	for py in h:
		for px in range(1, w - 1):
			if img.get_pixel(px, py).a > 0.5:
				out[py * w + px] = minf(tv[py * w + px], minf(tv[py * w + px - 1], tv[py * w + px + 1]))
	for py in h:
		for px in w:
			var c := img.get_pixel(px, py)
			if c.a <= 0.0:
				continue
			var o := outline.lerp(Color.WHITE, out[py * w + px])
			img.set_pixel(px, py, Color(o.r, o.g, o.b, c.a))
	return ImageTexture.create_from_image(img)

func _white_texture(tex : Texture2D) -> Texture2D:
	var img : Image = tex.get_image()
	if img.is_compressed():
		img.decompress()
	for py in img.get_height():
		for px in img.get_width():
			img.set_pixel(px, py, Color(1, 1, 1, img.get_pixel(px, py).a))
	return ImageTexture.create_from_image(img)

func _opp_icon_pos(i : int) -> Vector2:
	var slot := _bottom_slot_size()
	if i == 0:
		return Vector2(8.0, opp_bar_y + 10.0) # sealed: left edge, mirroring the player's
	return Vector2(W - 8.0 - slot.x - (2 - i) * (slot.x + 8.0), opp_bar_y + 10.0)

# Center of the opponent's hand, between their sealed and deck icons.
func _opp_hand_center() -> Vector2:
	var slot := _bottom_slot_size()
	var left := _opp_icon_pos(0).x + slot.x
	var right := _opp_hand_right_x()
	return Vector2((left + right) / 2.0, _opp_icon_pos(0).y + slot.y / 2.0)

# The right edge of the opponent's hand area: their hand icon, or their asterisk (extra cards)
# icon when it is shown (it sits just left of the hand icon).
func _opp_hand_right_x() -> float:
	var star = star_buttons[1] if star_buttons.size() > 1 else null
	if star != null and is_instance_valid(star) and star.visible:
		return star.position.x
	return _opp_hand_icon_pos().x

# The range (min x, max x) the opponent's hand card *centres* may use: between their sealed icon
# and their hand icon (or asterisk icon), leaving room for half a card at each end.
func opp_hand_span() -> Vector2:
	var slot := _bottom_slot_size()
	var half_card : float = CardBase.get_opponent_hand_card_size().x / 2.0
	var left := _opp_icon_pos(0).x + slot.x + 6.0 + half_card
	var right := _opp_hand_right_x() - 6.0 - half_card
	if right < left:
		var mid := (left + right) / 2.0
		return Vector2(mid, mid)
	return Vector2(left, right)

# The opponent's hand icon: just left of their deck (yours sits left of your deck, too).
func _opp_hand_icon_pos() -> Vector2:
	var slot := _bottom_slot_size()
	return Vector2(_opp_icon_pos(1).x - 8.0 - slot.x, _opp_icon_pos(1).y)

func _layout_hand_pile(side : int, pos : Vector2, slot : Vector2) -> void:
	if hand_pile_rects[side] == null:
		return
	_set_rect(hand_pile_rects[side], Rect2(pos, slot))
	var gs := slot.x * 0.62
	_set_rect(hand_pile_glyphs[side], Rect2(pos + Vector2((slot.x - gs) / 2.0, slot.y * 0.16), Vector2(gs, gs)))
	var l : Label = hand_pile_labels[side]
	l.position = pos + Vector2(0, slot.y - 30)
	l.size = Vector2(slot.x, 28)

# Boost boxes sit on the bottom edge of their area and grow upward with their text;
# the asterisk / overdrive buttons and bonus panels ride on top of them.
var _boost_shown_h : Array = [-1.0, -1.0]

# The boost zone (a Node2D) only shows its children inside the given size, from its top-left:
# it draws that rect as a mask (CLIP_CHILDREN_ONLY: the mask itself isn't shown).
func _clip_boost_zone(zone : Node2D, size : Vector2) -> void:
	if not zone.has_meta("phone_clip"):
		zone.clip_children = CanvasItem.CLIP_CHILDREN_ONLY
		zone.draw.connect(func():
			var sz : Vector2 = zone.get_meta("phone_clip")
			zone.draw_rect(Rect2(Vector2.ZERO, sz), Color.WHITE))
	if zone.get_meta("phone_clip", Vector2.ZERO) != size:
		zone.set_meta("phone_clip", size)
		zone.queue_redraw()

func _update_boost_layout() -> void:
	if not _built:
		return
	var zone_w := W / 2.0 - 8.0
	# Both boost boxes sit above an icon-row's worth of space (the opponent's icons; the same
	# height on the player's side, which keeps the opponent's hand from covering it).
	# (The bottom edge touches the top of the metallic border of the opponent bar below:
	# that bar starts 10 px above the icon row.)
	var bottoms := [gauge_y - 4.0, gauge_y - 4.0] # (just above the gauge strip)
	var xs := [4.0, W / 2.0 + 4.0]
	var names := ["PlayerBoostZone", "OpponentBoostZone"]
	var bonus := ["PlayerStrike/CharBonusPanel", "OpponentStrike/CharBonusPanel"]
	for i in range(2):
		var zone = game.get_node_or_null(names[i])
		if zone == null:
			continue
		var om : MarginContainer = zone.get_node("OuterMargin")
		var fx : RichTextLabel = zone.get_node("OuterMargin/BoostPanel/InnerMargin/BoostVBox/BoostEffects")
		fx.visible = fx.text.strip_edges() != ""
		var h := om.get_combined_minimum_size().y
		# The box slides smoothly up / down (out from behind the gauge strip) as its height
		# changes: the shown height eases toward the real one, and the zone clips its contents
		# to the shown part.
		var shown : float = _boost_shown_h[i]
		if shown < 0.0:
			shown = h
		else:
			shown += (h - shown) * minf(1.0, get_process_delta_time() * 14.0)
			if absf(h - shown) < 0.5:
				shown = h
		_boost_shown_h[i] = shown
		_clip_boost_zone(zone, Vector2(zone_w, shown))
		om.size = Vector2(zone_w, maxf(h, shown))
		zone.position = Vector2(xs[i], bottoms[i] - shown)
		var fire = zone.get_node_or_null("BoostFire")
		if fire != null:
			fire.position = om.position
			fire.size = Vector2(zone_w, maxf(h, shown))
			var holder = game.get_node_or_null("AllCards/PlayerBoosts" if i == 0 else "AllCards/OpponentBoosts")
			fire.set_level(holder.get_child_count() if holder != null else 0)
		var top : float = zone.position.y
		var od := overdrive_buttons[i]
		od.z_index = 12 # above the ice bonus box they overlap
		od.position.y = top - 40.0
		od.position.x = 6.0 if i == 0 else W - 6.0 - od.get_combined_minimum_size().x
		var bp = game.get_node_or_null(bonus[i])
		if bp != null:
			# The ice popup sits directly on top of its boost window: the player's at the
			# right end (the asterisk / overdrive buttons are at the left), the opponent's
			# at the left end.
			var bt : Label = bp.get_node_or_null("MarginContainer/VBox/BonusText")
			if bt != null:
				var txt := _bonus_effect_text_for(i, true)
				if bt.text != txt:
					bt.text = txt
				# Every line is the same height (BONUS_LINE_H), whatever the font size: the text
				# starts at BONUS_FONT_MAX and shrinks until it fits on one line, else on two. Only
				# once it is down to BONUS_FONT_MIN does the box grow to three or more lines.
				var avail : float = W / 2.0 - 8.0 - 16.0
				var bfont : Font = bt.get_theme_font("font")
				if str(bt.get_meta("fit_txt", "\u0001")) != txt: # (only when the text changes)
					bt.set_meta("fit_txt", txt)
					var fs := BONUS_FONT_MAX
					# One line, if a font size down to the minimum makes it fit...
					while fs > BONUS_FONT_MIN and bfont.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > avail - 6.0:
						fs -= 1
					var one_line : bool = bfont.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x <= avail - 6.0
					if not one_line:
						# ...else the largest size that wraps to two lines.
						fs = BONUS_FONT_MAX
						var ms : Vector2 = bfont.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, avail - 6.0, fs)
						while fs > BONUS_FONT_MIN and ms.y > bfont.get_height(fs) * 2.0 + 1.0:
							fs -= 1
							ms = bfont.get_multiline_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, avail - 6.0, fs)
					bt.add_theme_font_size_override("font_size", fs)
					# (the gap between lines makes up the difference to the fixed line height)
					bt.add_theme_constant_override("line_spacing", int(BONUS_LINE_H - bfont.get_height(fs)))
					bt.autowrap_mode = TextServer.AUTOWRAP_OFF if one_line else TextServer.AUTOWRAP_WORD_SMART
				bt.size = Vector2(avail, 0.0)
				# The box is exactly as tall as the lines the label really wraps to (each
				# BONUS_LINE_H): the label's own minimum height isn't used (on the phone it came out
				# a line too tall), its height is worked out here from its lines instead.
				bt.clip_text = true
				bt.max_lines_visible = -1
				var real_lines : int = maxi(1, bt.get_line_count())
				var text_h : float = real_lines * BONUS_LINE_H + 2.0
				var want_min := Vector2(avail, ceilf(text_h))
				if bt.custom_minimum_size != want_min:
					bt.custom_minimum_size = want_min
			bp.size = Vector2(bp.size.x, 0.0)
			bp.size = bp.get_combined_minimum_size()

			# Same size and place as the boost window's collapsed box, right on top of it
			# (the asterisk / overdrive buttons overlap it).
			bp.position = Vector2(xs[i], top - bp.size.y - 2.0)
		if USE_STAT_GEMS:
			var above : float = top
			if bp != null and bp.visible:
				above = bp.position.y
			var gems_top := _place_stat_gems(i, xs[i], above - 3.0, zone_w)
			if gems_top < above - 3.0:
				od.position.y = gems_top - 40.0 # (the overdrive button rides above the gems)

const BONUS_FONT_MAX := 21
const BONUS_FONT_MIN := 14 # below this, text in the bonus box gets hard to read on a phone
const BONUS_LINE_H := 28.0 # every line of the bonus box is this tall, whatever its font size

func _place_action_menu() -> void:
	var amc : Control = game.action_menu_container
	var s := 0.72
	if GlobalSettings.phone_controls_active():
		# Phone controls: the (minimized by default) menu hangs under the hamburger icon.
		var am : ActionMenu = game.action_menu
		# The eye (show/hide) button is hidden in phone controls; the menu minimizes itself.
		var eye_box := am.get_node_or_null("OuterMargin/MainVBox/PanelContainer/ShowHideHBox") as Control
		if eye_box != null:
			eye_box.visible = false
		# Minimized "choose an action" is just the eye icon, no text.
		var icon_only : bool = not am.showing
		# Minimized, the menu is just an empty panel: make it invisible and untouchable.
		amc.modulate.a = 0.0 if icon_only else 1.0
		am.mouse_filter = Control.MOUSE_FILTER_IGNORE if icon_only else Control.MOUSE_FILTER_STOP
		am.instructions_label.visible = not icon_only
		# Twice the normal popup scale, so the options are easy to tap (it rarely shows).
		s = 1.44
		amc.scale = Vector2(s, s)
		var mw := W - 24.0
		if icon_only:
			amc.size.x = 0.0 # shrinks to the minimum size (the eye button)
			mw = amc.get_combined_minimum_size().x * s
		else:
			amc.size.x = mw / s
		amc.position.x = (W - mw) / 2.0
		var mh := amc.get_combined_minimum_size().y * s
		amc.size.y = mh / s
		amc.position.y = top_h + 32.0 + 4.0
		return
	# Without phone controls the popup is centered across the screen and sits on the top edge
	# of your bar at the bottom, 25% larger than its old size (0.72).
	s = 0.72 * 1.25
	amc.scale = Vector2(s, s)
	var w := W - 24.0
	amc.size.x = w / s
	amc.position.x = (W - w) / 2.0
	var h := amc.get_combined_minimum_size().y * s
	amc.size.y = h / s
	amc.position.y = bottom_y - h

# A copy of the top discard's card-type icon (the one the gauge boxes use) sits on each
# discard pile so the top card reads at a glance. It ignores the mouse, so tapping the pile
# still works.
var _discard_icons : Array = [null, null]
var _discard_icons_ready : Array = [false, false]

# ---- Cards going to an area stop at the screen center first --------------------------------------
# A card on its way to an area (gauge, discard pile, boosts, sealed, overdrive...) first flies
# quickly to focus size, centered under the action banners (an action's banner, e.g. BOOST, stays
# up until it gets there), pauses a moment, then flies on to the area.
# Not for cards going into a strike, back to the deck (reshuffles) or the hand, nor for the strike
# cards leaving with the plates or a boost dropping into the gauge (those have their own moves).
# Set USE_CENTER_STOP_FLIGHTS to false to go back to direct flights.
const USE_CENTER_STOP_FLIGHTS := true
# Mulliganed cards stop at the center too (off: they fly straight back to the deck; the MULLIGAN banner still shows).
const USE_MULLIGAN_FOCUS := false
const CENTER_STOP_HOLD := 0.45  # at the center (the action banner fades away meanwhile)
const CENTER_STOP_TIME := 0.15  # the quick flight to the center
const CENTER_STOP_Z := 31       # over the board and the reference windows (z 30); under card
								# previews (z 40). (It sits below the action banners, so they don't overlap.)
var _center_cards : Array = []  # cards on their way to (or waiting at) the center

# Both players' cards go one at a time (the same for both, e.g. in online play): each waits its
# turn where it is (out of sight), then
# flies to the center, pauses, and flies on to its area; the next one starts as the previous one
# leaves the center. They wait for the action's banner (a Move's payment comes just before its
# banner) for at most CENTER_QUEUE_GATE seconds. The action banner stays up until the last card
# has left the center. Every card at the center glows in its player's color.
const CENTER_QUEUE_GATE := 0.6
var _center_queue : Array = []   # {card, pos, state, scale, player}
var _center_current = null       # the queued card now on its way to / at the center
var _center_queue_since : float = -1.0
var action_banner_up : bool = false # (set by StrikeStage while an action banner shows)
var payment_banner_up : bool = false # (StrikeStage: a confirmed PAY banner waits for its cards)

# True while an action banner should stay up for cards: one still flying to the center, or
# still queued or at the center.
func center_cards_arriving() -> bool:
	var keep := []
	var arriving := false
	for c in _center_cards:
		if is_instance_valid(c) and c.has_meta("phone_center_hold"):
			keep.append(c)
			if c.state == CardBase.CardState.CardState_Discarding and c.animation_time < 1.0:
				arriving = true
	_center_cards = keep
	if _center_current != null and not is_instance_valid(_center_current):
		_center_current = null
	if _cards_drawing():
		_banner_got_cards = true # (a Prepare's draw is its cards)
		return true
	if not _banner_got_cards and _now_s() < _banner_expect_until:
		return true # (an action whose cards haven't started yet)
	return arriving or not _center_queue.is_empty() or _center_current != null

# Game._process: during a strike, hold the next events back while cards are still queued for, on
# their way to, or paused at the screen center, so the next thing (e.g. the opponent paying force
# for an effect) doesn't start before the card in focus has gone on. Capped, so a stuck card can
# never stall the game.
const EVENT_HOLD_MAX := 4.0 # seconds (real time)
var _event_hold_elapsed : float = 0.0
var _change_hold_armed_at : float = -1.0
var _change_hold_seen_cards : bool = false
const CHANGE_HOLD_TTL := 8.0

func should_hold_events(delta : float) -> bool:
	var flights := _center_flight_busy()
	var busy : bool = strike_stage != null and strike_stage._active and flights
	# Changing cards (either player's): what follows waits for the last changed card to finish its
	# stop at the center. (Armed by the ChangeCards event; its cards may only start a moment later,
	# so it stays armed until they have been and gone.)
	if _change_hold_armed_at >= 0.0:
		if _now_s() - _change_hold_armed_at > CHANGE_HOLD_TTL:
			_change_hold_armed_at = -1.0
		elif flights:
			_change_hold_seen_cards = true
			busy = true
		elif _change_hold_seen_cards:
			_change_hold_armed_at = -1.0 # (its cards have all been through)
	if not busy:
		_event_hold_elapsed = 0.0
		return false
	_event_hold_elapsed += delta
	return _event_hold_elapsed < EVENT_HOLD_MAX

func _center_flight_busy() -> bool:
	if _center_current != null and is_instance_valid(_center_current):
		return true
	for e in _center_queue:
		var c = e["card"]
		if is_instance_valid(c) and c.has_meta("phone_center_wait") \
				and c.state == CardBase.CardState.CardState_Discarding:
			return true
	for c in _center_cards:
		if is_instance_valid(c) and c.has_meta("phone_center_hold") \
				and c.state == CardBase.CardState.CardState_Discarding:
			return true
	return false

# Starts the next queued card once the one before has left the center (called every frame).
func _pump_center_queue() -> void:
	if _center_current != null and is_instance_valid(_center_current):
		return
	_center_current = null
	while not _center_queue.is_empty():
		var now := _now_s()
		if _center_queue_since < 0.0:
			_center_queue_since = now
		if not action_banner_up and not payment_banner_up and now - _center_queue_since < CENTER_QUEUE_GATE:
			return # (waiting for the action's banner)
		var e : Dictionary = _center_queue.pop_front()
		var card = e["card"]
		# (skipped if it has been sent somewhere else meanwhile)
		if not is_instance_valid(card) or not card.has_meta("phone_center_wait") \
				or card.state != CardBase.CardState.CardState_Discarding:
			continue
		card.remove_meta("phone_center_wait")
		card.card_features.visible = true
		if card.has_meta("phone_show_front"):
			card.flip_card_to_front(true) # (your own mulliganed card: shown face up)
		_center_current = card
		_start_center_flight(card, e["pos"], e["state"], e["scale"], e["player"], e.get("then", Callable()))
		return
	_center_queue_since = -1.0

# The action banner's hold-back for an event: for actions whose cards then fly through the
# center (a boost, changing cards, exceeding, a character action), the next events come as soon
# as the banner is up (it waits for the cards); everything else waits for the whole banner.
func _banner_delay(et, full : float) -> float:
	var E = Enums.EventType
	if USE_CENTER_STOP_FLIGHTS and et in [E.EventType_Boost_Played, E.EventType_Transform_Added,
			E.EventType_ChangeCards, E.EventType_Exceed, E.EventType_CharacterAction, E.EventType_Prepare]:
		# (its cards follow: the banner waits a moment for the first one, and for any draws)
		_banner_expect_until = _now_s() + BANNER_EXPECT_WAIT
		_banner_got_cards = false
		return minf(full, strike_stage.BANNER_IN)
	return full

const BANNER_EXPECT_WAIT := 1.5

# Something (a payment banner) waits for cards that will start toward the center shortly.
func expect_center_cards(secs : float) -> void:
	_banner_expect_until = _now_s() + secs
	_banner_got_cards = false
var _banner_expect_until : float = -1.0
var _banner_got_cards : bool = false

# Cards still being drawn (into either hand).
func _cards_drawing() -> bool:
	for zone in [game.get_hand_zone(true), game.get_hand_zone(false)]:
		for c in zone.get_children():
			if c is CardBase and c.state == CardBase.CardState.CardState_DrawingToHand:
				return true
	return false

# `final_scale`: when set, the size the card ends at (for flights whose end size isn't the one
# discard_to gives its target state, like a boost shrinking into its boost box).
# `is_player`: whose card (its glow color). Every card queues up (one at a time).
# `then_cb`: called instead of the flight on to the area, once the card leaves the center (a card
# going on into a hand: see fly_from_sealed_to_hand).
func _fly_via_center(card, target_state, final_scale = null, is_player : bool = true, then_cb : Callable = Callable()) -> void:
	var real_pos : Vector2 = card.target_pos
	_banner_got_cards = true
	# Wait in place, out of sight, for its turn.
	card.target_pos = card.card_features.position
	card.target_scale = card.card_features.scale
	card.return_state = CardBase.CardState.CardState_Discarding
	card.card_features.visible = false
	card.set_meta("phone_center_wait", true)
	card.set_meta("phone_center_hold", true) # (keeps its raised drawing order)
	_center_queue.append({"card": card, "pos": real_pos, "state": target_state,
			"scale": final_scale, "player": is_player, "then": then_cb})

# A card leaving a sealed area for a hand: it stops at the screen center (in focus) like a card
# going to an area, then shrinks to hand size and goes on into the hand (`then_cb` puts it there).
func fly_from_sealed_to_hand(card, is_player : bool, then_cb : Callable) -> void:
	if not USE_CENTER_STOP_FLIGHTS or card == null or not is_instance_valid(card):
		then_cb.call()
		return
	# (a flight to where it is, so it can wait its turn in the queue; no stop of its own)
	card.set_meta("phone_leg2", true)
	card.discard_to(card.card_features.position, CardBase.CardState.CardState_InGauge)
	card.remove_meta("phone_leg2")
	_fly_via_center(card, CardBase.CardState.CardState_InHand, null, is_player, func():
		if not is_instance_valid(card):
			return
		# Shrinks to its hand size at the center, then is drawn into the hand.
		card.start_pos = card.card_features.position
		card.target_pos = card.start_pos
		card.original_scale = card.card_features.scale
		card.target_scale = card.default_scale
		card.start_rotation = card.card_features.rotation_degrees
		card.animation_time = 0.0
		card.animation_length = 0.12
		get_tree().create_timer(_pt(0.14)).timeout.connect(func():
			if not is_instance_valid(card):
				return
			then_cb.call()
			# (back to its normal drawing order: it flies over the hand cards lying over it only)
			card.z_as_relative = true
			card.z_index = 0
			if card.state == CardBase.CardState.CardState_DrawingToHand:
				card._raise_hand_for_anim(true)))

func _start_center_flight(card, real_pos : Vector2, target_state, final_scale, is_player : bool, then_cb : Callable = Callable()) -> void:
	# To focus size (or as large as fits), centered in the space below the action banners.
	var banner_bottom : float = stage_y + (stage_h - band_h) / 2.0 + 95.0 # (banners are 190 tall)
	var room : float = H - banner_bottom - 16.0
	var fs : Vector2 = CardBase.phone_focus_scale
	if CARD_H * fs.y > room:
		fs = Vector2.ONE * (room / CARD_H)
	var center := Vector2(W / 2.0, banner_bottom + 8.0 + room / 2.0)
	card.start_pos = card.card_features.position
	card.original_scale = card.card_features.scale
	card.start_rotation = card.card_features.rotation_degrees
	card.animation_time = 0.0
	card.target_pos = center
	card.target_scale = fs
	card.animation_length = CENTER_STOP_TIME
	card.z_as_relative = false
	card.z_index = CENTER_STOP_Z
	card.return_state = CardBase.CardState.CardState_Discarding # (holds at the center)
	card.set_meta("phone_center_hold", true)
	_set_center_glow(card, true, is_player)
	if not card in _center_cards:
		_center_cards.append(card)
	var token : int = int(card.get_meta("phone_center_token", 0)) + 1
	card.set_meta("phone_center_token", token)
	get_tree().create_timer(_pt(card.animation_length + CENTER_STOP_HOLD)).timeout.connect(func():
		if not is_instance_valid(card) or int(card.get_meta("phone_center_token", 0)) != token:
			return
		card.remove_meta("phone_center_hold")
		_set_center_glow(card, false, is_player)
		if _center_current == card:
			_center_current = null # (the next queued card can go)
		if target_state == CardBase.CardState.CardState_InGauge:
			refresh_gauge() # (its gauge box grows in now that the focus pause is over)
		# (unless something else has sent it elsewhere meanwhile)
		if card.state != CardBase.CardState.CardState_Discarding or not card.target_pos.is_equal_approx(center):
			if card.state != CardBase.CardState.CardState_Discarding:
				card._end_zone_flight() # (it landed elsewhere while held raised)
			return
		if card.has_meta("phone_show_front"):
			card.remove_meta("phone_show_front")
			card.flip_card_to_front(false) # (face down again on its way into the deck)
		if then_cb.is_valid():
			then_cb.call() # (it goes on some other way, e.g. into a hand)
			return
		card.set_meta("phone_leg2", true)
		card.discard_to(real_pos, target_state)
		card.remove_meta("phone_leg2")
		if final_scale != null:
			card.target_scale = final_scale
			card.resting_scale = final_scale)

# A glow round a card in its player's color (red for you, blue for the opponent), using the card's
# own highlight panel.
func _set_center_glow(card, on : bool, is_player : bool) -> void:
	var bl = card.get_node_or_null("CardFocusFeatures/Backlight")
	if bl == null:
		return
	if on:
		var col : Color = GAUGE_COLORS[0 if is_player else 1]
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col, 0.85)
		sb.set_corner_radius_all(14)
		sb.shadow_color = Color(col, 0.7)
		sb.shadow_size = 18
		bl.add_theme_stylebox_override("panel", sb)
		bl.visible = true
	else:
		bl.remove_theme_stylebox_override("panel")
		bl.visible = false

# Grows a control in from its center (a new gauge box, a new top discard).
func _grow_in(c : Control) -> void:
	c.pivot_offset = c.size / 2.0
	c.scale = Vector2.ZERO
	var t := c.create_tween()
	t.tween_property(c, "scale", Vector2.ONE, 0.24).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

var _in_cleanup : bool = false # from a strike's end (the plate opening) until the turn ends
var _mulligan_done : Array = [false, false] # (a player's ReshuffleDeck_Mulligan event ends theirs)
var current_action_banner : String = "" # (set by StrikeStage.show_action_banner)

# Banners for actions whose discards are their own cost (no separate DISCARD banner for those).
# Actions whose cards are paid before their own event arrives (EXCEED: its gauge is spent first):
# when a card heads for the center and such an event is just ahead, its banner shows now (and not
# again when the event comes).
# (A character action's banner: also used for its pre-confirmation.)
const UNIQUE_ACTION_BANNER := "UNIQUE ACTION"

# `from_hand`: the card is paid from a hand (only a character action's cost is looked for then;
# EXCEED is paid with gauge). Returns true when it brought a banner up (or one already is).
func _banner_ahead(from_hand : bool = false) -> bool:
	if strike_stage == null:
		return false
	var E = Enums.EventType
	var n := 0
	for ev in game.events_ahead:
		n += 1
		if n > 8 or not ev is Dictionary:
			break
		var et = ev.get("event_type", -1)
		if et == E.EventType_AdvanceTurn:
			break
		var text := ""
		if et == E.EventType_Exceed and not from_hand:
			text = "EXCEED"
		elif et == E.EventType_CharacterAction:
			# A character action paid for with force / gauge: its own banner (not a payment one)
			# while its cost goes through the center.
			text = UNIQUE_ACTION_BANNER
		if text == "":
			continue
		if ev.get("phone_banner_done", false):
			return true
		ev["phone_banner_done"] = true
		var is_opp : bool = int(ev.get("event_player", -1)) == int(Enums.PlayerId.PlayerId_Opponent)
		if is_opp:
			# (it counts as their action: effects during it get no banner of their own)
			_opp_action_text = text
			_opp_action_shown_at = _now_s()
			_opp_action_clear_at = -1.0
		strike_stage.show_action_banner(text, 1 if is_opp else 0)
		_banner_delay(et, 0.0)
		_banner_got_cards = true
		return true
	return false

# The opponent has been asked to pay force (Game events: an attack's force cost, force for an
# effect, force to block) and their payment hasn't shown yet. (A pass sends no cards: the ask
# lapses after a while, or at their next decision.)
var _opp_force_asked_at : float = -1.0
var _opp_force_for_character : bool = false # (that force is for their character's ability)
const OPP_FORCE_ASK_TTL := 20.0

# A force-for-effect from a character's ability (its effect, or the one it pays for, is marked
# character_effect).
func _is_character_effect(effect) -> bool:
	if not effect is Dictionary:
		return false
	if bool(effect.get("character_effect", false)):
		return true
	for k in ["overall_effect", "per_force_effect"]:
		var sub = effect.get(k)
		if sub is Dictionary and bool(sub.get("character_effect", false)):
			return true
	return false

func _opp_force_pending() -> bool:
	return _opp_force_asked_at >= 0.0 and _now_s() - _opp_force_asked_at < OPP_FORCE_ASK_TTL

func _track_opp_force_ask(event) -> void:
	var E = Enums.EventType
	var et = event["event_type"]
	if et == E.EventType_AdvanceTurn:
		_opp_force_asked_at = -1.0
		return
	if int(event.get("event_player", -1)) != int(Enums.PlayerId.PlayerId_Opponent):
		return
	if et in [E.EventType_Strike_PayCost_Force, E.EventType_ForceForEffect, E.EventType_Strike_ForceForArmor]:
		var di = game.game_wrapper.get_decision_info()
		# (force to block paid with gauge instead: not force)
		if et == E.EventType_Strike_ForceForArmor and di != null and str(di.limitation) == "gauge":
			_opp_force_asked_at = -1.0
		else:
			_opp_force_asked_at = _now_s()
			# Force for their character's own ability (May: 1 force for +1 Power when she
			# strikes): it shows as their UNIQUE ACTION, not a payment.
			_opp_force_for_character = et == E.EventType_ForceForEffect and di != null \
					and _is_character_effect(di.effect)
	elif et in [E.EventType_Strike_PayCost_Gauge, E.EventType_GaugeForEffect, E.EventType_Strike_EffectChoice,
			E.EventType_Strike_ChooseToDiscard]:
		_opp_force_asked_at = -1.0 # (a different decision of theirs)

# Game._on_hand_size_exceeded: a player has to discard down to their hand size; the cards they
# discard (soon after, or once you've chosen them) come under a HAND LIMIT banner.
const HAND_LIMIT_BANNER := "HAND LIMIT"
const HAND_LIMIT_TTL := 120.0 # (seconds: you may take a while to choose)
var _hand_limit_at : Array = [-1.0, -1.0]

func hand_limit_started(is_player : bool) -> void:
	_hand_limit_at[0 if is_player else 1] = _now_s()

func _banner_covers_discards(text : String) -> bool:
	for pre in ["CHANGE CARDS", "DISCARD", "PAY FORCE", "MOVE", "ADVANCE", "RETREAT", "EXCEED", UNIQUE_ACTION_BANNER, HAND_LIMIT_BANNER]:
		if text.begins_with(pre):
			return true
	return false

# Game._on_add_to_sealed: an effect has sealed a card (it is on its way through the center): a
# SEAL banner in the sealing player's color, once for the cards sealed together. Not for a strike
# card sealed as the strike ends (it leaves with the plate), nor when the sealing pays for an
# action whose own banner is up (a payment, a character action).
const SEAL_BANNER := "SEAL"

func on_card_sealed(card, from_zone, is_player : bool) -> void:
	if strike_stage == null or card == null or not is_instance_valid(card):
		return
	if from_zone == game.get_node_or_null("AllCards/Striking") \
			or int(card.get_meta("phone_prev_state", -1)) == int(CardBase.CardState.CardState_InStrike):
		return
	if action_banner_up and (current_action_banner == SEAL_BANNER or current_action_banner.begins_with("PAY")
			or current_action_banner == UNIQUE_ACTION_BANNER):
		return
	strike_stage.show_action_banner(SEAL_BANNER, 0 if is_player else 1)

# A choice of cards to seal (an effect's "seal X cards", Outrun the Past, a transform to seal):
# its pre-confirmation banner is SEAL.
func _is_seal_choice() -> bool:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_SelectCards:
		return false
	var di = g.game_wrapper.get_decision_info()
	if di != null and (str(di.destination) == "sealed" or str(di.source) == "outrun_seal"):
		return true
	return g.is_tournelouse_transform_bonus_choice()

# StrikeStage.end_strike: the strike is over, its cleanup follows.
func strike_cleanup_started() -> void:
	_in_cleanup = true

# CardBase.discard_to, once a card's flight to a zone is set up (still in the zone it leaves).
# (Also: boosts cleared at the end of a strike leave like its strike cards.)
#  * a boost going to the gauge doesn't fly there (its gauge box grows in instead);
#  * a strike card going to the gauge / discard pile (or sealed / overdrive...) at the end of the strike leaves the screen
#    sideways with its half of the metal plate (the plate opens at the same time), then is put
#    straight in its area; one that went to the discard pile grows in there.
func _on_card_zone_flight(card, from_zone, target_state) -> void:
	var g = game
	var S = CardBase.CardState
	if from_zone == null or not is_instance_valid(card):
		return
	var boosts := [g.get_node_or_null("AllCards/PlayerBoosts"), g.get_node_or_null("AllCards/OpponentBoosts")]
	if target_state == S.CardState_InGauge and from_zone in boosts:
		card.finish_animation_immediately()
		return
	var striking = g.get_node_or_null("AllCards/Striking")
	# Boosts cleared away as a strike resolves (just after it ends) leave like the strike cards:
	# off the screen sideways, then straight into their areas (no stop at the center).
	var strike_cleanup : bool = from_zone in boosts and strike_stage != null \
			and Time.get_ticks_msec() - int(strike_stage.ended_at_ms) < int(2500 / ANIM_PACE)
	# (a strike card, wherever it is parked, always leaves like one)
	if int(card.get_meta("phone_prev_state", -1)) == int(S.CardState_InStrike):
		strike_cleanup = true
	# Continuous boosts cleared at the end of a strike (just before its attacks leave, so the plate
	# is still closed): straight to the discard pile, no stop at the center.
	if from_zone in boosts and target_state == S.CardState_Discarded and not strike_cleanup \
			and strike_stage != null and strike_stage._active:
		return
	# Mulligan: cards going back from a hand into the deck (before that player's mulligan is done)
	# get a MULLIGAN banner and go through the center one at a time like any action's cards (your
	# own face up, the opponent's face down).
	var hands := [g.get_node_or_null("AllCards/PlayerHand"), g.get_node_or_null("AllCards/OpponentHand")]
	if USE_CENTER_STOP_FLIGHTS and target_state == S.CardState_InDeck and from_zone in hands \
			and not card.has_meta("phone_leg2"):
		var mside := hands.find(from_zone)
		if not _mulligan_done[mside]:
			if USE_MULLIGAN_FOCUS:
				if mside == 0:
					card.set_meta("phone_show_front", true)
				_fly_via_center(card, target_state, null, mside == 0)
			if not (action_banner_up and current_action_banner == "MULLIGAN") and strike_stage != null:
				strike_stage.show_action_banner("MULLIGAN", mside)
			return
	if from_zone != striking and not strike_cleanup:
		# Discards in the strike's cleanup (after the plate has opened, until the turn ends) fly
		# straight to the pile: no stop at the center.
		# (Not a discard down to the hand size, which goes through the center under HAND LIMIT.)
		var hand_limit_side := -1
		if from_zone == g.get_node_or_null("AllCards/PlayerHand"):
			hand_limit_side = 0
		elif from_zone == g.get_node_or_null("AllCards/OpponentHand"):
			hand_limit_side = 1
		var hand_limit : bool = hand_limit_side >= 0 and _hand_limit_at[hand_limit_side] >= 0.0 \
				and _now_s() - _hand_limit_at[hand_limit_side] < HAND_LIMIT_TTL
		# (the rest of the cards discarded together come while its banner is up)
		if _in_cleanup and target_state == S.CardState_Discarded and not hand_limit \
				and not (action_banner_up and current_action_banner == HAND_LIMIT_BANNER):
			return
		# (a card leaving a sealed area stops at the center wherever it goes, back into a deck too)
		var from_sealed : bool = from_zone in [g.get_node_or_null("AllCards/PlayerSealed"), g.get_node_or_null("AllCards/OpponentSealed")]
		if USE_CENTER_STOP_FLIGHTS and not card.has_meta("phone_leg2") \
				and (not target_state in [S.CardState_InStrike, S.CardState_InDeck, S.CardState_InHand]
					or (from_sealed and target_state == S.CardState_InDeck)):
			_fly_via_center(card, target_state, null, not str(from_zone.name).begins_with("Opponent"))
			# A character action's cost (force from a hand, or gauge): the UNIQUE ACTION banner, not
			# a payment / DISCARD one.
			if target_state == S.CardState_Discarded and from_zone in [g.get_node_or_null("AllCards/PlayerHand"),
					g.get_node_or_null("AllCards/OpponentHand")]:
				if _banner_ahead(true):
					return
			# The opponent paying force they were asked for (an attack's force cost, force for an
			# effect, force to block): their paid cards come under a PAY FORCE banner, in their
			# color, instead of DISCARD.
			if target_state == S.CardState_Discarded and strike_stage != null and _opp_force_pending() \
					and from_zone in [g.get_node_or_null("AllCards/OpponentHand"), g.get_node_or_null("AllCards/OpponentGauge")]:
				_opp_force_asked_at = -1.0
				var pay_text := UNIQUE_ACTION_BANNER if _opp_force_for_character else "PAY FORCE"
				if not (action_banner_up and current_action_banner == pay_text):
					strike_stage.show_action_banner(pay_text, 1)
				return
			# The action these cards are paying for (e.g. EXCEED: its gauge is spent before its own
			# event comes): its banner comes up now, before the first card reaches the center.
			if from_zone in [g.get_node_or_null("AllCards/PlayerGauge"), g.get_node_or_null("AllCards/OpponentGauge")]:
				_banner_ahead()
			# A card discarded from a hand by an effect (during a strike, or e.g. a boost forcing a
			# discard) gets a DISCARD banner, once for the cards discarded together, which waits
			# for them like any action banner. Not when the discard is an action's own cost (its
			# banner, e.g. CHANGE CARDS, is up already).
			# (Also a card discarded from the top of a deck, e.g. picked from the revealed cards.)
			if target_state == S.CardState_Discarded and strike_stage != null \
					and from_zone in [g.get_node_or_null("AllCards/PlayerHand"), g.get_node_or_null("AllCards/OpponentHand"),
							g.get_node_or_null("AllCards/PlayerDeck"), g.get_node_or_null("AllCards/OpponentDeck")] \
					and not (action_banner_up and _banner_covers_discards(current_action_banner)):
				var dside := 1 if str(from_zone.name).begins_with("Opponent") else 0
				# Discarding down to the hand size: HAND LIMIT instead of DISCARD.
				var dtext := "DISCARD"
				if _hand_limit_at[dside] >= 0.0 and _now_s() - _hand_limit_at[dside] < HAND_LIMIT_TTL \
						and from_zone in [g.get_node_or_null("AllCards/PlayerHand"), g.get_node_or_null("AllCards/OpponentHand")]:
					dtext = HAND_LIMIT_BANNER
					_hand_limit_at[dside] = -1.0
				strike_stage.show_action_banner(dtext, dside)
		return
	if target_state == S.CardState_InStrike or target_state == S.CardState_InHand:
		return # (still part of the strike, or back to the hand)
	var real_pos : Vector2 = card.target_pos
	var real_scale : Vector2 = card.target_scale
	var here : Vector2 = card.card_features.position
	var half_w : float = CARD_W * card.card_features.scale.x / 2.0
	var off_x : float = -half_w - 30.0 if here.x < W / 2.0 else W + half_w + 30.0
	# Out sideways at the plate's speed, keeping its size.
	card.target_pos = Vector2(off_x, here.y)
	card.target_scale = card.card_features.scale
	card.animation_length = strike_stage.OPEN_TIME if strike_stage != null else 0.3
	var token : int = int(card.get_meta("phone_exit_token", 0)) + 1
	card.set_meta("phone_exit_token", token)
	get_tree().create_timer(_pt(card.animation_length + 0.05)).timeout.connect(func():
		if not is_instance_valid(card) or int(card.get_meta("phone_exit_token", 0)) != token:
			return
		if card.state == S.CardState_Discarding:
			return # (sent somewhere else meanwhile)
		card.target_pos = real_pos
		card.target_scale = real_scale
		if card.state == S.CardState_Discarded:
			card.set_card_and_focus(real_pos, 0, Vector2.ZERO)
			var t : Tween = card.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			t.tween_property(card.card_features, "scale", real_scale, 0.24)
			t.tween_property(card.focus_feature, "scale", real_scale, 0.24)
		else:
			card.set_card_and_focus(real_pos, 0, real_scale))
var _discard_icon_cards : Array = [null, null]

# ---- Match over: animated banner (confetti on a win), tap it to leave -------------------
var game_over_root : Control = null

# ---- Victory slots ---------------------------------------------------------------------------
# Under each life bar, at its inner end: one slot per game that player needs to win the match (up
# to 3: a best of 3 needs 2, a best of 5 needs 3). An empty slot is a bold dot; a won game is a small
# white square marked N (won with a normal attack), S (special, in the player's color), U (ultra,
# rainbow) or X (any other way, in the green of the eye icon), filling from the inner end outward.
# The game doesn't play matches of several games yet: SERIES_WINS_NEEDED is 1, and the wins of
# earlier games (series_wins) are kept for when it does.
const VICTORY_SLOT := 30.0
const VICTORY_GAP := 6.0
const MAX_VICTORY_SLOTS := 3
static var series_wins_needed : int = 1
static var series_wins : Array = [[], []] # per side: the kinds of the games won so far
var _victory_slots : Array = [[], []]
var _x_green : Color = Color(0.25, 0.85, 0.3)
var _x_green_done : bool = false
var _series_checked : bool = false

func _victory_slot_count() -> int:
	return clampi(series_wins_needed, 1, MAX_VICTORY_SLOTS)

func _layout_victory_slots(side : int, inner_x : float, y : float) -> void:
	var n := _victory_slot_count()
	# (a finished match's wins don't carry into the next one: checked once, as this game starts)
	if not _series_checked:
		_series_checked = true
		if series_wins[0].size() >= n or series_wins[1].size() >= n:
			series_wins = [[], []]
	if not _x_green_done:
		_x_green_done = true
		_x_green = _eye_green()
	var slots : Array = _victory_slots[side]
	while slots.size() < n:
		var m = load("res://scenes/game/victory_marker.gd").new()
		m.z_index = 5
		backdrop.add_child(m)
		slots.append(m)
	for i in range(slots.size()):
		var m = slots[i]
		m.visible = i < n
		m.size = Vector2(VICTORY_SLOT, VICTORY_SLOT)
		var x : float = (inner_x - (i + 1) * VICTORY_SLOT - i * VICTORY_GAP) if side == 0 \
				else (inner_x + i * (VICTORY_SLOT + VICTORY_GAP))
		m.position = Vector2(x, y)
		m.player_color = _side_color(side == 0)
		m.x_color = _x_green
		var kinds : Array = series_wins[side]
		m.set_won(str(kinds[i]) if i < kinds.size() else "", false)

# The green of the eye icon (its most strongly green pixel).
func _eye_green() -> Color:
	var tex = load("res://assets/icons/greeneye.png")
	if tex == null:
		return Color(0.25, 0.85, 0.3)
	var img : Image = tex.get_image()
	if img == null:
		return Color(0.25, 0.85, 0.3)
	if img.is_compressed():
		img.decompress()
	var best := Color(0.25, 0.85, 0.3)
	var best_v := -1.0
	for py in range(0, img.get_height(), 2):
		for px in range(0, img.get_width(), 2):
			var c := img.get_pixel(px, py)
			if c.a < 0.8:
				continue
			var v := c.g - maxf(c.r, c.b)
			if v > best_v:
				best_v = v
				best = Color(c.r, c.g, c.b)
	return best

# Game._on_game_over: the winner's next slot is marked with how they won.
func record_victory(loser : int, reason : int) -> void:
	var winner := 1 if loser == int(Enums.PlayerId.PlayerId_Player) else 0
	var kind := "X"
	if reason == int(Enums.GameOverReason.GameOverReason_Life) and _gem_strike and _strike_card_ids[winner] >= 0:
		var lc = game.game_wrapper.get_card_database().get_card(_strike_card_ids[winner])
		if lc != null:
			match str(lc.definition.get("type", "")):
				"normal": kind = "N"
				"special": kind = "S"
				"ultra": kind = "U"
	var kinds : Array = series_wins[winner]
	if kinds.size() >= _victory_slot_count():
		return
	kinds.append(kind)
	var slots : Array = _victory_slots[winner]
	if kinds.size() - 1 < slots.size():
		slots[kinds.size() - 1].set_won(kind, true)

func show_game_over(won : bool) -> void:
	if not _built or _restored:
		return
	# If a strike ended the match, the plate opens and the cards leave now; the banner
	# appears right away, with its effects.
	if strike_stage != null:
		strike_stage.plate_wait()
	# The battle is over: the strike cards fade away so they don't sit behind the banner.
	var striking = game.get_node_or_null("AllCards/Striking")
	if striking != null:
		striking.create_tween().tween_property(striking, "modulate:a", 0.0, 0.25)
	_show_game_over_now(won)

func _show_game_over_now(won : bool) -> void:
	if not _built or _restored:
		return
	if game_over_root != null and is_instance_valid(game_over_root):
		game_over_root.queue_free()
	game.game_over_stuff.visible = false # the stock label is replaced by the banner
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.z_index = 150
	root.size = Vector2(W, H)
	game.add_child(root)
	game_over_root = root
	if not won:
		var storm : Control = load("res://scenes/game/storm_clouds.gd").new()
		storm.size = Vector2(W, H)
		storm.set("max_bottom", stage_y) # (no lower than the player names)
		root.add_child(storm)

	var bh := 230.0
	var by := H * 0.40 - bh / 2.0
	var base : Color = Color(0.95, 0.68, 0.08) if won else Color(0.42, 0.05, 0.08)
	var edge : Color = Color(1.0, 0.95, 0.6) if won else Color(0.9, 0.25, 0.25)
	var banner := Panel.new()
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.clip_contents = true
	var bsb := StyleBoxFlat.new()
	bsb.bg_color = Color(base.r, base.g, base.b, 0.95)
	bsb.border_color = edge
	bsb.border_width_top = 6
	bsb.border_width_bottom = 6
	banner.add_theme_stylebox_override("panel", bsb)
	banner.position = Vector2(-W - 60.0, by)
	banner.size = Vector2(W, bh)
	root.add_child(banner)

	# A soft light bar sweeping across the banner.
	var sweep := ColorRect.new()
	sweep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sweep.color = Color(1, 1, 1, 0.22)
	sweep.size = Vector2(90, bh + 40)
	sweep.position = Vector2(-160, -20)
	sweep.rotation = 0.35
	banner.add_child(sweep)

	var label := Label.new()
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "VICTORY!" if won else "DEFEAT"
	label.size = Vector2(W, bh - 40.0)
	label.position = Vector2(0, 6)
	label.pivot_offset = label.size / 2.0
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 128 if won else 140)
	label.add_theme_color_override("font_color", Color.WHITE if won else Color(1.0, 0.82, 0.82))
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0) if won else Color(0.12, 0, 0))
	label.add_theme_constant_override("outline_size", 16)
	banner.add_child(label)

	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "TAP TO EXIT"
	hint.size = Vector2(W, 36)
	hint.position = Vector2(0, bh - 46.0)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 26)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.9))
	hint.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hint.add_theme_constant_override("outline_size", 6)
	banner.add_child(hint)

	# The whole banner is the exit button.
	var btn := _invisible_button()
	btn.size = banner.size
	btn.pressed.connect(func(): game._quit_to_menu())
	banner.add_child(btn)

	# Slide in, bounce the text, then keep it alive.
	# Tweens belong to the banner, so they end with it.
	var slide := banner.create_tween()
	slide.tween_property(banner, "position:x", 0.0, 0.7).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	label.scale = Vector2(0.4, 0.4)
	var pop := banner.create_tween()
	pop.tween_interval(0.35)
	pop.tween_property(label, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	var breathe := banner.create_tween().set_loops()
	breathe.tween_interval(1.2)
	breathe.tween_property(label, "scale", Vector2(1.05, 1.05), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	breathe.tween_property(label, "scale", Vector2.ONE, 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	var glint := banner.create_tween().set_loops()
	glint.tween_interval(1.6)
	glint.tween_property(sweep, "position:x", W + 160.0, 1.1).set_trans(Tween.TRANS_SINE)
	glint.tween_callback(func(): sweep.position.x = -160.0)
	var blink := banner.create_tween().set_loops()
	blink.tween_property(hint, "modulate:a", 0.35, 0.8).set_trans(Tween.TRANS_SINE)
	blink.tween_property(hint, "modulate:a", 1.0, 0.8).set_trans(Tween.TRANS_SINE)

	if won:
		var conf := CPUParticles2D.new()
		conf.position = Vector2(W / 2.0, -30.0)
		conf.amount = 150
		conf.lifetime = 8.0
		conf.preprocess = 0.0
		conf.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
		conf.emission_rect_extents = Vector2(W / 2.0, 4.0)
		conf.direction = Vector2(0, 1)
		conf.spread = 25.0
		conf.gravity = Vector2(0, 140)
		conf.initial_velocity_min = 90.0
		conf.initial_velocity_max = 240.0
		conf.angular_velocity_min = -420.0
		conf.angular_velocity_max = 420.0
		conf.scale_amount_min = 8.0
		conf.scale_amount_max = 16.0
		var ramp := Gradient.new()
		ramp.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
		ramp.colors = PackedColorArray([Color(1, 0.25, 0.3), Color(1, 0.85, 0.2), Color(0.25, 0.85, 0.4),
				Color(0.3, 0.6, 1.0), Color(0.85, 0.4, 1.0), Color(1, 1, 1)])
		ramp.offsets = PackedFloat32Array([0.0, 0.2, 0.4, 0.6, 0.8, 0.95])
		conf.color_initial_ramp = ramp
		conf.emitting = true
		root.add_child(conf)

func _make_badge_label(gcard, gsz : float) -> Label:
	var bl := Label.new()
	bl.name = "Badge"
	bl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bl.text = gcard.badge_text
	bl.size = Vector2(gsz, gsz)
	bl.position = Vector2.ZERO
	bl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	var bl_scale := 0.72
	if gcard.badge_text.length() == 2 or gcard.badge_text.length() == 3:
		bl_scale = 0.56
	elif gcard.badge_text.length() > 3:
		bl_scale = 0.42
	bl.add_theme_font_override("font", load("res://scenes/game/badge_font.gd").make_font())
	bl.add_theme_font_size_override("font_size", int(gsz * bl_scale))
	bl.add_theme_color_override("font_color", gcard.badge_color)
	bl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
	bl.add_theme_constant_override("outline_size", 6)
	return bl

func _update_discard_icons() -> void:
	var slot := _bottom_slot_size()
	for side in range(2):
		var zone : Node = game.get_node_or_null("AllCards/PlayerDiscards" if side == 0 else "AllCards/OpponentDiscards")
		if zone == null:
			continue
		var holder : Panel = _discard_icons[side]
		if holder == null:
			holder = Panel.new()
			holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			holder.z_as_relative = false
			holder.z_index = 8
			holder.visible = false
			holder.add_theme_stylebox_override("panel", _style(Color(0.08, 0.1, 0.16, 0.78), Color(1, 1, 1, 0.7), 2, 8))
			var ic := TextureRect.new()
			ic.name = "Icon"
			ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			holder.add_child(ic)
			backdrop.add_child(holder)
			_discard_icons[side] = holder
		# Under a focused card (z 10), except during a strike: then the discard cards are raised
		# over the metal plate (z 11) and the icon has to sit above them.
		# (Follows the discard cards themselves: they stay raised a while after a strike ends,
		# while the cards fly to their piles.)
		var want_z : int = 12 if ((strike_stage != null and strike_stage._active) or int(zone.get("z_index")) >= 10) else 8
		if holder.z_index != want_z:
			holder.z_index = want_z
		# The discard count always sits on top of the top-card icon.
		var cl : Label = discard_label if side == 0 else odiscard_label
		if cl != null and (cl.z_as_relative or cl.z_index != want_z + 1):
			cl.z_as_relative = false
			cl.z_index = want_z + 1
		var cards := zone.get_children()
		if cards.is_empty():
			holder.visible = false
			_discard_icon_cards[side] = null
			_discard_icons_ready[side] = true
			continue
		var top = cards[cards.size() - 1]
		var icon : TextureRect = holder.get_node("Icon")
		var grow := false
		if top != _discard_icon_cards[side] or icon.texture == null:
			# A card still on its way to the pile: the pile shows what it had until it lands.
			if top.state == CardBase.CardState.CardState_Discarding:
				continue
			var tex := _moon_icon(top)
			if tex == null:
				holder.visible = false # card image not loaded yet; retry next frame
				continue
			icon.texture = tex
			# A new top card grows in from the pile's center, like a new gauge box (not when
			# the pile is first shown).
			grow = _discard_icons_ready[side] and top != _discard_icon_cards[side]
			_discard_icon_cards[side] = top
		var pos : Vector2 = Vector2(W - 8.0 - slot.x, bottom_y + (bottom_h - slot.y) / 2.0) if side == 0 else _opp_icon_pos(2)
		var sz := slot.x - 10.0 # nearly the full width of the pile card (5px gap each side)
		holder.size = Vector2(sz, sz)
		holder.position = pos + Vector2((slot.x - sz) / 2.0, slot.y * 0.5 - sz / 2.0)
		icon.position = Vector2(3, 3)
		icon.size = Vector2(sz - 6.0, sz - 6.0)
		# Special / ultra marker (roman numeral or greek letter), as on the gauge boxes.
		var btxt : String = str(top.badge_text)
		var bkey := btxt + "|" + str(roundi(sz))
		if str(holder.get_meta("bkey", "")) != bkey:
			holder.set_meta("bkey", bkey)
			var ob := holder.get_node_or_null("Badge")
			if ob != null:
				holder.remove_child(ob)
				ob.queue_free()
			if btxt != "":
				holder.add_child(_make_badge_label(top, sz))
		holder.visible = true
		_discard_icons_ready[side] = true
		if grow:
			_grow_in(holder)

# The "are you sure you want to quit" dialog hangs directly under the hamburger button
# (other modal dialogs stay centered on the screen).
func _place_modal() -> void:
	var g = game
	var dlg := g.get_node_or_null("ModalDialog") as Control
	if dlg == null or not dlg.visible:
		return
	# Above everything on the board, including the gold turn frame round the stage.
	_bring_to_front(dlg)
	if g.modal_dialog_type == g.ModalDialogType.ModalDialogType_ExitToMenu:
		var top := top_h + 32.0 + 4.0
		var panel := dlg.get_node_or_null("PanelContainer") as Control
		var ph : float = panel.get_combined_minimum_size().y if panel != null else 300.0
		dlg.offset_top = top
		dlg.offset_bottom = top + ph
	else:
		dlg.offset_top = 0.0
		dlg.offset_bottom = H

var _side_colors_set : bool = false
var _player_first : bool = true # (you are red when you went first, blue otherwise)

# The player who goes first is red, the other blue: that colours the player's bottom bar
# (and the left half of the stage) and the opponent's icon bar. The starting player is
# the active player when the match begins (mulligans), so it is read once then.
func _update_side_colors() -> void:
	if _side_colors_set:
		return
	var g = game
	if g.game_wrapper == null or g.ui_state == g.UIState.UIState_WaitForGameServer:
		return
	_side_colors_set = true
	var player_first : bool = g.game_wrapper.get_active_player() == Enums.PlayerId.PlayerId_Player
	_player_first = player_first
	# [top, bottom] of each bar's soft gradient.
	var red_bar := [Color(0.55, 0.20, 0.20), Color(0.38, 0.12, 0.13)]
	var blue_bar := [Color(0.26, 0.32, 0.60), Color(0.15, 0.19, 0.40)]
	var red_stage := Color(0.85, 0.15, 0.10, 0.20)
	var blue_stage := Color(0.10, 0.20, 0.95, 0.20)
	var pb : Array = red_bar if player_first else blue_bar
	var ob : Array = blue_bar if player_first else red_bar
	panels["bottom"].get_node("Metal").set_colors(pb[0], pb[1])
	panels["opp_bar"].get_node("Metal").set_colors(ob[0], ob[1])
	panels["stage_l"].add_theme_stylebox_override("panel", _style(red_stage if player_first else blue_stage))
	panels["stage_r"].add_theme_stylebox_override("panel", _style(blue_stage if player_first else red_stage))

func _process(_delta : float) -> void:
	if not _built or _restored:
		return
	_pace_tweens()
	_update_side_colors()
	_place_modal()
	_update_discard_icons()
	_reconcile_ref_list_popout()
	_update_revealed()
	_update_boost_zone_taps()
	_update_opp_action()
	_update_last_action_boxes()
	_update_turn_badge()
	_update_strike_overlays()
	_update_hand_known_eyes()
	_update_marble()
	_update_dialogs()
	_update_turn_highlight()
	_update_exceed_icons()
	_update_star_neon()
	_update_wild_labels()
	_update_pick_glows()
	_update_bonus_preview()
	_update_multi_action_box()
	_update_hidden_boosts()
	_update_boost_layout()
	if game.action_menu_container.visible:
		_place_action_menu()
	if GlobalSettings.phone_controls_active():
		_update_menu_minimize()
		_update_island()
	else:
		# (no island: the pre-confirmation banners follow the action popup)
		_update_confirm_banner(game.action_menu_container.visible)
	_update_gauge_highlight(_delta)
	_update_low_life(_delta)
	_pump_center_queue()
	if GlobalSettings.phone_controls_active():
		_update_move_highlight()
		_update_choice_highlights()
		_update_gauge_selection_outline()
	if game.enforce_timer != _last_timers_enabled:
		_layout_life()
	# A card preview never outlives the popup it came from.
	if popout_preview_root != null and game.card_popout_parent.get_child_count() == 0 \
			and not _preview_keep \
			and (char_review_root == null or not is_instance_valid(char_review_root)):
		close_popout_preview()
	# The asterisk buttons are shown exactly when the game shows the extra card.
	var buddy_cards = [game.player_buddy_character_card, game.opponent_buddy_character_card]
	for side in range(2):
		if star_buttons[side] != null and is_instance_valid(buddy_cards[side]):
			var star_vis : bool = buddy_cards[side].visible or _has_extra_refs(side)
			if side == 1 and star_vis != star_buttons[side].visible:
				# The asterisk takes room from the opponent's hand area: re-fit their hand.
				star_buttons[side].visible = star_vis
				var hs : Control = game.get_node_or_null("OpponentHand/HandSpawn")
				if hs != null:
					hs.position = _opp_hand_center() - hs.size * hs.scale / 2.0
				game.layout_player_hand(false)
			star_buttons[side].visible = star_vis
			# The real extra card is replaced by the asterisk: keep it parked off screen and
			# untouchable (the game moves it back on screen when the buddy appears, where
			# its invisible buttons used to swallow taps meant for the hamburger menu).
			var bc = buddy_cards[side]
			if bc.position.x > -1500.0:
				bc.position = Vector2(-2000, -2000)
			if not bc.has_meta("phone_untouchable"):
				bc.set_meta("phone_untouchable", true)
				for n in bc.find_children("*", "Control", true, false):
					n.mouse_filter = Control.MOUSE_FILTER_IGNORE

# Characters with a card kept out of the game (set aside) that is worth looking at during the
# match: it is listed in their asterisk (extra cards) window, and the asterisk is always shown.
const EXTRA_REFERENCE_CARDS := {
	"happychaos": ["happychaos_deusexmachina"],
}
var _extra_refs_state : Array = [0, 0] # 0 = not made yet, 1 = being made, 2 = made / none

func _has_extra_refs(side : int) -> bool:
	var deck : Dictionary = game.player_deck if side == 0 else game.opponent_deck
	var ids : Array = EXTRA_REFERENCE_CARDS.get(str(deck.get("id", "")), [])
	if ids.is_empty():
		return false
	if _extra_refs_state[side] == 0:
		_extra_refs_state[side] = 1
		_make_extra_refs(side, deck, ids)
	return true

func _make_extra_refs(side : int, deck : Dictionary, ids : Array) -> void:
	var g = game
	var pid := Enums.PlayerId.PlayerId_Player if side == 0 else Enums.PlayerId.PlayerId_Opponent
	var zone = g.get_node("AllCards/PlayerBuddyCopy" if side == 0 else "AllCards/OpponentBuddyCopy")
	var card_db = g.game_wrapper.get_card_database()
	var back_url : String = deck["image_resources"]["cardback"]["url"]
	var made : Array = []
	for card in g.game_wrapper.get_player_deck_list(pid):
		var lc = card_db.get_card(card.id)
		var def_id : String = str(lc.definition.get("id", ""))
		if not def_id in ids or def_id in made:
			continue
		made.append(def_id)
		var copy_card = await g.create_card(CardBase.BuddyCardReferenceId, lc.definition,
			lc.get_image_url_index_data(), back_url, zone, side == 1,
			lc.definition["display_name"], lc.definition["boost"]["display_name"])
		copy_card.hide_count = true
		copy_card.set_card_and_focus(g.OffScreen, 0, CardBase.ReferenceCardScale)
		copy_card.resting_scale = CardBase.ReferenceCardScale
		copy_card.change_state(CardBase.CardState.CardState_Offscreen)
		copy_card.flip_card_to_front(true)
	_extra_refs_state[side] = 2

# The asterisk icons: the deck's card back, and a gently pulsing neon frame.
func _update_star_neon() -> void:
	# The asterisk buttons take taps before the hand cards: they sit just after the cards in the
	# scene tree (taps go to the control that comes last), but before the popup windows.
	var all_cards = game.get_node_or_null("AllCards")
	if all_cards != null:
		for sb in star_buttons:
			if sb == null:
				continue
			if sb.get_parent() != game:
				sb.reparent(game, false)
			if sb.get_index() < all_cards.get_index():
				game.move_child(sb, all_cards.get_index())
	var pulse := 0.5 # steady glow (no pulse)
	for side in range(2):
		var sb = star_buttons[side]
		if sb == null or not sb.visible:
			continue
		var back : TextureRect = sb.get_node("Back")
		if back.texture == null:
			var src : TextureRect = sealed_rect if side == 0 else osealed_rect
			if src != null and src.texture != null:
				back.texture = src.texture
		var fs : StyleBoxFlat = sb.get_node("Neon").get_theme_stylebox("panel")
		fs.border_color = Color(0.2, 1.0, 1.0).lerp(Color(0.75, 1.0, 1.0), pulse)
		var gs : StyleBoxFlat = sb.get_node("Glow").get_theme_stylebox("panel")
		gs.shadow_size = int(lerpf(5.0, 12.0, pulse))
		gs.shadow_color = Color(1.0, 0.2, 0.85, lerpf(0.45, 0.9, pulse))
		var star : Label = sb.get_node("Star")
		star.add_theme_color_override("font_outline_color", Color(1.0, 0.25, 0.85, lerpf(0.6, 1.0, pulse)))

# Top bar: both turn markers sit in the center (P1 center-left, P2 center-right,
# mirrored) with the clocks directly beneath them, and each life bar stretches
# from the screen edge to its marker. Counters sit under the bars.
func _layout_life() -> void:
	var timers : bool = game.enforce_timer
	_last_timers_enabled = timers
	var center_gap := 36.0 # (just clear of the menu button: the bars fill the old turn-marker space)
	var clock_w := 60.0
	var marker_off := 30.0 # distance from center line to each marker / clock (room for the menu button)
	var bar_w := W / 2.0 - center_gap - 6.0
	for pair in [["PlayerLife", true], ["OpponentLife", false]]:
		var life : LifeScene = game.get_node(pair[0])
		var is_p1 : bool = pair[1]
		life.scale = Vector2.ONE
		life.position = Vector2(6.0 if is_p1 else W / 2.0 + center_gap, 4.0)
		life.clock_suppressed = not timers

		var hb = life.get_node("HealthBar")
		for panel_name in ["RedBarBackground", "BackgroundPanel"]:
			var panel : Control = hb.get_node(panel_name)
			panel.custom_minimum_size = Vector2(bar_w, 35)
			panel.size = Vector2(bar_w, 35)
		_style_life_bar(hb, bar_w)
		# Your (red) bar is anchored at the center end and empties toward it, mirroring the
		# opponent's, which empties toward the center from the other side.
		var fill_dir := ProgressBar.FILL_END_TO_BEGIN if is_p1 else ProgressBar.FILL_BEGIN_TO_END
		for bar_path in ["BackgroundPanel/Margin/HealthProgressBar", "RedBarBackground/Margin/JustLostHealthBar"]:
			(hb.get_node(bar_path) as ProgressBar).fill_mode = fill_dir

		# life / deck / discard counters: left under the P1 bar, right under the P2 bar (hidden: the
		# victory slots sit under the bars instead; the counters are still kept up to date)
		var info : HBoxContainer = life.get_node("CardInfoBox")
		info.visible = false
		var side := 0 if is_p1 else 1
		if hand_icons[side] == null:
			var hi := TextureRect.new()
			# The stock icon is black; recolor it white so it reads on the dark bar.
			var himg : Image = (load("res://assets/icons/cards.png") as Texture2D).get_image()
			for py in himg.get_height():
				for px in himg.get_width():
					var pc := himg.get_pixel(px, py)
					himg.set_pixel(px, py, Color(1, 1, 1, pc.a))
			hi.texture = ImageTexture.create_from_image(himg)
			hi.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			hi.custom_minimum_size = Vector2(44, 48)
			hi.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			hi.tooltip_text = "Cards in Hand"
			info.add_child(hi)
			var hl := Label.new()
			hl.add_theme_font_size_override("font_size", 32)
			hl.mouse_filter = Control.MOUSE_FILTER_PASS
			hl.tooltip_text = "Cards in Hand"
			hl.text = "0"
			info.add_child(hl)
			hand_icons[side] = hi
			hand_labels[side] = hl
		# White-tint the stock (black) icons so they read on the dark bar.
		for icon_name in ["HPIcon", "DeckIcon", "DiscardIcon", "DiscardXIcon"]:
			var ic : TextureRect = info.get_node(icon_name)
			if not ic.has_meta("white_done"):
				ic.texture = _white_texture(ic.texture)
				ic.set_meta("white_done", true)
		# Player: heart, deck, trash, hand. Opponent: the exact mirror image.
		var order : Array = ["HPIcon", "HPLabel", "DeckIcon", "DeckLabel", "DiscardIcon", "DiscardXIcon", "DiscardLabel"]
		var groups : Array = [
			[info.get_node("HPIcon"), info.get_node("HPLabel")],
			[info.get_node("DeckIcon"), info.get_node("DeckLabel")],
			[info.get_node("DiscardIcon"), info.get_node("DiscardXIcon"), info.get_node("DiscardLabel")],
			[hand_icons[side], hand_labels[side]],
		]
		# The opponent's groups run in reverse order, but each icon keeps its number on its right.
		var nodes : Array = []
		for grp in groups:
			nodes.append_array(grp)
		for idx in range(nodes.size()):
			info.move_child(nodes[idx], idx)
		info.alignment = BoxContainer.ALIGNMENT_BEGIN if is_p1 else BoxContainer.ALIGNMENT_END
		info.custom_minimum_size = Vector2(0, 48)
		var cw : float = info.get_combined_minimum_size().x + 24.0
		var s : float = minf(0.75, bar_w / cw)
		info.scale = Vector2(s, s)
		info.size = Vector2(bar_w / s, 48)
		info.position = Vector2(0.0, 38.0)

		# The turn marker is replaced by the TURN badge on the stage (see _update_turn_badge).
		var indicator : Control = life.get_node("TurnIndicator")
		indicator.visible = false

		var clock : Label = life.get_node("Clock")
		clock.size = Vector2(clock_w, 34)
		clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if is_p1 else HORIZONTAL_ALIGNMENT_LEFT
		var clock_abs_x : float = W / 2.0 - marker_off - clock_w if is_p1 else W / 2.0 + marker_off
		clock.position = Vector2(clock_abs_x - life.position.x, 42.0)
		if not timers:
			clock.visible = false
		# The victory slots: under the bar, at its inner end (outside the clock when it shows).
		var inner_x : float = (6.0 + bar_w) if is_p1 else (W / 2.0 + center_gap)
		if timers:
			inner_x = (clock_abs_x - 6.0) if is_p1 else (clock_abs_x + clock_w + 6.0)
		_layout_victory_slots(side, inner_x, 4.0 + 38.0 + 2.0)

# Life bars: an orange frame (the gold / amber of the board's trim), and thin black lines through
# the bar at every 5 life (5, 10, 15, 20, 25 of 30).
const LIFE_BORDER := Color(1.0, 0.56, 0.16)

func _style_life_bar(hb : Node, bar_w : float) -> void:
	var bg : PanelContainer = hb.get_node("RedBarBackground")
	if not bg.has_meta("phone_styled"):
		bg.set_meta("phone_styled", true)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.09, 0.09, 0.09)
		sb.border_color = LIFE_BORDER
		sb.set_border_width_all(3)
		sb.set_corner_radius_all(4)
		bg.add_theme_stylebox_override("panel", sb)
		# The fill's 5 px content margins gave it a 10 px minimum width that Godot adds on top of
		# the life fraction, so the bar ran about one life long (5 life reached past the 5 line).
		# Without them the fill is exactly life / 30 of the bar, matching the lines.
		for bar_path in ["BackgroundPanel/Margin/HealthProgressBar", "RedBarBackground/Margin/JustLostHealthBar"]:
			var pb : ProgressBar = hb.get_node(bar_path)
			var fill = pb.get_theme_stylebox("fill")
			if fill != null:
				var f2 : StyleBox = fill.duplicate()
				f2.set_content_margin_all(0.0)
				pb.add_theme_stylebox_override("fill", f2)
		var ticks := Control.new()
		ticks.name = "LifeTicks"
		ticks.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ticks) # (after both bars, so drawn over them)
		ticks.draw.connect(func():
			# A thin tick at every single life (top and bottom edges), a full black line every 5.
			var steps : int = int(HealthBar.MaxHealth)
			var tick_h : float = ticks.size.y * 0.3
			for i in range(1, steps):
				var x := ticks.size.x * i / steps
				if i % 5 == 0:
					ticks.draw_line(Vector2(x, 0.0), Vector2(x, ticks.size.y), Color.BLACK, 2.0)
				else:
					ticks.draw_line(Vector2(x, 0.0), Vector2(x, tick_h), Color(0, 0, 0, 0.75), 1.0)
					ticks.draw_line(Vector2(x, ticks.size.y - tick_h), Vector2(x, ticks.size.y), Color(0, 0, 0, 0.75), 1.0))
	var tk : Control = hb.get_node("LifeTicks")
	# Over the fill area only (inside the 5 px margins).
	tk.position = Vector2(5.0, 5.0)
	if tk.size != Vector2(bar_w - 10.0, 25.0):
		tk.size = Vector2(bar_w - 10.0, 25.0)
		tk.queue_redraw()

# ---- Low life: the bar glows and pulses -------------------------------------------------------
# At 6 life or less a player's life bar is highlighted (a red glow round it, its border warming
# from orange to red) and pulses, faster the closer they are to 0: about once a second at 6, about
# four times a second at 1.
const LOW_LIFE := 6
var _low_life_phase : Array = [0.0, 0.0]

func _update_low_life(delta : float) -> void:
	for pair in [["PlayerLife", 0], ["OpponentLife", 1]]:
		var hb = game.get_node_or_null("%s/HealthBar" % pair[0])
		if hb == null:
			continue
		var side : int = pair[1]
		var bar : Range = hb.get_node("BackgroundPanel/Margin/HealthProgressBar")
		var bg : PanelContainer = hb.get_node("RedBarBackground")
		var sb = bg.get_theme_stylebox("panel")
		var glow : Panel = hb.get_node_or_null("LowLifeGlow")
		if glow == null:
			glow = Panel.new()
			glow.name = "LowLifeGlow"
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow.visible = false
			hb.add_child(glow)
			hb.move_child(glow, 0) # (behind the bar)
		var life := int(bar.value)
		var low : bool = life <= LOW_LIFE and life > 0
		if not low:
			if glow.visible:
				glow.visible = false
				if sb is StyleBoxFlat:
					sb.border_color = LIFE_BORDER
			continue
		# 1 Hz at 6 life up to about 4 Hz at 1.
		var hz := lerpf(1.0, 4.0, float(LOW_LIFE - life) / float(LOW_LIFE - 1))
		_low_life_phase[side] = fmod(_low_life_phase[side] + delta * hz, 1.0)
		var pulse := 0.5 + 0.5 * sin(_low_life_phase[side] * TAU)
		var red := Color(1.0, 0.12, 0.08)
		var gsb := StyleBoxFlat.new()
		gsb.draw_center = false
		gsb.border_color = Color(red, 0.55 + 0.45 * pulse)
		gsb.set_border_width_all(3)
		gsb.set_corner_radius_all(6)
		gsb.shadow_color = Color(red, 0.35 + 0.45 * pulse)
		gsb.shadow_size = int(4.0 + 8.0 * pulse)
		glow.add_theme_stylebox_override("panel", gsb)
		glow.position = bg.position - Vector2(3, 3)
		glow.size = bg.size + Vector2(6, 6)
		glow.visible = true
		if sb is StyleBoxFlat:
			sb.border_color = LIFE_BORDER.lerp(red, 0.35 + 0.65 * pulse)

# ---- TURN badge -------------------------------------------------------------------------------
# A toggle switch: a silver-bordered track centered at the top of the stage (on the row of the
# last-action boxes and just as tall, reaching the same distance into each side), with the shiny
# silver "TURN" badge as its knob, sitting in the half of whose turn it is and gliding across when
# the turn changes. The other half of the track is darkened. It's drawn under the gold turn frame
# (z 3), which goes over it.
const TURN_TRACK_PAD := 3.0
var _turn_track : Control = null
# Fixed sizes: the knob is just wide enough for "TURN" (plus a little padding) and never resizes
# with the last-action boxes beside it; the track hugs the two knob positions.
const TURN_BADGE_H := 32.0
const TURN_BADGE_TEXT_PAD := 9.0 # (each side of the word)
const TURN_KNOB_GAP := 1.0       # (each side of the center seam)
var TURN_BADGE_W : float = _measure_turn_badge_w()
var _turn_badge : Control = null
var _turn_badge_side : int = -1
var _turn_badge_tween : Tween = null

func _update_turn_badge() -> void:
	var g = game
	# (Game.set_turn_indicator still shows / hides the old, now hidden, markers: they say whose
	# turn it is.)
	var p_ind = g.get_node_or_null("PlayerLife/TurnIndicator")
	var o_ind = g.get_node_or_null("OpponentLife/TurnIndicator")
	var side := -1
	if p_ind != null and p_ind.modulate.a > 0.5:
		side = 0
	elif o_ind != null and o_ind.modulate.a > 0.5:
		side = 1
	if _turn_badge == null or not is_instance_valid(_turn_badge):
		_turn_track = Control.new()
		_turn_track.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_turn_track.z_index = 2 # (under the gold turn frame, z 3)
		_turn_track.draw.connect(_draw_turn_track)
		backdrop.add_child(_turn_track)
		_turn_badge = load("res://scenes/game/turn_badge.gd").new()
		_turn_badge.z_index = 2
		backdrop.add_child(_turn_badge)
	if side < 0:
		_turn_badge.visible = false
		_turn_track.visible = false
		_turn_badge_side = -1
		return
	_turn_track.visible = true
	# As tall as the last-action box; before that box first shows (the first turn), as tall as
	# it will be (its font at full size, plus its margins).
	# Fixed size, centered on the row of the (fixed-height) last-action boxes.
	var h := TURN_BADGE_H
	_turn_badge.size = Vector2(TURN_BADGE_W, h)
	var y := stage_y + 36.0 + (LAST_ACTION_H - h) / 2.0
	var tp := TURN_TRACK_PAD
	_turn_track.position = Vector2(W / 2.0 - TURN_KNOB_GAP - TURN_BADGE_W - tp, y - tp)
	_turn_track.size = Vector2((TURN_BADGE_W + TURN_KNOB_GAP + tp) * 2.0, h + tp * 2.0)
	_turn_track.queue_redraw()
	var x := W / 2.0 - TURN_KNOB_GAP - TURN_BADGE_W if side == 0 else W / 2.0 + TURN_KNOB_GAP
	var target := Vector2(x, y)
	if not _turn_badge.visible or _turn_badge_side < 0:
		_turn_badge.position = target
		_turn_badge.visible = true
	elif side != _turn_badge_side:
		if _turn_badge_tween != null and _turn_badge_tween.is_valid():
			_turn_badge_tween.kill()
		_turn_badge_tween = _turn_badge.create_tween()
		_turn_badge_tween.tween_property(_turn_badge, "position", target, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	elif _turn_badge_tween == null or not _turn_badge_tween.is_running():
		_turn_badge.position = target
	_turn_badge_side = side

# The track: a dark slot with a polished silver rim; the half the knob is in is lit a little, the
# other half darkened.
func _draw_turn_track() -> void:
	var t := _turn_track
	var r := Rect2(Vector2.ZERO, t.size)
	var rad := minf(10.0, r.size.y * 0.35)
	var rim := StyleBoxFlat.new()
	rim.bg_color = Color(0.62, 0.64, 0.69)
	rim.set_corner_radius_all(int(rad))
	rim.border_color = Color(0.92, 0.93, 0.96)
	rim.border_width_top = 2
	rim.border_width_left = 1
	rim.border_width_right = 1
	rim.border_width_bottom = 1
	rim.shadow_color = Color(0, 0, 0, 0.45)
	rim.shadow_size = 3
	t.draw_style_box(rim, r)
	var inner := r.grow(-2.0)
	var half_w := inner.size.x / 2.0
	var lit := Color(0.32, 0.34, 0.39)
	# The empty half is a slot sunk into the metal: darkest just under its top lip, lightening
	# toward the bottom, with inner shadows on the top and sides and a thin light lip along the
	# bottom edge (where the rim catches the light).
	var dark_top := Color(0.015, 0.017, 0.025)
	var dark_bottom := Color(0.12, 0.13, 0.16)
	var cr := int(maxf(rad - 2.0, 2.0))
	# (follows the knob as it glides, switching sides as it passes the middle)
	var knob_left : bool = _turn_badge.position.x + _turn_badge.size.x / 2.0 < W / 2.0
	for i in range(2):
		var hr := Rect2(inner.position + Vector2(half_w * i, 0.0), Vector2(half_w, inner.size.y))
		var is_lit : bool = (i == 0) == knob_left and _turn_badge_side >= 0
		var sb := StyleBoxFlat.new()
		sb.bg_color = lit if is_lit else dark_top
		if i == 0:
			sb.corner_radius_top_left = cr
			sb.corner_radius_bottom_left = cr
		else:
			sb.corner_radius_top_right = cr
			sb.corner_radius_bottom_right = cr
		t.draw_style_box(sb, hr)
		if is_lit:
			continue
		# Vertical gradient (dark at the top, lighter at the bottom), inset from the rounded
		# outer corners so it stays inside the slot.
		var steps := 10
		var gx0 : float = hr.position.x + (float(cr) if i == 0 else 0.0)
		var gx1 : float = hr.end.x - (float(cr) if i == 1 else 0.0)
		for s in range(steps):
			var f := float(s) / steps
			var gy := hr.position.y + hr.size.y * f
			t.draw_rect(Rect2(gx0, gy, gx1 - gx0, hr.size.y / steps + 0.5),
					dark_top.lerp(dark_bottom, f * f))
		# Inner shadows: heavy along the top, lighter down the outer side.
		for s in range(4):
			var a := 0.55 * (1.0 - s / 4.0)
			t.draw_line(Vector2(hr.position.x + cr * 0.5, hr.position.y + 0.5 + s),
					Vector2(hr.end.x - cr * 0.5, hr.position.y + 0.5 + s), Color(0, 0, 0, a), 1.0)
		var side_x := hr.position.x + 0.5 if i == 0 else hr.end.x - 0.5
		var side_dir := 1.0 if i == 0 else -1.0
		for s in range(3):
			var a := 0.4 * (1.0 - s / 3.0)
			var sx := side_x + side_dir * s
			t.draw_line(Vector2(sx, hr.position.y + cr), Vector2(sx, hr.end.y - cr), Color(0, 0, 0, a), 1.0)
		# The light lip along the bottom edge.
		t.draw_line(Vector2(hr.position.x + cr, hr.end.y - 0.5), Vector2(hr.end.x - cr, hr.end.y - 0.5),
				Color(1, 1, 1, 0.22), 1.0)
	# The center seam.
	t.draw_line(Vector2(r.size.x / 2.0, inner.position.y + 2), Vector2(r.size.x / 2.0, inner.end.y - 2), Color(0, 0, 0, 0.45), 1.0)

# The knob's width: "TURN" at the badge's font size (58% of its height, see turn_badge.gd),
# plus padding.
static func _measure_turn_badge_w() -> float:
	var f : Font = load("res://scenes/game/badge_font.gd").make_font()
	var fs := int(TURN_BADGE_H * 0.58)
	return ceilf(f.get_string_size("TURN", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + TURN_BADGE_TEXT_PAD * 2.0)

func hide_unused_arena_art() -> void:
	var g = game
	g.friend_track_layer.visible = false
	g.enemy_track_layer.visible = false
	for layer in g.friend_track_overlay_layers:
		layer.visible = false
	for layer in g.enemy_track_overlay_layers:
		layer.visible = false
	g.arena_graphics.visible = false

func _place_pile(button : Control, pos : Vector2, width : float) -> void:
	button.size = Vector2(CARD_W, CARD_H)
	button.scale = Vector2(width / CARD_W, width / CARD_W)
	button.position = pos

func _place_strike_zone(zone : Control, center : Vector2) -> void:
	# Only a position marker for strike cards: it must not swallow taps meant for the
	# red / blue Boost / Strike areas underneath.
	zone.mouse_filter = Control.MOUSE_FILTER_IGNORE
	zone.size = Vector2(CARD_W, CARD_H)
	zone.scale = Vector2(0.4, 0.4)
	zone.position = center - zone.size * zone.scale / 2.0

# --------------------------------------------------------------------------
# Characters / arena strip
# --------------------------------------------------------------------------

var _visible_cache := {}
var _full_width_cache := {}

# Per character: the part of the idle pose (as fractions of its visible box) to fit into the
# stage, for figures with long weapons / limbs that should reach past it.
const BODY_FIT := {
	"waldstein": Rect2(0.2, 0.0, 0.47, 1.0),
	"yuzu": Rect2(0.18, 0.0, 0.43, 1.0),
	"orie": Rect2(0.0, 0.27, 1.0, 0.73),
}
# Characters that look a little small with the standard fit.
const SCALE_BOOST := {"merkava": 1.15, "nanase": 1.15, "mika": 1.15}

func _scale_boost(ch : Character) -> float:
	var path := String(ch.animation.sprite_frames.resource_path)
	for k in SCALE_BOOST:
		if path.contains("/%s/" % k):
			return SCALE_BOOST[k]
	return 1.0

# A character whose limbs reach past the middle of the stage is drawn behind the opponent.
func _layer_chars() -> void:
	var a : Character = game.get_node_or_null("PlayerCharacter")
	var b : Character = game.get_node_or_null("OpponentCharacter")
	if a == null or b == null:
		return
	var wa : bool = a.has_meta("wide_reach")
	var wb : bool = b.has_meta("wide_reach")
	a.z_index = 1 if (wb and not wa) else 0
	b.z_index = 1 if (wa and not wb) else 0

# The box (in frame pixels) the character's idle pose really occupies, padded a little.
# Falls back to the whole frame for tightly cropped sprites.
func _visible_rect(ch : Character, tex_size : Vector2) -> Rect2:
	var full := Rect2(Vector2.ZERO, tex_size)
	var frames = ch.animation.sprite_frames
	var key : int = frames.get_instance_id()
	if _visible_cache.has(key):
		return _visible_cache[key]
	var result := full
	var tex = frames.get_frame_texture("idle", 0)
	var img : Image = tex.get_image() if tex != null else null
	if img != null and not img.is_empty():
		var r : Rect2 = Rect2(img.get_used_rect())
		if r.size.x > 0.0 and r.size.y > 0.0 and (r.size.y < tex_size.y * 0.8 or r.size.x < tex_size.x * 0.8):
			var pad := r.size.y * 0.04
			result = Rect2(r.position - Vector2(pad, pad), r.size + Vector2(pad, pad) * 2.0).intersection(full)
	_full_width_cache[key] = result.size.x
	# Figures with long reaching limbs (Waldstein's arms): fit the body only; the limbs are
	# allowed to reach into the opponent's half (drawn behind the opponent, see _layer_chars).
	for k in BODY_FIT:
		if String(frames.resource_path).contains("/%s/" % k):
			var f : Rect2 = BODY_FIT[k]
			result = Rect2(result.position + result.size * f.position, result.size * f.size)
	_visible_cache[key] = result
	return result

func _place_main_character(ch : Character, is_p1 : bool) -> void:
	if ch.animation == null or ch.animation.sprite_frames == null:
		return
	var tex_size : Vector2 = ch.get_size()
	# Some sprite sheets (season 6) have huge, mostly empty frames: fit the visible figure
	# (not the frame) into the stage, and stand its feet on the floor line.
	var fit := _visible_rect(ch, tex_size)
	var s := minf(minf(stage_full_h * 0.70, stage_h - band_h - 80.0) / fit.size.y, (W / 2.0 - 24.0) / fit.size.x)
	s *= _scale_boost(ch)
	ch.scale = Vector2(s, s)
	var full_w : float = _full_width_cache.get(ch.animation.sprite_frames.get_instance_id(), fit.size.x)
	if full_w * s > W / 2.0:
		ch.set_meta("wide_reach", true)
	elif ch.has_meta("wide_reach"):
		ch.remove_meta("wide_reach")
	_layer_chars()
	var feet_y := stage_y + stage_h - band_h - 8.0
	var bottom_from_center : float = fit.end.y - tex_size.y / 2.0
	var pos := Vector2(W * (0.25 if is_p1 else 0.75), feet_y - (bottom_from_center + ch.vertical_offset) * s)
	char_stage_pos[ch] = pos
	if ch.animation_state == Character.AnimationState.AnimationState_Moving:
		ch.target_position = pos
	else:
		ch.position = pos
		ch.current_position = pos
		ch.target_position = pos

# Replacement for Game.move_character_to_arena_square in phone mode.
func on_character_moved(character : Character, arena_location : int, immediate : bool,
		move_anim, buddy_offset : int) -> void:
	var g = game
	var is_p1 : bool = character == g.get_node("PlayerCharacter")
	var is_p2 : bool = character == g.get_node("OpponentCharacter")
	if is_p1 or is_p2:
		_place_main_character(character, is_p1)
		var pos : Vector2 = char_stage_pos.get(character, character.position)
		if immediate:
			character.position = pos
		else:
			character.move_to(pos, move_anim)
		# The stage always shows P1 on the left and P2 on the right: face each other from the start.
		character.set_facing(is_p1)
		if is_p1:
			p1_loc = arena_location
		else:
			p2_loc = arena_location
	else:
		character.position = OFFSCREEN
		var mine : bool = character in g.player_buddies or character.get_parent() == g.player_lightningrods
		var old_entry : Dictionary = aux_markers.get(character.get_instance_id(), {})
		var old_marker = old_entry.get("marker", null)
		# A marker already on the strip (Eddie moved by a boost or an effect) glides to its new
		# space; only a new one appears there directly.
		var was_placed : bool = old_marker != null and is_instance_valid(old_marker) and old_entry.get("placed", false)
		aux_markers[character.get_instance_id()] = {
			"ch": character, "loc": arena_location, "off": buddy_offset, "mine": mine,
			"marker": old_marker, "placed": was_placed and not immediate,
		}
	update_strip()

func update_strip() -> void:
	if not _built:
		return
	var g = game
	var pc = g.get_node("PlayerCharacter")
	var oc = g.get_node("OpponentCharacter")
	var ploc : int = g.cached_player_location if g.cached_player_location > 0 else p1_loc
	var oloc : int = g.cached_opponent_location if g.cached_opponent_location > 0 else p2_loc
	var pw := 0
	var ow := 0
	if g.game_wrapper.current_game != null:
		if pc.is_wide:
			pw = g.game_wrapper.get_player_extra_width(Enums.PlayerId.PlayerId_Player)
		if oc.is_wide:
			ow = g.game_wrapper.get_player_extra_width(Enums.PlayerId.PlayerId_Opponent)
	for i in range(1, 10):
		var color := Color(0.42, 0.42, 0.42)
		if ploc > 0 and i >= ploc - pw and i <= ploc + pw:
			color = Color(0.62, 0.30, 0.28)
		elif oloc > 0 and i >= oloc - ow and i <= oloc + ow:
			color = Color(0.28, 0.32, 0.64)
		square_styles[i - 1].bg_color = color
	# Eddie (Zato's buddy) has an icon of his own: a character standing in his space shares
	# it with him, Eddie on the bottom half.
	var eddie_locs := {}
	for key in aux_markers.keys():
		var en : Dictionary = aux_markers[key]
		if _is_eddie(en["ch"]) and is_instance_valid(en["ch"]) and en["ch"].visible and en["loc"] >= 1 and en["loc"] <= 9:
			eddie_locs[int(en["loc"])] = true
	_place_icon(p1_icon, ploc, pw, pw == 0 and eddie_locs.has(ploc))
	_place_icon(p2_icon, oloc, ow, ow == 0 and eddie_locs.has(oloc))
	_place_arena_button(arena_btn_p, ploc, pw)
	_place_arena_button(arena_btn_o, oloc, ow)
	_place_phone_extras()

	for key in aux_markers.keys():
		var entry : Dictionary = aux_markers[key]
		var ch = entry["ch"]
		var marker = entry["marker"]
		var alive : bool = is_instance_valid(ch) and not ch.is_queued_for_deletion() and ch.visible and ch.is_inside_tree()
		if not alive or entry["loc"] < 1 or entry["loc"] > 9:
			if marker != null and is_instance_valid(marker):
				marker.queue_free()
			aux_markers.erase(key)
			continue
		if marker == null or not is_instance_valid(marker):
			marker = _make_eddie_icon(entry["mine"]) if _is_eddie(ch) else _make_aux_marker(ch, entry["mine"])
			entry["marker"] = marker
		if marker != null and marker.has_meta("eddie_side"):
			var eloc : int = entry["loc"]
			var shared : bool = (ploc > 0 and eloc >= ploc - pw and eloc <= ploc + pw) \
					or (oloc > 0 and eloc >= oloc - ow and eloc <= oloc + ow)
			if marker.texture == null or marker.get_meta("eddie_shared", null) != shared:
				marker.texture = _eddie_face(entry["mine"], 2.0 if shared else 1.0)
				if marker.texture != null:
					marker.set_meta("eddie_shared", shared)
			var full := sq - 6.0
			var esz := Vector2(full, floorf(full / 2.0) - 1.0 if shared else full) # bottom half when shared
			var eoff := Vector2(3.0, 3.0 + (full - esz.y if shared else 0.0))
			_glide_to(marker, _sq_pos(eloc) + eoff, esz, entry.get("placed", false) == false)
			entry["placed"] = true
		elif marker != null:
			var base := _sq_pos(entry["loc"])
			var marker_pos : Vector2 = base + Vector2(sq * 0.25 + entry["off"] * sq * 0.22, sq * 0.45)
			_glide_to(marker, marker_pos, Vector2(sq * 0.5, sq * 0.5), entry.get("placed", false) == false)
			entry["placed"] = true

func _make_aux_marker(ch : Character, mine : bool) -> TextureRect:
	var frames = ch.animation.sprite_frames
	if frames == null or not frames.has_animation("idle"):
		return null
	var r := TextureRect.new()
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.texture = frames.get_frame_texture("idle", 0)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.modulate = Color(1.0, 0.8, 0.8) if mine else Color(0.8, 0.85, 1.0)
	backdrop.add_child(r)
	return r

func _place_icon(icon : TextureRect, loc : int, extra_width : int, right_half : bool = false) -> void:
	if loc < 1 or loc > 9:
		icon.visible = false
		return
	var was_visible := icon.visible
	icon.visible = true
	var left := maxi(1, loc - extra_width)
	var right := mini(9, loc + extra_width)
	var span := right - left + 1
	# Sharing the space with Eddie (who has the bottom half): the portrait is cut to a band across
	# its middle so it still fills the top half.
	if right_half != icon.get_meta("half_crop", false):
		if not icon.has_meta("full_tex") or (not icon.get_meta("half_crop", false) and icon.texture != icon.get_meta("full_tex")):
			icon.set_meta("full_tex", icon.texture)
		var full_tex : Texture2D = icon.get_meta("full_tex")
		icon.texture = _portrait_crop(full_tex, 2.1) if right_half else full_tex
		icon.set_meta("half_crop", right_half)
	if right_half:
		var full := sq - 6.0
		var half := floorf(full / 2.0) - 1.0
		_glide_to(icon, _sq_pos(left) + Vector2(3.0, 3.0), Vector2(full, half), not was_visible)
		return
	_glide_to(icon, _sq_pos(left) + Vector2(3, 3), Vector2(sq * span - 6, sq - 6), not was_visible)

func _is_eddie(ch) -> bool:
	return is_instance_valid(ch) and ch.has_method("get_buddy_id") and str(ch.get_buddy_id()) == "eddie"

# Eddie's face, cut from his buddy card (the grinning head at the top of the art).
# `aspect` is the width / height of the box it fills (1 = square, 0.5 = sharing a space).
func _eddie_face(mine : bool, aspect : float = 1.0) -> Texture2D:
	var card = game.player_buddy_character_card if mine else game.opponent_buddy_character_card
	if card == null or not is_instance_valid(card) or card.fancy_card == null or card.fancy_card.texture == null:
		return null
	var tex : Texture2D = card.fancy_card.texture
	var ts := tex.get_size()
	var hgt := ts.y * 0.273
	var cy := ts.y * 0.157
	if aspect > 1.0:
		hgt = ts.y * 0.095 # a wide band: just his eyes and grin
		cy = ts.y * 0.188
	var wid := minf(hgt * aspect, ts.x)
	var at := AtlasTexture.new()
	at.atlas = tex
	at.region = Rect2(ts.x * 0.493 - wid / 2.0, cy - hgt / 2.0, wid, hgt)
	return at

# A portrait cut to its middle part, to fill a box `aspect` times as wide as it is tall.
func _portrait_crop(tex : Texture2D, aspect : float) -> Texture2D:
	if tex == null:
		return null
	var ts := tex.get_size()
	var wid := minf(ts.x, ts.y * aspect)
	var hgt := minf(ts.y, wid / aspect)
	var at := AtlasTexture.new()
	at.atlas = tex
	# A wide band sits a little above the middle, where the eyes are.
	var top := (ts.y - hgt) / 2.0 if aspect <= 1.0 else clampf(ts.y * 0.4 - hgt / 2.0, 0.0, ts.y - hgt)
	at.region = Rect2((ts.x - wid) / 2.0, top, wid, hgt)
	return at

# Eddie's arena icon: his face in a black frame.
func _make_eddie_icon(mine : bool) -> TextureRect:
	var r := _make_icon(Color(0, 0, 0))
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_meta("eddie_side", 0 if mine else 1)
	# Glows in his owner's colour while Zato is exceeded.
	r.set_meta("glow_color", (p1_icon if mine else p2_icon).get_meta("border_color", Color.WHITE))
	return r

# Smoothly slides a control to a new position / size (snaps when `snap` is set,
# e.g. on first placement or after a layout change).
func _glide_to(node : Control, pos : Vector2, new_size : Vector2, snap : bool = false) -> void:
	if node.has_meta("glide_tween"):
		var old_tween = node.get_meta("glide_tween")
		if old_tween != null and is_instance_valid(old_tween):
			old_tween.kill()
		node.remove_meta("glide_tween")
	if _snap_icons or snap or not node.is_inside_tree():
		node.position = pos
		node.size = new_size
		return
	if node.position.is_equal_approx(pos) and node.size.is_equal_approx(new_size):
		return
	var tween := node.create_tween().set_parallel(true)
	tween.tween_property(node, "position", pos, ICON_GLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(node, "size", new_size, ICON_GLIDE_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	node.set_meta("glide_tween", tween)

const ICON_GLIDE_TIME := 0.35
var _snap_icons := false

func load_portraits() -> void:
	for pair in [[game.player_deck, p1_icon], [game.opponent_deck, p2_icon]]:
		var deck_id : String = str(pair[0].get("id", "custom"))
		var candidates := ["res://assets/portraits/%s.png" % deck_id,
			"res://assets/portraits/%s.png" % deck_id.trim_prefix("custom_"),
			"res://assets/portraits/custom.png"]
		for path in candidates:
			if ResourceLoader.exists(path):
				pair[1].texture = load(path)
				break

# --------------------------------------------------------------------------
# Gauge strips
# --------------------------------------------------------------------------

func refresh_gauge() -> void:
	if not _built:
		return
	var g = game
	for side in range(2):
		var is_p := side == 0
		var zone : Node = g.get_node("AllCards/PlayerGauge" if is_p else "AllCards/OpponentGauge")
		# A card still on its way through the screen center (waiting its turn, or held there in
		# focus) has no gauge box yet: its box grows in once the focus pause is over.
		var cards := zone.get_children().filter(func(c): return not _gauge_card_in_focus_flight(c))
		var holder : Node2D = gauge_nodes[side]
		holder.z_index = 4 # above the gauge-strip button so the boxes get their own taps
		if GlobalSettings.phone_controls_active():
			if is_p:
				_gauge_slots.clear()
			# Clicks go to the last control in tree order, so the boxes must come after
			# the gauge-strip button.
			backdrop.move_child(holder, -1)
		for old in holder.get_children():
			holder.remove_child(old)
			old.queue_free()
		var slots := maxi(7, cards.size())
		var bolt_rects : Array = []
		var avail := W / 2.0 - 12.0
		var gsz := minf(avail / slots - 3.0, gauge_h - 6.0)
		var total := slots * (gsz + 3.0) - 3.0
		var x0 := 6.0 if is_p else W - 6.0 - total
		var y0 := gauge_y + (gauge_h - gsz) / 2.0
		for i in range(slots):
			var filled := i < cards.size()
			var slot := Panel.new()
			slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
			slot.add_theme_stylebox_override("panel", _style(
				Color(0.55, 0.85, 1.0) if filled else Color(0.30, 0.62, 0.85),
				Color(0.85, 0.95, 1.0) if filled else Color(0.15, 0.35, 0.6), 2, 4))
			# Your (red) gauge fills left to right; the opponent's (blue) one right to left.
			var px : int = i if is_p else slots - 1 - i
			slot.position = Vector2(x0 + px * (gsz + 3.0), y0)
			slot.size = Vector2(gsz, gsz)
			if filled and _gauge_prev_cards[side] >= 0 and i >= _gauge_prev_cards[side]:
				# A card just went to the gauge: its box grows in from the center, over an
				# empty box.
				var back := Panel.new()
				back.mouse_filter = Control.MOUSE_FILTER_IGNORE
				back.add_theme_stylebox_override("panel", _style(Color(0.30, 0.62, 0.85), Color(0.15, 0.35, 0.6), 2, 4))
				back.position = slot.position
				back.size = slot.size
				holder.add_child(back)
				slot.set_meta("grow_in", true)
			holder.add_child(slot)
			if slot.has_meta("grow_in"):
				_grow_in(slot)
			bolt_rects.append(Rect2(slot.position, slot.size))
			if i == 0 and not filled:
				slot.add_child(_gauge_g_label(side, gsz))
			if filled:
				var icon := TextureRect.new()
				icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
				icon.texture = _moon_icon(cards[i])
				icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				icon.position = Vector2(2, 2)
				icon.size = Vector2(gsz - 4, gsz - 4)
				icon.z_index = 2 # over the lightning (z 5; the boxes are z 4)
				slot.add_child(icon)
				# Special / ultra marker, centered in the gauge box.
				var gcard = cards[i]
				if gcard.badge_text != "":
					var bl := _make_badge_label(gcard, gsz)
					bl.z_index = 2 # over the lightning too
					slot.add_child(bl)
				if is_p and GlobalSettings.phone_controls_active():
					# Phone controls: tap a gauge box to select that card (while gauge can
					# be spent); long press to focus it. Otherwise the tap opens the gauge.
					var slot_card = gcard
					var slot_btn := _invisible_button()
					slot_btn.size = Vector2(gsz, gsz)
					slot.add_child(slot_btn)
					_gauge_slots.append([slot, gcard])
					_wire_tap_hold(slot_btn, func(): _gauge_slot_tap(slot_card),
							func(): _gauge_slot_hold(slot_card))
				elif GlobalSettings.phone_controls_active():
					# Opponent's gauge box: a tap or a long press focuses that card (an empty part
					# of their strip opens their gauge window).
					var oslot_card = gcard
					var oslot_btn := _invisible_button()
					oslot_btn.size = Vector2(gsz, gsz)
					slot.add_child(oslot_btn)
					_wire_tap_hold(oslot_btn, func(): _gauge_slot_hold(oslot_card),
							func(): _gauge_slot_hold(oslot_card))
		_update_gauge_bolts(side, bolt_rects, cards.size())
		_gauge_prev_cards[side] = cards.size()
		gauge_center[side] = Vector2(x0 + total / 2.0, gauge_y + gauge_h / 2.0)
		var panel = g.get_node("PlayerZones/PlayerGauge" if is_p else "OpponentZones/OpponentGauge")
		panel.center_override = gauge_center[side]

# A gauge card that hasn't finished its stop at the screen center (queued, flying there, or held
# there in focus).
func _gauge_card_in_focus_flight(c) -> bool:
	return c is CardBase and c.state == CardBase.CardState.CardState_Discarding \
			and (c.has_meta("phone_center_wait") or c.has_meta("phone_center_hold"))

# ---- Gauge "G" and lightning -----------------------------------------------------------------
# An empty gauge shows a big calligraphic "G" in its first space, in its player's color with a black
# border (the first gauge card covers it). Gauge cards send bolts of lightning along the strip
# (see gauge_bolts.gd).
const GAUGE_COLORS := [Color(0.95, 0.25, 0.2), Color(0.3, 0.45, 1.0)]
var _gauge_g_font : FontVariation = null
var _gauge_bolts : Array = [null, null]
var _gauge_prev_cards : Array = [-1, -1] # gauge size at the last refresh (new boxes grow in)

# The "G" glyph's ink box (Lavishly Yours, at font size 1000, relative to its baseline origin):
# measured from the font file, so the letter can be scaled and centered to fill its box exactly
# (script glyphs sit well off center in their line box).
const GAUGE_G_INK := Rect2(-89.0, -779.0, 841.0, 1040.0)

func _gauge_g_label(side : int, gsz : float) -> Control:
	if _gauge_g_font == null:
		_gauge_g_font = FontVariation.new()
		_gauge_g_font.base_font = load("res://fonts/LavishlyYours-Regular.ttf")
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.position = Vector2.ZERO
	c.size = Vector2(gsz, gsz)
	var outline := maxi(4, int(gsz * 0.12))
	# Fit the ink (plus its black border) inside the box, with a little room to spare.
	var room := gsz - outline - gsz * 0.08
	var fsize := int(room * 1000.0 / maxf(GAUGE_G_INK.size.x, GAUGE_G_INK.size.y))
	var k := fsize / 1000.0
	var ink_center := (GAUGE_G_INK.position + GAUGE_G_INK.size / 2.0) * k
	var baseline := Vector2(gsz, gsz) / 2.0 - ink_center
	var col : Color = GAUGE_COLORS[side]
	var font : Font = _gauge_g_font
	c.draw.connect(func():
		c.draw_string_outline(font, baseline, "G", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, outline, Color.BLACK)
		c.draw_string(font, baseline, "G", HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col))
	return c

var _gauge_bolt_clips : Array = [null, null]
# The gauge lightning (gauge_bolts.gd) is off for now; set to true to bring it back (or use it in
# a theme). The 7 boxes and the "G" stay either way.
const USE_GAUGE_BOLTS := false

func _update_gauge_bolts(side : int, rects : Array, cards : int) -> void:
	if not USE_GAUGE_BOLTS:
		return
	var bolts = _gauge_bolts[side]
	var clip : Control = _gauge_bolt_clips[side]
	if bolts == null or not is_instance_valid(bolts) or clip == null or not is_instance_valid(clip):
		# The bolts are clipped to their gauge strip, so their glow never spills over the boost
		# windows above or the arena below. They sit over the gauge boxes (z 4) and under the
		# boxes' icons (z 6) and focused cards (z 10).
		clip = Control.new()
		clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		clip.clip_contents = true
		clip.z_index = 5
		backdrop.add_child(clip)
		bolts = load("res://scenes/game/gauge_bolts.gd").new()
		clip.add_child(bolts)
		_gauge_bolts[side] = bolts
		_gauge_bolt_clips[side] = clip
	if not rects.is_empty():
		var area : Rect2 = rects[0]
		for r in rects:
			area = area.merge(r)
		clip.position = area.position - Vector2(3, 0)
		clip.size = area.size + Vector2(6, 0)
		bolts.position = -clip.position
	bolts.set_gauge(rects, cards, GAUGE_COLORS[side])

# The card-type "moon" icon is in the top-left corner of every card image.
func _moon_icon(card) -> Texture2D:
	var tex : Texture2D = card.card_url_loaded_image
	if tex == null:
		return null
	var s := tex.get_size()
	# Region in 750 x 1024 card coordinates that is centered on the icon.
	# Seasons 1-4 and 8 print the normal-attack shape in the top-right corner,
	# seasons 5-7 in the top-left.
	var mine : bool = str(card.get_parent().name).begins_with("Player")
	var deck : Dictionary = game.player_deck if mine else game.opponent_deck
	var side_hint := -1
	var season_num := 0
	if deck.has("season"):
		season_num = int(str(deck["season"]))
		if season_num >= 1 and season_num <= 8:
			side_hint = 0 if (season_num >= 5 and season_num <= 7) else 1
	var r : Rect2 = _icon_region(tex, side_hint, season_num)
	var atlas := AtlasTexture.new()
	atlas.atlas = tex
	atlas.region = Rect2(r.position.x * s.x / 750.0, r.position.y * s.y / 1024.0,
			r.size.x * s.x / 750.0, r.size.y * s.y / 1024.0)
	return atlas

var _icon_side_cache := {}

# Locates the colourful shape icon in a top corner (750 x 1024 coordinates) by
# taking the biggest connected blob of vivid pixels in a search window. Returns
# a square Rect2 centered on it, or an empty Rect2 when nothing is found.
func _find_glyph(img : Image, right_side : bool) -> Rect2:
	var w := img.get_width()
	var h := img.get_height()
	var k := w / 750.0
	var step := 4.0
	var win_w := 140.0
	var win_h := 140.0
	var y_start := 20.0
	var x_start := 750.0 - 15.0 - win_w if right_side else 15.0
	var cols := int(win_w / step)
	var rows := int(win_h / step)
	var mask := PackedByteArray()
	mask.resize(cols * rows)
	for r in range(rows):
		for c in range(cols):
			var x := int((x_start + c * step) * k)
			var y := int((y_start + r * step) * k)
			if x >= w or y >= h:
				continue
			var col := img.get_pixel(x, y)
			if col.s > 0.3 and col.v > 0.25:
				mask[r * cols + c] = 1
	var label := PackedInt32Array()
	label.resize(cols * rows)
	var best_count := 0
	var best_box := Rect2i()
	var next_label := 1
	for start in range(cols * rows):
		if mask[start] == 0 or label[start] != 0:
			continue
		var stack : Array[int] = [start]
		label[start] = next_label
		var count := 0
		var minc := cols
		var maxc := 0
		var minr := rows
		var maxr := 0
		while not stack.is_empty():
			var idx : int = stack.pop_back()
			var c := idx % cols
			var r := idx / cols
			count += 1
			minc = mini(minc, c)
			maxc = maxi(maxc, c)
			minr = mini(minr, r)
			maxr = maxi(maxr, r)
			for dr in range(-2, 3):
				for dc in range(-2, 3):
					var nc := c + dc
					var nr := r + dr
					if nc < 0 or nr < 0 or nc >= cols or nr >= rows:
						continue
					var ni := nr * cols + nc
					if mask[ni] == 1 and label[ni] == 0:
						label[ni] = next_label
						stack.append(ni)
		next_label += 1
		var bw := maxc - minc + 1
		var bh := maxr - minr + 1
		# Glyph-sized and roughly square blobs only.
		if count >= 10 and bw * step >= 40.0 and bw * step <= 150.0 and bh * step >= 40.0 and bh * step <= 150.0 and count > best_count:
			best_count = count
			best_box = Rect2i(minc, minr, bw, bh)
	if best_count == 0:
		return Rect2()
	var cx := x_start + (best_box.position.x + best_box.size.x / 2.0) * step
	var cy := y_start + (best_box.position.y + best_box.size.y / 2.0) * step
	var side := clampf(maxf(best_box.size.x, best_box.size.y) * step * 1.2, 70.0, 150.0)
	var px := clampf(cx - side / 2.0, 0.0, 750.0 - side)
	var py := maxf(cy - side / 2.0, 0.0)
	return Rect2(px, py, side, side)

# Finds which top corner holds the card-type disc. The disc has a distinctive
# signature: a bright white rim at radius ~72 with a non-white interior just
# inside it. Defaults to the left corner.
func _icon_region(tex : Texture2D, side_hint : int = -1, season : int = 0) -> Rect2:
	# Measured icon positions (center x, center y, box size) in 750 x 1024 card
	# coordinates for the seasons whose normal-attack icon sits in the top right.
	# Seasons 5-7 use the round icon at the top left (found by the code below).
	var season_icons := {
		1: Vector3(658.0, 92.0, 96.0),
		2: Vector3(674.0, 89.0, 120.0),
		3: Vector3(671.0, 89.0, 112.0),
		4: Vector3(678.0, 66.0, 128.0),
		8: Vector3(646.0, 104.0, 140.0),
	}
	if season_icons.has(season):
		var si : Vector3 = season_icons[season]
		return Rect2(si.x - si.z / 2.0, maxf(si.y - si.z / 2.0, 0.0), si.z, si.z)
	var key := tex.get_instance_id()
	if _icon_side_cache.has(key):
		return _icon_side_cache[key]
	# Default: disc icon at the top-left (144 x 136 px box centered at 72, 68).
	var result := Rect2(0.0, 0.0, 144.0, 136.0)
	var img : Image = tex.get_image()
	if img != null and not img.is_empty():
		var w := img.get_width()
		var h := img.get_height()
		var k := w / 750.0
		var scores := []
		for cx_base in [72.0, 750.0 - 72.0]:
			var rim := 0.0
			var inner := 0.0
			var n_rim := 0
			var n_inner := 0
			for a in range(0, 360, 5):
				for r in [64.0, 68.0, 72.0]:
					var x := int((cx_base + r * cos(deg_to_rad(a))) * k)
					var y := int((68.0 + r * sin(deg_to_rad(a))) * k)
					if x < 0 or y < 0 or x >= w or y >= h:
						continue
					var col := img.get_pixel(x, y)
					var white : bool = col.v > 0.85 and col.s < 0.2
					if r == 72.0:
						n_rim += 1
						if white:
							rim += 1.0
					else:
						n_inner += 1
						if white:
							inner += 1.0
			scores.append(rim / maxf(n_rim, 1.0) - inner / maxf(n_inner, 1.0))
		# When the season says the icon is on the left (seasons 5-7), only the left corner
		# counts: pale art in the right corner (e.g. the sky on Chipp's Slash) can look like a
		# white disc rim.
		var disc_score : float = scores[0] if side_hint == 0 else maxf(scores[0], scores[1])
		if side_hint != 1 and disc_score >= 0.08:
			# Disc-style icon (white rim). Right corner box is mirrored.
			if side_hint < 0 and scores[1] > scores[0] + 0.05:
				result = Rect2(750.0 - 144.0, 0.0, 144.0, 136.0)
		else:
			# Plain-glyph icon (no disc): it is the colourful blob in one of the
			# top corners, centered about (79, 89) from the left edge or the
			# mirror of that from the right edge. Compare colourfulness.
			var right_side : bool = side_hint == 1
			if side_hint < 0:
				var glyph := []
				for cx_base in [0.105 * 750.0, 0.895 * 750.0]:
					var hit := 0
					var n := 0
					for dy in range(-34, 35, 3):
						for dx in range(-38, 39, 3):
							var x := int((cx_base + dx) * k)
							var y := int((89.0 + dy) * k)
							if x < 0 or y < 0 or x >= w or y >= h:
								continue
							n += 1
							var col := img.get_pixel(x, y)
							if col.s > 0.3 and col.v > 0.2:
								hit += 1
					glyph.append(float(hit) / maxf(n, 1.0))
				right_side = glyph[1] > glyph[0] + 0.12
			var found : Rect2 = _find_glyph(img, right_side)
			if found.size.x > 0.0:
				result = found
			else:
				var gx := 0.895 * 750.0 if right_side else 0.105 * 750.0
				result = Rect2(gx - 56.0, 33.0, 112.0, 112.0)
	_icon_side_cache[key] = result
	return result

# --------------------------------------------------------------------------
# Bottom bar
# --------------------------------------------------------------------------

func on_game_ready() -> void:
	if not _built:
		return
	var g = game
	load_portraits()
	var res = g.player_deck.get("image_resources", {})
	if res.has("cardback"):
		var back : Texture2D = await g.image_loader.get_card_image(res["cardback"]["url"], 0)
		for r in [sealed_rect, deck_rect, discard_rect, hand_pile_rects[0]]:
			if r != null:
				r.texture = back
	if player_name_label != null:
		var pname : String = str(g.game_wrapper.get_player_name(Enums.PlayerId.PlayerId_Player))
		# Offline (vs CPU) games use a placeholder name; show the main-menu name instead.
		if g.game_wrapper.is_ai_game() and GlobalSettings.DefaultPlayerName != "":
			pname = GlobalSettings.DefaultPlayerName
		player_name_label.text = pname
		g.opponent_name_label.text = str(g.game_wrapper.get_player_name(Enums.PlayerId.PlayerId_Opponent))
	var ores = g.opponent_deck.get("image_resources", {})
	if ores.has("cardback"):
		var oback : Texture2D = await g.image_loader.get_card_image(ores["cardback"]["url"], 0)
		for r in [osealed_rect, odeck_rect, odiscard_rect, hand_pile_rects[1]]:
			if r != null:
				r.texture = oback
	var deck = g.player_deck
	var on_exceed_text := ""
	if 'on_exceed' in deck:
		on_exceed_text = GameStrings.get_on_exceed_text(deck['on_exceed'])
	ability_text = on_exceed_text + GameStrings.get_effects_text(deck['ability_effects'])
	exceed_ability_text = GameStrings.get_effects_text(deck['exceed_ability_effects'])
	# Characters with their card's printed wording on file (see PERMANENT_BONUS_TEXT) show
	# that same wording here too.
	var did := str(deck.get("id", ""))
	if PRINTED_ABILITY_TEXT.has(did):
		# Exactly as it is printed on the card (a null side keeps the generated text).
		if PRINTED_ABILITY_TEXT[did][0] != null:
			ability_text = PRINTED_ABILITY_TEXT[did][0]
		if PRINTED_ABILITY_TEXT[did][1] != null:
			exceed_ability_text = PRINTED_ABILITY_TEXT[did][1]
	elif PERMANENT_BONUS_TEXT.has(did) and did in PERMANENT_BONUS_CHARACTERS:
		ability_text = on_exceed_text + PERMANENT_BONUS_TEXT[did][0]
		exceed_ability_text = PERMANENT_BONUS_TEXT[did][1]
	_exceed_note = _exceed_lines_of(ability_text)
	refresh_counts()
	update_strip()
	_prewarm_icons()

# Works out every card's gauge icon ahead of time, a few per frame, so the first time a list
# window (deck, gauge, discard...) opens it doesn't have to stop and read the card pictures.
var _prewarm_started : bool = false
var _backdrop_scripts : Array = [] # (kept loaded)
func _prewarm_icons() -> void:
	if _prewarm_started:
		return
	_prewarm_started = true
	# The window backdrops too: loading a backdrop script the first time a window opens costs
	# a moment on a phone.
	for key in WINDOW_THEMES[window_theme]:
		_backdrop_scripts.append(load(WINDOW_THEMES[window_theme][key]))
		await get_tree().process_frame
	for zone_name in ["AllCards/PlayerAllCopy", "AllCards/OpponentAllCopy"]:
		var zone = game.get_node_or_null(zone_name)
		if zone == null:
			continue
		for card in zone.get_children():
			if not (card is CardBase) or card.card_id < 0:
				continue
			var tries := 0
			while is_instance_valid(card) and card.card_url_loaded_image == null and tries < 120:
				await get_tree().process_frame
				tries += 1
			if is_instance_valid(card) and card.card_url_loaded_image != null:
				_moon_icon(card)
			await get_tree().process_frame
		await get_tree().process_frame

func refresh_counts() -> void:
	if not _built:
		return
	var g = game
	var gw = g.game_wrapper
	if gw.current_game == null:
		return
	var me := Enums.PlayerId.PlayerId_Player
	var opp := Enums.PlayerId.PlayerId_Opponent
	if hand_labels[0] != null:
		hand_labels[0].text = str(gw.get_player_hand_size(me))
		hand_labels[1].text = str(gw.get_player_hand_size(opp))
	if hand_pile_labels[0] != null:
		hand_pile_labels[0].text = str(gw.get_player_hand_size(me))
		hand_pile_labels[1].text = str(gw.get_player_hand_size(opp))
	deck_label.text = str(gw.get_player_deck_size(me))
	discard_label.text = str(gw.get_player_discards_size(me))
	var has_sealed : bool = 'has_sealed_area' in g.player_deck and g.player_deck['has_sealed_area']
	sealed_label.text = str(gw.get_player_sealed_size(me))
	sealed_rect.modulate.a = 1.0 if has_sealed else 0.35
	var exceeded : bool = gw.is_player_exceeded(me)
	var text := exceed_ability_text if (exceeded and exceed_ability_text != "") else ability_text
	# ("When you Exceed" effects aren't shown here: the bonus box shows them on your turn, while
	# you have the gauge to exceed. See _update_exceed_note.)
	text = _without_exceed_lines(text)
	var shown := "[center]%s[/center]" % text
	if ability_label.text != shown:
		ability_label.text = shown

	var od_p : bool = g.is_player_overdrive_visible(me)
	var od_o : bool = g.is_player_overdrive_visible(opp)
	overdrive_buttons[0].visible = od_p
	overdrive_buttons[0].text = "Overdrive: %d" % gw.get_player_overdrive_size(me)
	overdrive_buttons[1].visible = od_o
	overdrive_buttons[1].text = "Overdrive: %d" % gw.get_player_overdrive_size(opp)
	var opp_sealed : bool = 'has_sealed_area' in g.opponent_deck and g.opponent_deck['has_sealed_area']
	opp_sealed_button.visible = false
	odeck_label.text = str(gw.get_player_deck_size(opp))
	odiscard_label.text = str(gw.get_player_discards_size(opp))
	osealed_label.text = str(gw.get_player_sealed_size(opp))
	osealed_rect.modulate.a = 1.0 if opp_sealed else 0.35

	if save_replay_menu_button != null:
		save_replay_menu_button.visible = g.replay_saving_enabled

func refresh_all() -> void:
	update_strip()
	refresh_gauge()
	refresh_counts()
	layout_hand()

# --------------------------------------------------------------------------
# Hand + focus preview
# --------------------------------------------------------------------------

# Hand cards get rounded corners (a shader on the card face, back and black backing); a card
# that leaves the hand goes back to square corners.
var _rounded_card_mat : ShaderMaterial = null

func _rounded_mat() -> ShaderMaterial:
	if _rounded_card_mat == null:
		_rounded_card_mat = ShaderMaterial.new()
		_rounded_card_mat.shader = load("res://scenes/card/rounded_card.gdshader")
		_rounded_card_mat.set_shader_parameter("radius", 0.06)
		_rounded_card_mat.set_shader_parameter("aspect", CARD_H / CARD_W)
	return _rounded_card_mat

func _set_card_rounded(card, on : bool) -> void:
	if not is_instance_valid(card) or bool(card.get_meta("phone_rounded", false)) == on:
		return
	card.set_meta("phone_rounded", on)
	var mat : Material = _rounded_mat() if on else null
	for path in ["CardFocusFeatures/CardContainer/Background",
			"CardFocusFeatures/CardContainer/CardFront/FancyCard",
			"CardFocusFeatures/CardContainer/CardBack"]:
		var n := card.get_node_or_null(path) as CanvasItem
		if n != null:
			n.material = mat

func _update_rounded_hand_cards() -> void:
	var g = game
	var hand : Node = g.get_hand_zone(true)
	for card in hand.get_children():
		_set_card_rounded(card, true)
	var all = g.get_node_or_null("AllCards")
	if all == null:
		return
	for zone in all.get_children():
		if zone == hand:
			continue
		for card in zone.get_children():
			if card is CardBase and bool(card.get_meta("phone_rounded", false)):
				_set_card_rounded(card, false)

func layout_hand() -> void:
	var g = game
	var zone : Node2D = g.get_hand_zone(true)
	_update_rounded_hand_cards()
	var count := zone.get_child_count()
	if count == 0:
		g.update_card_counts()
		return
	g.update_eyes_on_hand_icons()
	if count > 1:
		g.sort_player_hand(zone)
	var card_w := CARD_W * hand_scale
	var card_h := CARD_H * hand_scale
	var margin := 10.0
	var step := card_w
	if count > 1:
		step = clampf((W - 2.0 * margin - card_w) / (count - 1), 34.0, card_w * 0.55)
	var total := card_w + step * (count - 1)
	var x0 := (W - total) / 2.0 + card_w / 2.0
	var y := hand_y + 8.0 + card_h / 2.0
	for i in range(count):
		var card : CardBase = zone.get_child(i)
		card.default_scale = Vector2(hand_scale, hand_scale)
		if count > 1 and card.state != CardBase.CardState.CardState_Focusing:
			card.change_state(CardBase.CardState.CardState_InHand)
		card.set_resting_position(Vector2(x0 + step * i, y), 0)
	g.update_card_counts()

# Called from Game.on_card_clicked. Returns true when the tap was only a
# focus/preview change and must not toggle selection.
func intercept_card_click(card) -> bool:
	var g = game
	if _selecting:
		return false
	if GlobalSettings.phone_controls_active():
		# Phone controls: a short tap on a hand card selects it (no focus); while a
		# card is focused, a short tap puts it back.
		if focused_card != null and is_instance_valid(focused_card):
			if focused_card == card and card.get_parent() == g.get_hand_zone(true) \
					and _can_toggle_selection(card):
				_on_select_pressed()
			else:
				clear_focus()
			return true
		if card.get_parent() == g.get_hand_zone(true):
			return false
	if card.get_parent() != g.get_hand_zone(true):
		# A card underneath the enlarged preview (e.g. a strike card): the tap was
		# meant for the preview, so minimize it.
		if focused_card != null and is_instance_valid(focused_card):
			clear_focus()
			return true
		return false
	if focused_card == card:
		if _selecting:
			return false # the Select / Deselect button toggles selection
		# Tapping the enlarged card itself selects / deselects it (when it can be) and
		# minimizes it, as with phone controls.
		if _can_toggle_selection(card):
			_on_select_pressed()
		clear_focus()
		return true
	var s : int = card.state
	if s != CardBase.CardState.CardState_InHand and s != CardBase.CardState.CardState_Unfocusing:
		return true
	if focused_card != null and is_instance_valid(focused_card):
		focused_card.unfocus()
	focused_card = card
	card.focus()
	_set_preview_visible(true)
	_refresh_select_button()
	return true

var _preview_press_token : int = 0
var _preview_long_fired : bool = false

func _on_preview_tap() -> void:
	if _preview_long_fired:
		_preview_long_fired = false
		return
	# A short tap on the enlarged hand card toggles its selection (with or without phone
	# controls, so focusing works the same way in both).
	if focused_card != null \
			and is_instance_valid(focused_card) \
			and focused_card.get_parent() == game.get_hand_zone(true) \
			and _can_toggle_selection(focused_card):
		# A tap ON the card selects / deselects it and unfocuses it in one go; a tap
		# anywhere else just unfocuses.
		var csize := Vector2(CARD_W, CARD_H) * CardBase.phone_focus_scale.x
		var on_card := Rect2(CardBase.phone_focus_center - csize / 2.0, csize).has_point(backdrop.get_local_mouse_position())
		if on_card:
			_on_select_pressed()
	clear_focus()

# True when tapping this card would select / deselect it right now (a card that
# is not relevant to the current action cannot be selected, so a tap unfocuses it).
func _can_toggle_selection(card) -> bool:
	var g = game
	if card == null or not is_instance_valid(card) or g.observer_mode:
		return false
	if g.ui_state != g.UIState.UIState_SelectCards and g.ui_state != g.UIState.UIState_PickTurnAction:
		return false
	return card.selected or g.can_select_card(card)

func _on_popout_preview_tap() -> void:
	if _popout_long_fired:
		_popout_long_fired = false
		return
	if GlobalSettings.phone_controls_active():
		var board_card = game.find_card_on_board(popout_preview_id)
		var gauge_locked : bool = game.ui_state != game.UIState.UIState_SelectCards \
				and game.game_wrapper.is_card_in_gauge(Enums.PlayerId.PlayerId_Player, popout_preview_id)
		# A focused gauge card works like a focused hand card while gauge can be picked: a tap
		# on the card toggles its selection and closes the view; a tap elsewhere just closes it.
		if _preview_from_gauge and game.ui_state == game.UIState.UIState_SelectCards \
				and _can_toggle_selection(board_card):
			var gsc : float = CardBase.phone_focus_scale.x
			var gsize := Vector2(CARD_W, CARD_H) * gsc
			var on_gcard := Rect2(CardBase.phone_focus_center - gsize / 2.0, gsize).has_point(game.get_global_mouse_position())
			close_popout_preview()
			if on_gcard:
				game.on_card_clicked(board_card)
			return
		# Otherwise a preview opened from a gauge box is just a look at the card: a tap closes it
		# (select / unselect with a tap on the box itself).
		# A hand card's focused view: a tap ON the card selects it and closes the view in one
		# go; a tap anywhere else (or a long press) just closes it.
		if _popout_can_select and not gauge_locked and not _preview_keep and _can_toggle_selection(board_card):
			var sc : float = CardBase.phone_focus_scale.x
			var csize := Vector2(CARD_W, CARD_H) * sc
			var on_card := Rect2(CardBase.phone_focus_center - csize / 2.0, csize).has_point(game.get_global_mouse_position())
			if on_card:
				_on_popout_select_pressed()
			close_popout_preview()
			return
	close_popout_preview()

func _on_popout_preview_down() -> void:
	_popout_long_fired = false
	_popout_press_token += 1
	var token := _popout_press_token
	get_tree().create_timer(CardBase.PhoneLongPressTime).timeout.connect(func():
		if token == _popout_press_token and is_instance_valid(_popout_close_btn) \
				and _popout_close_btn.button_pressed:
			_popout_long_fired = true
			close_popout_preview())

# --------------------------------------------------------------------------
# Phone controls phase 3: tap / long-press shortcuts
# --------------------------------------------------------------------------
# A pulsing outline around your gauge while gauge cards may be spent on the
# current action (a reminder that gauge can be selected).
var _gauge_hl : Panel = null
var _gauge_hl_timer : float = 0.0
var _gauge_hl_on : bool = false

func _update_gauge_highlight(delta : float) -> void:
	if _gauge_hl == null or not is_instance_valid(_gauge_hl):
		_gauge_hl = Panel.new()
		_gauge_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_gauge_hl.add_theme_stylebox_override("panel", _style(Color(1, 0.9, 0.2, 0.10), Color(1, 0.9, 0.2), 5, 6))
		_gauge_hl.z_index = 6
		_gauge_hl.visible = false
		backdrop.add_child(_gauge_hl)
	_gauge_hl.position = Vector2(2, gauge_y + 1)
	_gauge_hl.size = Vector2(W / 2.0 - 4.0, gauge_h - 2.0)
	_gauge_hl_timer -= delta
	if _gauge_hl_timer <= 0.0:
		_gauge_hl_timer = 0.15
		_gauge_hl_on = _gauge_selectable()
	_gauge_hl.visible = _gauge_hl_on
	if _gauge_hl_on:
		_gauge_hl.modulate.a = 0.75 + 0.25 * sin(Time.get_ticks_msec() / 220.0)

func _gauge_selectable() -> bool:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_SelectCards:
		return false
	var zone = g.get_node_or_null("AllCards/PlayerGauge")
	if zone == null:
		return false
	for c in zone.get_children():
		if c is CardBase and g.can_select_card(c):
			return true
	return false

var _manual_gauge_open : bool = false

# True when the game wants to open the gauge popup on its own (phone controls
# never do that; tapping the gauge strip itself still opens it).
func suppress_gauge_popout() -> bool:
	return GlobalSettings.phone_controls_active() and not _manual_gauge_open

# ---- Phase 4: gauge boxes, move taps, help popup -------------------------------
var arena_sq_btns : Array = []
var help_btn : Button = null
var help_root : Node2D = null
var _move_hl : Panel = null

var _gauge_slots : Array = []

# Selected gauge cards get a bright outline in their box, like selected hand cards.
func _update_gauge_selection_outline() -> void:
	for entry in _gauge_slots:
		var slot : Panel = entry[0]
		var card = entry[1]
		if not is_instance_valid(slot):
			continue
		var sel : bool = is_instance_valid(card) and card.selected
		if sel == bool(slot.get_meta("gsel", false)):
			continue
		slot.set_meta("gsel", sel)
		# A border drawn above the gauge bar's glow, so selected boxes stand out from it.
		if slot.has_meta("gsel_ov"):
			var ov = slot.get_meta("gsel_ov")
			if is_instance_valid(ov):
				ov.queue_free()
			slot.remove_meta("gsel_ov")
		if sel:
			var ovp := Panel.new()
			ovp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			ovp.z_as_relative = false
			ovp.z_index = 30
			ovp.add_theme_stylebox_override("panel", _style(Color(1.0, 0.2, 0.8, 0.18), Color(1.0, 0.2, 0.8), 6, 5))
			ovp.position = Vector2(-2, -2)
			ovp.size = slot.size + Vector2(4, 4)
			slot.add_child(ovp)
			slot.set_meta("gsel_ov", ovp)
		if sel:
			slot.add_theme_stylebox_override("panel", _style(Color(1.0, 0.75, 0.95), Color(1.0, 0.2, 0.8), 5, 4))
		else:
			slot.add_theme_stylebox_override("panel", _style(Color(0.55, 0.85, 1.0), Color(0.85, 0.95, 1.0), 2, 4))

func _nearest_gauge_card(pos : Vector2):
	var best = null
	var best_d := INF
	for entry in _gauge_slots:
		var slot : Panel = entry[0]
		if not is_instance_valid(slot) or not is_instance_valid(entry[1]):
			continue
		var r : Rect2 = slot.get_global_rect()
		var d : float = absf(r.get_center().x - pos.x)
		# (only a box right next to the tap: the very edge, or a gap between boxes)
		if d < best_d and d <= r.size.x:
			best_d = d
			best = entry[1]
	return best

func _gauge_slot_tap(card) -> void:
	if not is_instance_valid(card):
		return
	# Gauge boxes only select while the gauge is glowing (a gauge-spending prompt is up);
	# selected ones can always be tapped again to unselect, even once the requirement is met.
	if game.ui_state == game.UIState.UIState_SelectCards and _can_toggle_selection(card):
		game.on_card_clicked(card)
	else:
		# Not selecting gauge right now: focus that card (an empty part of the strip still
		# opens the gauge window).
		_gauge_slot_hold(card)

func _gauge_slot_hold(card) -> void:
	if is_instance_valid(card):
		if show_popout_preview(card.card_id):
			_preview_keep = true
			_preview_from_gauge = true
			if card.selected:
				# Focused while selected: the same bright pink border as a selected gauge box.
				var sc : float = CardBase.phone_focus_scale.x
				var csize := Vector2(CARD_W, CARD_H) * sc
				var ring := Panel.new()
				ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
				ring.add_theme_stylebox_override("panel", _style(Color(1.0, 0.2, 0.8, 0.12), Color(1.0, 0.2, 0.8), 6, 8))
				ring.position = CardBase.phone_focus_center - csize / 2.0 - Vector2(6, 6)
				ring.size = csize + Vector2(12, 12)
				popout_preview_root.add_child(ring)

# A tap on a character's icon while a list of move options is up: picks the option that
# leaves that character where it is (blocked push / pull / advance / retreat).
func _choice_tap_on_character(pid : int) -> bool:
	var mcm := _move_choice_map()
	if mcm.is_empty():
		return false
	var loc : int = game.game_wrapper.get_player_location(pid)
	if loc in mcm["dest"]:
		game.action_menu._on_choice_pressed(mcm["dest"][loc])
	return true

# Tap on an arena space that holds neither character: choose Move to that space.
func _square_tap(loc : int) -> void:
	var g = game
	# An option list of moves (Grasp...): the tapped landing space picks its option.
	var mcm := _move_choice_map()
	if not mcm.is_empty():
		if loc in mcm["dest"]:
			g.action_menu._on_choice_pressed(mcm["dest"][loc])
		return
	# A move choice from an effect (boost, strike card like grasp...): tap a highlighted space.
	if g.ui_state == g.UIState.UIState_SelectArenaLocation and not g.observer_mode:
		if loc in g.arena_locations_clickable:
			g._on_arena_location_pressed(loc)
		return
	if g.observer_mode or g.ui_state != g.UIState.UIState_PickTurnAction:
		return
	if not _menu_action("Move"):
		return
	for _i in range(20):
		await get_tree().process_frame
		if g.ui_state == g.UIState.UIState_SelectArenaLocation:
			break
	if g.ui_state == g.UIState.UIState_SelectArenaLocation and loc in g.arena_locations_clickable:
		g._on_arena_location_pressed(loc)

# Spaces that can be picked right now (move / placement choices) pulse with a green outline.
var _choice_hls : Array = []

func _update_choice_highlights() -> void:
	var g = game
	if _choice_hls.is_empty():
		for i in range(9):
			var p := Panel.new()
			p.mouse_filter = Control.MOUSE_FILTER_IGNORE
			p.add_theme_stylebox_override("panel", _style(Color(0.2, 1.0, 0.5, 0.22), Color(0.2, 1.0, 0.5), 5, 4))
			p.z_index = 5
			p.visible = false
			backdrop.add_child(p)
			_choice_hls.append(p)
	var on : bool = g.ui_state == g.UIState.UIState_SelectArenaLocation and not g.observer_mode
	var pulse := 0.75 + 0.25 * sin(Time.get_ticks_msec() / 200.0)
	var mcm := _move_choice_map()
	# Tinted in the color of the character being moved (green when it isn't a move, or both).
	var tint := _choice_tint(on, mcm)
	if tint != _choice_hl_tint:
		_choice_hl_tint = tint
		for hp in _choice_hls:
			hp.add_theme_stylebox_override("panel", _style(Color(tint, 0.22), tint, 5, 4))
	for i in range(9):
		var p : Panel = _choice_hls[i]
		var show_it : bool = (on and (i + 1) in g.arena_locations_clickable) or (not mcm.is_empty() and (i + 1) in mcm["dest"])
		p.visible = show_it
		if show_it:
			p.position = _sq_pos(i + 1)
			p.size = Vector2(sq, sq)
			p.modulate.a = pulse

var _choice_hl_tint : Color = Color(0.2, 1.0, 0.5)

# The colors of the two sides: you are red when you went first, blue otherwise.
func _side_color(is_player : bool) -> Color:
	var red := is_player == _player_first
	return Color(1.0, 0.3, 0.25) if red else Color(0.35, 0.55, 1.0)

func _choice_tint(arena_on : bool, mcm : Dictionary) -> Color:
	var green := Color(0.2, 1.0, 0.5)
	var g = game
	if not mcm.is_empty():
		if bool(mcm["moves_opponent"]):
			return _side_color(false)
		# Your own moves, unless some options move the opponent instead (then: green).
		var di = g.game_wrapper.get_decision_info()
		if di != null:
			for e in di.choice:
				if e is Dictionary and str(e.get("effect_type", "")) in ["push", "pull"]:
					return green
		return _side_color(true)
	if not arena_on:
		return green
	if g.ui_sub_state == g.UISubState.UISubState_SelectCards_MoveActionGenerateForce:
		return _side_color(true) # your Move action
	var di2 = g.game_wrapper.get_decision_info()
	var et := str(di2.effect_type) if di2 != null else ""
	if et in [StrikeEffects.PushOrPullToSpace, StrikeEffects.PullToSpaceAndGainPower]:
		return _side_color(false)
	if et == StrikeEffects.MoveToSpace:
		return _side_color(true)
	return green

# Outline on the space chosen for a move while its force is being paid.
func _update_move_highlight() -> void:
	var g = game
	if _move_hl == null or not is_instance_valid(_move_hl):
		_move_hl = Panel.new()
		_move_hl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_move_hl.add_theme_stylebox_override("panel", _style(Color(1, 0.9, 0.2, 0.25), Color(1, 0.9, 0.2), 5, 4))
		_move_hl.z_index = 5
		_move_hl.visible = false
		backdrop.add_child(_move_hl)
	var loc : int = int(g.selected_arena_location)
	var on : bool = g.ui_sub_state == g.UISubState.UISubState_SelectCards_MoveActionGenerateForce and loc >= 1 and loc <= 9
	_move_hl.visible = on
	if on:
		_move_hl.position = _sq_pos(loc)
		_move_hl.size = Vector2(sq, sq)

func _place_phone_extras() -> void:
	if arena_sq_btns.is_empty():
		return
	for i in range(9):
		var b : Button = arena_sq_btns[i]
		b.position = _sq_pos(i + 1)
		b.size = Vector2(sq, sq)
	var slot := _bottom_slot_size()
	var discard_pos := Vector2(W - 8 - slot.x, bottom_y + (bottom_h - slot.y) / 2.0)
	var hs := 40.0
	help_btn.size = Vector2(hs, hs)
	help_btn.position = Vector2(discard_pos.x + slot.x - hs, discard_pos.y - hs - 4.0)

const HELP_LINES := [
	"[b]Prepare[/b]: tap your hand icon (next to your deck)",
	"[b]Deck[/b]: long press for your deck reference; tap to pick a Wild Swing (on your turn, it starts a strike), then O to confirm",
	"[b]Change Cards[/b]: tap your discard pile",
	"[b]Move[/b]: tap an empty arena space",
	"[b]Exceed[/b]: tap your icon on the arena",
	"[b]Manual Reshuffle[/b]: long press your hand icon",
	"[b]Boost[/b]: tap your red area",
	"[b]Strike[/b]: tap the opponent's blue area",
	"[b]Character action[/b]: tap the ability box",
	"[b]Your character cards[/b]: long press your icon on the arena",
	"[b]Opponent's character cards[/b]: tap or long press their icon on the arena",
	"[b]Deck reference[/b]: long press your deck",
	"[b]Discard pile[/b]: long press your discard pile (or tap it when you can't take an action)",
	"[b]Opponent's discard[/b]: tap or long press to see the whole pile",
	"[b]Cards[/b]: tap to select, long press to focus; when focused, tap to select, long press to unfocus",
	"[b]Gauge[/b]: when outlined, tap a gauge box to spend it, long press to focus it",
	"[b]Opponent's gauge[/b]: long press a gauge box to focus it",
	"[b]Confirm / cancel[/b]: the green O / red X box at the bottom",
]

func show_help() -> void:
	if help_root != null and is_instance_valid(help_root):
		close_help()
		return
	help_root = Node2D.new()
	help_root.z_index = 90
	game.add_child(help_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.7)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.size = Vector2(W, H)
	help_root.add_child(dim)
	var close_btn := _flat_button(help_root, close_help)
	close_btn.size = Vector2(W, H)
	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _style(Color(0.08, 0.09, 0.14, 0.98), Color(1, 1, 1, 0.6), 2, 14)
	sb.content_margin_left = 20
	sb.content_margin_right = 20
	sb.content_margin_top = 16
	sb.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", sb)
	var rt := RichTextLabel.new()
	rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rt.bbcode_enabled = true
	rt.fit_content = true
	rt.scroll_active = false
	rt.custom_minimum_size = Vector2(W - 80.0, 0)
	for k in ["normal_font_size", "bold_font_size"]:
		rt.add_theme_font_size_override(k, 24)
	var text := "[b]Phone controls[/b] (tap anywhere to close)\n\n"
	for line in HELP_LINES:
		text += "•  " + line + "\n"
	rt.text = text
	panel.add_child(rt)
	help_root.add_child(panel)
	panel.position = Vector2(20, top_h + 20)

func close_help() -> void:
	if help_root != null and is_instance_valid(help_root):
		help_root.queue_free()
	help_root = null

var arena_btn_p : Button = null
var arena_btn_o : Button = null
var char_review_root : Node2D = null

func _place_arena_button(btn : Button, loc : int, extra_width : int) -> void:
	if btn == null:
		return
	if loc < 1 or loc > 9:
		btn.visible = false
		return
	btn.visible = true
	var left := maxi(1, loc - extra_width)
	var right := mini(9, loc + extra_width)
	btn.position = _sq_pos(left)
	btn.size = Vector2(sq * (right - left + 1), sq)

# Wires `btn` so a short press runs `tap` and a long press runs `hold` (not both).
func _wire_tap_hold(btn : BaseButton, tap : Callable, hold : Callable) -> void:
	for c in btn.pressed.get_connections():
		btn.pressed.disconnect(c.callable)
	var st := {"token": 0, "fired": false}
	if not hold.is_null():
		# Weak reference: the button may be freed (its window closed) before the timer fires.
		var btn_ref : WeakRef = weakref(btn)
		btn.button_down.connect(func():
			st["fired"] = false
			st["token"] += 1
			var t : int = st["token"]
			get_tree().create_timer(CardBase.PhoneLongPressTime).timeout.connect(func():
				var b = btn_ref.get_ref()
				if t == st["token"] and b != null and b.button_pressed:
					st["fired"] = true
					hold.call()))
		btn.button_up.connect(func(): st["token"] += 1)
	btn.pressed.connect(func():
		if st["fired"]:
			st["fired"] = false
			return
		tap.call())

# Presses the turn-menu choice whose text starts with `prefix` (if it is enabled).
func _menu_action(prefix : String, any_state : bool = false) -> bool:
	var g = game
	if g.observer_mode:
		return false
	if not any_state and g.ui_state != g.UIState.UIState_PickTurnAction:
		return false
	var choices : Array = g.current_action_menu_choices
	for i in range(choices.size()):
		if str(choices[i].get("text", "")).begins_with(prefix):
			if choices[i].get("disabled", false):
				return false
			g.action_menu._on_choice_pressed(i)
			return true
	return false

# The index of a character action that is a strike, for characters whose strikes are meant to be
# started with it (deck flag warn_when_striking_without_character_action); -1 if none.
func _strike_action_index() -> int:
	var g = game
	if _strike_prompt_up and not str(g.action_menu.instructions_label.text).contains("Use your character ability"):
		_strike_prompt_up = false # (something else replaced the question)
	if _strike_prompt_up:
		return 0 # (the question is already up: the tap backs out of it)
	if not g._should_warn_about_skipping_strike_character_action():
		return -1
	var gw = g.game_wrapper
	for i in range(gw.get_player_character_action_count(Enums.PlayerId.PlayerId_Player)):
		var ca = gw.get_player_character_action(Enums.PlayerId.PlayerId_Player, i)
		if not gw.can_do_character_action(Enums.PlayerId.PlayerId_Player, i):
			continue
		# (Its effect is a strike, e.g. Giovanna's: free on her front side, 1 Gauge exceeded.)
		var eff = ca.get("effect", {})
		while eff is Dictionary and not eff.is_empty():
			if str(eff.get("effect_type", "")) == "strike":
				return i
			eff = eff.get("and", {})
	return -1

var _strike_prompt_up : bool = false

# ---- A wild swing picked with the deck ------------------------------------------------------
# Tapping your deck while choosing a strike card picks the wild swing: the island's O lights up
# (it wild swings), X lets it go, and the mini banner reads STRIKE (WILD SWING). Picking a card
# lets it go too. On your turn, tapping the deck starts a strike this way.
var _ws_pending : bool = false
var _ws_pending_at : int = 0
const WS_PENDING_WAIT_MS := 1500 # (for the strike's card choice to come up after the deck tap)

var _ws_through_action : bool = false # (armed for a strike started with the character action: it
	# waits through the action's cost, until the card choice comes up or you're back at the turn menu)
var _ws_prompt : bool = false # (the "use your character ability?" question came from a deck tap)

func _ws_pending_live() -> bool:
	if not _ws_pending:
		return false
	var g = game
	if not g.selected_cards.is_empty() and _is_strike_pick():
		_ws_pending = false # (a card was picked instead)
		return false
	if not _is_strike_pick():
		var waiting_on_action : bool = _ws_through_action and g.ui_state != g.UIState.UIState_PickTurnAction \
				and Time.get_ticks_msec() - _ws_pending_at < 60000
		if not waiting_on_action and Time.get_ticks_msec() - _ws_pending_at > WS_PENDING_WAIT_MS:
			_ws_pending = false
			_ws_through_action = false
		return false
	_ws_through_action = false
	return true

func _arm_wild_swing(through_action : bool) -> void:
	_ws_pending = true
	_ws_pending_at = Time.get_ticks_msec()
	_ws_through_action = through_action

func _pick_wild_swing() -> void:
	var g = game
	if _ws_pending_live():
		# Tapping the deck again lets the wild swing go (still choosing a strike card).
		_ws_pending = false
		g._update_buttons()
		return
	if not g.selected_cards.is_empty():
		g.deselect_all_cards()
	_ws_pending = true
	_ws_pending_at = Time.get_ticks_msec()
	g._update_buttons()

func _start_wild_swing_strike() -> bool:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_PickTurnAction:
		return false
	# Characters whose strikes are meant to start with their character action (Giovanna): the
	# island asks first, as for the blue area (a second tap backs out of the question).
	if _strike_action_index() >= 0:
		_ask_strike_with_action(true)
		return true
	_arm_wild_swing(false)
	if _menu_action("Strike"):
		return true
	_ws_pending = false
	return false

# The island asks: strike with the character ability (O) or a plain strike (X)? Tapping the
# blue area again backs out to the turn menu. Works whether a card was picked first or not.
# `wild`: asked from a deck tap: either way, the strike's card choice comes up with the wild swing
# picked (waiting for O).
func _ask_strike_with_action(wild : bool = false) -> void:
	var g = game
	if _strike_prompt_up:
		_strike_prompt_up = false
		_ws_prompt = false
		g._update_buttons()
		return
	var action_idx := _strike_action_index()
	if action_idx < 0:
		return
	# The card(s) already picked from your hand (one, or two for an EX strike).
	var picked : Array = []
	if wild:
		g.deselect_all_cards()
	else:
		for c in g.selected_cards:
			if is_instance_valid(c) and g.game_wrapper.is_card_in_hand(Enums.PlayerId.PlayerId_Player, c.card_id):
				picked.append(c.card_id)
	_strike_prompt_up = true
	_ws_prompt = wild
	var use_it := func():
		_strike_prompt_up = false
		_ws_prompt = false
		if wild:
			_arm_wild_swing(true) # (through the action's cost, if it has one)
		_strike_with_action(action_idx, picked)
	var plain := func():
		_strike_prompt_up = false
		_ws_prompt = false
		g._update_buttons()
		if wild:
			_arm_wild_swing(false)
		if picked.is_empty():
			g._on_strike_button_pressed()
		else:
			g._on_shortcut_strike_pressed()
	var choices := [
		{"text": "Confirm", "action": use_it},
		{"text": "Cancel", "action": plain},
	]
	g.current_action_menu_choices = choices
	g.action_menu.set_choices("Use your character ability for this strike?" + (" (Tap the deck again to cancel)" if wild else ""),
			choices, false, -1, -1, false, false, false, 2)
	g.action_menu.visible = true

# Strikes with the character action: pays its cost (if any, e.g. 1 Gauge), then strikes with the
# card(s) picked beforehand, or lets you pick one now.
func _strike_with_action(action_idx : int, picked : Array) -> void:
	var g = game
	var ca = g.game_wrapper.get_player_character_action(Enums.PlayerId.PlayerId_Player, action_idx)
	var free : bool = int(ca.get("force_cost", 0)) == 0 and int(ca.get("gauge_cost", 0)) == 0
	if free and not picked.is_empty() and "shortcut_effect_type" in ca:
		g._update_buttons()
		g._on_shortcut_character_action_pressed(action_idx) # strikes with the picked card(s)
		return
	g.deselect_all_cards()
	g._update_buttons()
	g._on_character_action_pressed(action_idx)
	if picked.is_empty():
		return
	# Once the cost is paid and the game asks for the strike card, use the picked one(s).
	var waited := 0.0
	while waited < 60.0:
		await get_tree().create_timer(_pt(0.1)).timeout
		waited += 0.1
		if g.ui_state == g.UIState.UIState_PickTurnAction:
			return # backed out
		if g.ui_state == g.UIState.UIState_SelectCards \
				and g.ui_sub_state == g.UISubState.UISubState_SelectCards_StrikeCard:
			break
	if g.ui_sub_state != g.UISubState.UISubState_SelectCards_StrikeCard:
		return
	_selecting = true
	for cid in picked:
		var card = g.find_card_on_board(cid)
		if card != null and not (card in g.selected_cards):
			g.on_card_clicked(card)
	_selecting = false
	if g.can_press_ok():
		g._on_instructions_ok_button_pressed(0)

func _character_action() -> void:
	var g = game
	var n : int = g.game_wrapper.get_player_character_action_count(Enums.PlayerId.PlayerId_Player)
	for i in range(n):
		var ca = g.game_wrapper.get_player_character_action(Enums.PlayerId.PlayerId_Player, i)
		if _menu_action(str(ca.get("action_name", "Character Action"))):
			return

func _wire_phone_controls() -> void:
	var g = game
	var T = g.CardPopoutType
	# Your deck: a wild swing while choosing a strike card; otherwise your revealed cards while
	# your top card is known, else your deck reference. A long press: always the deck reference.
	var open_my_ref := func(): _toggle_popout(T.CardPopoutType_ReferencePlayer, g._on_player_reference_button_pressed)
	_wire_tap_hold(panels["deck_btn_p"], func():
		# Choosing a strike card: the wild swing is picked (any picked cards let go) and waits for
		# the island's O, like a picked card does.
		if _is_strike_pick():
			_pick_wild_swing()
			return
		# Your turn: starts a strike with the wild swing picked (as tapping the blue area, then the
		# deck, would).
		if _start_wild_swing_strike():
			return
		if _menu_action("Wild Swing", true):
			return
		if _reveal_info(0)["deck"] != "":
			_toggle_revealed_box(0)
		else:
			open_my_ref.call(), open_my_ref)
	# Your hand icon: Prepare; a long press: Manual Reshuffle.
	_wire_tap_hold(panels["hand_btn_p"], func(): _menu_action("Prepare"), func(): _menu_action("Manual Reshuffle"))
	_wire_tap_hold(panels["ability_btn"], _character_action, Callable())
	_wire_tap_hold(panels["stage_btn_p"], func(): _menu_action("Boost"), Callable())
	_wire_tap_hold(panels["stage_btn_o"], func():
		# Characters whose strikes only get their bonus when started with their character
		# action (Giovanna): the island asks whether to use it for this strike.
		if _strike_action_index() >= 0:
			_ask_strike_with_action()
			return
		if not _menu_action("Strike"):
			_menu_action("EX Strike"), Callable())
	var dbtn = g.get_node("AllCards/PlayerDiscardButton")
	var open_my_discard := func(): _toggle_popout(T.CardPopoutType_DiscardPlayer, g._on_player_discard_button_pressed)
	# Tap: Change Cards, or (when no action can be chosen right now) the discard window.
	_wire_tap_hold(dbtn, func():
		if not _menu_action("Change Cards"):
			open_my_discard.call(), open_my_discard)
	# Opponent's deck: a long press does the same as a tap (opens their deck reference) ...
	var open_opp_ref := func(): _toggle_popout(T.CardPopoutType_ReferenceOpponent, g._on_opponent_reference_button_pressed)
	# ... except while their top card is revealed: then a tap opens the revealed cards.
	_wire_tap_hold(panels["deck_btn_o"], func():
		if _opp_reveal_info()["deck"] != "":
			_toggle_revealed_box(1)
		else:
			open_opp_ref.call(), open_opp_ref)
	# Opponent's discard pile: tap or long press opens the discard window.
	var odbtn = g.get_node("AllCards/OpponentDiscardButton")
	var open_opp_discard := func(): _toggle_popout(T.CardPopoutType_DiscardOpponent, g._on_opponent_discard_button_pressed)
	_wire_tap_hold(odbtn, open_opp_discard, open_opp_discard)
	# No hover / pressed highlight on the discard piles.
	for b in [dbtn, odbtn]:
		if b is TextureButton:
			b.texture_hover = b.texture_normal
			b.texture_pressed = b.texture_normal
	# One tap button per arena space (Move); the character icon buttons added after
	# these sit on top of them and take priority.
	for i in range(9):
		var loc := i + 1
		var sqb := _flat_button(backdrop, func(): pass)
		sqb.z_index = 2
		_wire_tap_hold(sqb, func(): _square_tap(loc), Callable())
		arena_sq_btns.append(sqb)
	help_btn = _text_button(backdrop, "?", show_help, 30)
	help_btn.add_theme_font_override("font", load("res://scenes/game/badge_font.gd").make_font())
	help_btn.add_theme_color_override("font_color", Color.WHITE)
	help_btn.add_theme_color_override("font_outline_color", Color.WHITE)
	help_btn.add_theme_constant_override("outline_size", 3)
	help_btn.z_index = 12
	# The stock arena squares would swallow taps meant for the icon buttons below;
	# their inner (selection) buttons still work, since those are separate controls.
	g.arena_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for sq_node in g.arena_layout.get_children():
		if sq_node is Control:
			sq_node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena_btn_p = _flat_button(backdrop, func(): pass)
	arena_btn_p.z_index = 3
	_wire_tap_hold(arena_btn_p, func():
		if not _choice_tap_on_character(Enums.PlayerId.PlayerId_Player):
			_menu_action("Exceed"),
			func(): show_character_review(false))
	arena_btn_o = _flat_button(backdrop, func(): pass)
	arena_btn_o.z_index = 3
	_wire_tap_hold(arena_btn_o, func():
		if not _choice_tap_on_character(Enums.PlayerId.PlayerId_Opponent):
			show_character_review(true), func(): show_character_review(true))

# Both character cards of one side, laid out like strike cards for review.
func show_character_review(is_opponent : bool) -> void:
	close_character_review()
	var zone = game.get_node_or_null("AllCards/OpponentAllCopy" if is_opponent else "AllCards/PlayerAllCopy")
	if zone == null:
		return
	var refs : Array = []
	for c in zone.get_children():
		if c is CardBase and c.card_id == CardBase.CharacterCardReferenceId:
			refs.append(c)
	if refs.is_empty():
		return
	close_popout_preview()
	clear_focus()
	char_review_root = Node2D.new()
	char_review_root.z_index = 40
	game.add_child(char_review_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.size = Vector2(W, H)
	char_review_root.add_child(dim)
	var close_btn := _flat_button(char_review_root, close_character_review)
	close_btn.position = Vector2.ZERO
	close_btn.size = Vector2(W, H)
	# Only the relevant character card is shown (the exceed card once exceeded), large.
	# Tapping or long-pressing it flips (smoothly) to the other one; a tap anywhere else
	# closes the view.
	var pid : int = Enums.PlayerId.PlayerId_Opponent if is_opponent else Enums.PlayerId.PlayerId_Player
	var st := {"idx": 1 if (refs.size() > 1 and game.game_wrapper.is_player_exceeded(pid)) else 0, "busy": false}
	var fs : Vector2 = CardBase.phone_focus_scale
	var fc : Vector2 = CardBase.phone_focus_center
	var src0 = refs[st["idx"]]
	var card : CardBase = load("res://scenes/card/card_base.tscn").instantiate()
	char_review_root.add_child(card)
	card.initialize_simple(src0.card_id, src0.card_url_loaded_image, src0.card_url_loaded_cardback, src0.card_attack_name, src0.card_boost_name)
	card.flip_card_to_front(src0.card_front.visible)
	card.change_state(CardBase.CardState.CardState_InPopout)
	card.set_card_and_focus(fc, 0, fs)
	card.focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_IGNORE
	card._set_preview_input_ignored(true)
	var cw : float = CARD_W * fs.x
	var ch : float = CARD_H * fs.y
	var flip := func():
		if st["busy"] or refs.size() < 2 or not is_instance_valid(card):
			return
		st["busy"] = true
		var nxt : int = 1 - int(st["idx"])
		var tw := card.create_tween()
		tw.tween_method(func(v : float): card.set_card_and_focus(null, null, Vector2(fs.x * v, fs.y)), 1.0, 0.0, 0.16)
		tw.tween_callback(func():
			var s2 = refs[nxt]
			card.initialize_simple(s2.card_id, s2.card_url_loaded_image, s2.card_url_loaded_cardback, s2.card_attack_name, s2.card_boost_name)
			card.flip_card_to_front(s2.card_front.visible)
			card.set_card_and_focus(fc, 0, Vector2(0.0, fs.y))
			st["idx"] = nxt)
		tw.tween_method(func(v : float): card.set_card_and_focus(null, null, Vector2(fs.x * v, fs.y)), 0.0, 1.0, 0.16)
		tw.tween_callback(func(): st["busy"] = false)
	var card_btn := _flat_button(char_review_root, flip)
	card_btn.position = fc - Vector2(cw, ch) / 2.0
	card_btn.size = Vector2(cw, ch)

func close_character_review() -> void:
	if char_review_root != null and is_instance_valid(char_review_root):
		char_review_root.queue_free()
	char_review_root = null

var _popout_can_select : bool = false
var _popout_long_fired : bool = false
var _popout_press_token : int = 0
var _popout_close_btn : Button = null

# Holding the enlarged card unfocuses it (phone controls).
func _on_preview_down() -> void:
	_preview_long_fired = false
	_preview_press_token += 1
	var token := _preview_press_token
	get_tree().create_timer(CardBase.PhoneLongPressTime).timeout.connect(func():
		if token == _preview_press_token and preview_button.button_pressed:
			_preview_long_fired = true
			clear_focus())

# Long press on a hand card focuses it, leaving its selection untouched.
func _on_card_long_press(card) -> void:
	var g = game
	if not is_instance_valid(card) or card.get_parent() != g.get_hand_zone(true):
		return
	if focused_card == card:
		clear_focus()
		return
	var s : int = card.state
	if s != CardBase.CardState.CardState_InHand and s != CardBase.CardState.CardState_Unfocusing:
		return
	if focused_card != null and is_instance_valid(focused_card):
		focused_card.unfocus()
	focused_card = card
	card.focus()
	_set_preview_visible(true)
	_refresh_select_button()

func clear_focus() -> void:
	if focused_card != null and is_instance_valid(focused_card):
		if focused_card.state == CardBase.CardState.CardState_Focusing:
			focused_card.unfocus()
	focused_card = null
	_set_preview_visible(false)

func on_card_lowered(card) -> void:
	if card == focused_card:
		focused_card = null
		_set_preview_visible(false)

func _set_preview_visible(show_it : bool) -> void:
	preview_button.visible = show_it
	# No separate Select button: a tap on the enlarged card selects it (as with phone controls).
	preview_hint.visible = false
	# The boost windows come later in the scene tree than the preview controls,
	# so they would win taps over the Select button. Let taps through while a
	# card is focused.
	_update_boost_zone_taps(true)

# Toggles mouse pass-through for a Control and everything under it, remembering
# each control's original filter so it can be restored exactly.
func _set_tree_input_ignored(root : Control, ignored : bool) -> void:
	var nodes : Array = [root]
	nodes.append_array(root.find_children("*", "Control", true, false))
	for n in nodes:
		if ignored:
			if not n.has_meta("phone_orig_mouse_filter"):
				n.set_meta("phone_orig_mouse_filter", n.mouse_filter)
			n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		elif n.has_meta("phone_orig_mouse_filter"):
			n.mouse_filter = n.get_meta("phone_orig_mouse_filter")
			n.remove_meta("phone_orig_mouse_filter")

func _on_select_pressed() -> void:
	if focused_card != null and is_instance_valid(focused_card):
		_selecting = true
		game.on_card_clicked(focused_card)
		_selecting = false
		_refresh_select_button()
		_refresh_select_button.call_deferred()

func _refresh_select_button() -> void:
	if focused_card != null and is_instance_valid(focused_card):
		preview_hint.text = "Deselect" if focused_card.selected else "Select"

# --------------------------------------------------------------------------
# Special / ultra card markers
# --------------------------------------------------------------------------
# Specials get a roman numeral (I, II, III, ...) and ultras a lower-case greek
# letter, assigned by the card's fixed position in its character's special /
# ultra list (the order of the character's card sheet), so the same card always
# gets the same marker and colour.

const ROMAN := ["I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII"]
const GREEK := ["α", "β", "γ", "δ", "ε", "ζ", "η", "θ", "ι", "κ", "λ", "μ"]
const SPECIAL_COLORS := [
	Color("ffd83b"), Color("ff9b3d"), Color("ff5c7a"), Color("c07dff"),
	Color("4fd8ff"), Color("7dff6b"), Color("ffffff"), Color("ff7de9"),
]
const ULTRA_COLORS := [
	Color("39f2ff"), Color("ffffff"), Color("a8ff5c"), Color("ffa8ff"),
	Color("ffe14d"), Color("ff7a5c"),
]

var _badge_maps := {}

func badge_for(card_def : Dictionary, is_opponent : bool) -> Dictionary:
	var card_type : String = str(card_def.get("type", ""))
	if card_type != "special" and card_type != "ultra":
		return {}
	var key := "opponent" if is_opponent else "player"
	if not _badge_maps.has(key):
		_badge_maps[key] = _build_badge_map(game.opponent_deck if is_opponent else game.player_deck)
	return _badge_maps[key].get(str(card_def.get("id", "")), {})

func _build_badge_map(deck : Dictionary) -> Dictionary:
	var specials : Array = []
	var ultras : Array = []
	var seen := {}
	var order := 0
	for entry in deck.get("cards", []):
		var def_id : String = str(entry.get("definition_id", ""))
		order += 1
		if def_id == "" or seen.has(def_id):
			continue
		seen[def_id] = true
		var def = CardDataManager.get_card(def_id)
		if def == null:
			continue
		var sort_key : int = int(entry.get("image_index", 1000 + order))
		var item := [sort_key, def_id]
		match str(def.get("type", "")):
			"special":
				specials.append(item)
			"ultra":
				ultras.append(item)
	specials.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	ultras.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var result := {}
	for i in range(specials.size()):
		result[specials[i][1]] = {
			"text": ROMAN[i] if i < ROMAN.size() else str(i + 1),
			"color": SPECIAL_COLORS[i % SPECIAL_COLORS.size()],
		}
	for i in range(ultras.size()):
		result[ultras[i][1]] = {
			"text": GREEK[i] if i < GREEK.size() else str(i + 1),
			"color": ULTRA_COLORS[i % ULTRA_COLORS.size()],
			"s6": int(float(str(deck.get("season", 0)))) == 6,
		}
	return result

# --------------------------------------------------------------------------
# Popouts / slideout
# --------------------------------------------------------------------------

# Deck / gauge / discard windows as a list instead of mini cards: a title, then two columns,
# one row per card showing [count] [gauge icon] "Card name - Boost name". The deck reference
# counts the copies left in deck+hand; the gauge and discard windows count the copies in that
# area. A tap or long press on a row focuses that card; when the game is asking for cards to
# be picked from the window, a tap on a row selects a copy of that card instead (identical
# copies share a row: which copy is picked doesn't matter). A tap anywhere outside the rows
# closes the window.
# True when the phone layout draws this window's contents itself from the game's zones, so the
# stock popout doesn't need to build its (hidden, slow to create) card copies.
func popout_draws_own_list(t) -> bool:
	return _ref_list_kind(t) in ["deck", "zone", "select", "revealed"]

func _ref_list_kind(t) -> String:
	var T = game.CardPopoutType
	if t == T.CardPopoutType_ReferencePlayer or t == T.CardPopoutType_ReferenceOpponent:
		return "deck"
	if t == T.CardPopoutType_RevealedOpponent:
		return "revealed"
	if t == T.CardPopoutType_ChoiceZone and _topdeck_picking():
		return "topdeck"
	if t == T.CardPopoutType_BuddyPlayer or t == T.CardPopoutType_BuddyOpponent:
		return "extra"
	if t in [T.CardPopoutType_GaugePlayer, T.CardPopoutType_GaugeOpponent,
			T.CardPopoutType_DiscardPlayer, T.CardPopoutType_DiscardOpponent,
			T.CardPopoutType_BoostPlayer, T.CardPopoutType_BoostOpponent,
			T.CardPopoutType_SealedPlayer, T.CardPopoutType_SealedOpponent]:
		return "select" if _popout_selecting(t) else "zone"
	return ""

# True while the game is asking for cards to be picked from the window of type `t`.
func _popout_selecting(t) -> bool:
	var g = game
	# Choosing boosts to sustain: the game opens your boost window itself (without the popout
	# instructions other picks set up), and its rows are what you pick from.
	if g.ui_state == g.UIState.UIState_SelectCards \
			and g.ui_sub_state == g.UISubState.UISubState_SelectCards_ChooseBoostsToSustain \
			and int(t) == int(g.CardPopoutType.CardPopoutType_BoostPlayer) \
			and not g.is_tournelouse_transform_zone_choice():
		return true
	var info = g.popout_instruction_info
	if not info or int(info.get("popout_type", -1)) != int(t):
		return false
	return g.ui_state == g.UIState.UIState_SelectCards

func _ref_player_name(is_player : bool) -> String:
	if is_player:
		if player_name_label != null and player_name_label.text != "":
			return player_name_label.text
		return str(game.game_wrapper.get_player_name(Enums.PlayerId.PlayerId_Player))
	return str(game.game_wrapper.get_player_name(Enums.PlayerId.PlayerId_Opponent))

# ---- Deck reference odds ----------------------------------------------------------------------
# For each distinct number of copies left (e.g. 2 and 1; Enkidu can have 6), the chance that such
# a card is on top of the deck ("WS %": what a wild swing would turn up) and, for the opponent,
# the chance it is in their hand. Your deck: the cards left in it (your hand is known to you).
# Theirs: deck and hand together, as their hand is unknown.
func _odds_data(is_p : bool) -> Dictionary:
	var gw = game.game_wrapper
	var counts : Array = []
	var n := 0
	var h := 0
	if is_p:
		var p = gw._get_player(Enums.PlayerId.PlayerId_Player)
		var by := {}
		for c in p.deck:
			var id := str(c.definition.get("id", ""))
			by[id] = int(by.get(id, 0)) + 1
		counts = by.values()
		n = p.deck.size()
	else:
		var db = gw.get_card_database()
		var seen := {}
		for card in game.get_node("AllCards/OpponentAllCopy").get_children():
			if card.card_id < 0:
				continue
			var lc = db.get_card(card.card_id - game.ReferenceScreenIdRangeStart)
			if lc == null:
				continue
			var id := str(lc.definition.get("id", ""))
			if seen.has(id):
				continue
			seen[id] = true
			counts.append(int(gw.count_cards_in_deck_and_hand(Enums.PlayerId.PlayerId_Opponent, id)))
		h = int(gw.get_player_hand_size(Enums.PlayerId.PlayerId_Opponent))
		n = int(gw.get_player_deck_size(Enums.PlayerId.PlayerId_Opponent)) + h
	var distinct : Array = []
	for c in counts:
		if int(c) > 0 and not int(c) in distinct:
			distinct.append(int(c))
	distinct.sort()
	distinct.reverse()
	return {"distinct": distinct, "n": n, "h": h}

func _pct(p : float) -> String:
	if p <= 0.0:
		return "0%"
	return "%d%%" % maxi(1, roundi(p * 100.0)) # (anything above 0 shows at least 1%)

# [[copies, "20%"], ...] for the top of the deck (or, with `hand`, for being in their hand).
func _odds_values(d : Dictionary, hand : bool) -> Array:
	var out : Array = []
	var n : int = d["n"]
	for c in d["distinct"]:
		var p := 0.0
		if n > 0:
			if hand:
				var h : int = d["h"]
				var none := 1.0
				for i in range(c):
					none *= maxf(0.0, float(n - h - i)) / float(n - i) if n - i > 0 else 0.0
				p = 1.0 - none
			else:
				p = float(c) / float(n)
		out.append([int(c), _pct(clampf(p, 0.0, 1.0))])
	return out

func _odds_tag(text : String, col : Color, icon : Texture2D = null) -> PanelContainer:
	var tag := PanelContainer.new()
	tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.border_color = Color(1, 1, 1)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.content_margin_left = 5
	sb.content_margin_right = 5
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	tag.add_theme_stylebox_override("panel", sb)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 3)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tag.add_child(hb)
	if icon != null:
		var ic := TextureRect.new()
		ic.texture = icon
		ic.custom_minimum_size = Vector2(24, 24)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)
	hb.alignment = BoxContainer.ALIGNMENT_CENTER
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 18)
	lab.add_theme_color_override("font_color", Color(1, 1, 1))
	lab.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	lab.add_theme_constant_override("outline_size", 6)
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lab)
	return tag

func _odds_cell(tag : Control, value_name : String, cell_w : float) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(cell_w, 42.0)
	cell.add_theme_stylebox_override("panel", _ref_cell_style(false))
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 3) # (as the card rows)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(inset)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(hb)
	tag.size_flags_vertical = Control.SIZE_FILL # (stretches to the row's full height)
	hb.add_child(tag)
	var vals := HBoxContainer.new()
	vals.name = value_name
	vals.add_theme_constant_override("separation", 4)
	vals.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vals.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(vals)
	return cell

# One count's own box: the number of copies in its top-left corner ("×2"), its chance in the
# bottom-right corner ("33" with a smaller "%"). Four boxes share each cell's width equally.
const ODDS_SLOTS := 4
func _odds_box() -> PanelContainer:
	var box := PanelContainer.new()
	box.custom_minimum_size = Vector2(0, 32)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := _style(Color(0.02, 0.03, 0.06, 0.9), Color(1, 1, 1, 0.75), 2, 6)
	sb.content_margin_left = 4
	sb.content_margin_right = 4
	sb.content_margin_top = 0
	sb.content_margin_bottom = 0
	box.add_theme_stylebox_override("panel", sb)
	# A free-layout area: the two corners are placed by hand (they may overlap a little).
	var area := Control.new()
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.clip_contents = false
	box.add_child(area)
	var cop := _odds_label("Copies", 16, Color(0.7, 0.85, 1.0))
	area.add_child(cop)
	var bottom := HBoxContainer.new()
	bottom.name = "Bottom"
	bottom.alignment = BoxContainer.ALIGNMENT_END # (bottom-right corner)
	bottom.add_theme_constant_override("separation", 1)
	bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(bottom)
	var num := _odds_label("Pct", 23, Color(1, 1, 1))
	num.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	bottom.add_child(num)
	var pct_sign := _odds_label("PctSign", 14, Color(1, 1, 1, 0.85))
	pct_sign.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	pct_sign.size_flags_vertical = Control.SIZE_FILL
	bottom.add_child(pct_sign)
	area.resized.connect(func(): _layout_odds_box(area))
	return box

# "×2" grows to fill the box's top-left quarter; the chance sits in the bottom-right corner.
func _layout_odds_box(area : Control) -> void:
	if not is_instance_valid(area) or area.size.x < 4.0:
		return
	var cop : Label = area.get_node("Copies")
	var bottom : Control = area.get_node("Bottom")
	var q := area.size / 2.0
	var f : Font = cop.get_theme_font("font")
	var fs := 34
	while fs > 10 and (f.get_string_size(cop.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > q.x + 2.0
			or f.get_ascent(fs) - f.get_descent(fs) * 0.3 > q.y + 6.0):
		fs -= 1
	fs = maxi(10, int(fs * 0.8)) # (a bit under the full quarter)
	cop.add_theme_font_size_override("font_size", fs)
	cop.reset_size()
	# Its glyph tops sit at the box's top edge (the label's own top padding is pulled up).
	var pad := f.get_ascent(fs) - fs * 0.72 # (ascent minus the digits' height)
	cop.position = Vector2(1.0, -maxf(0.0, pad) + 3.0)
	bottom.reset_size()
	var bs := bottom.get_combined_minimum_size()
	bottom.size = bs
	bottom.position = area.size - bs + Vector2(0.0, 0.0) # (clear of the bottom border)

func _odds_label(n : String, fs : int, col : Color) -> Label:
	var l := Label.new()
	l.name = n
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	l.add_theme_constant_override("outline_size", 4)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l

func _fill_odds_boxes(vals : HBoxContainer, values : Array) -> void:
	# Always four equal slots (unused ones stay empty but keep the boxes the same size).
	var slots := maxi(ODDS_SLOTS, values.size())
	while vals.get_child_count() < slots:
		vals.add_child(_odds_box())
	while vals.get_child_count() > slots:
		var last := vals.get_child(vals.get_child_count() - 1)
		vals.remove_child(last)
		last.queue_free()
	for i in range(slots):
		var box := vals.get_child(i)
		box.modulate.a = 1.0 if i < values.size() else 0.0
		if i >= values.size():
			continue
		box.find_child("Copies", true, false).text = "×%d" % values[i][0]
		# "33%" -> "33" and a smaller "%".
		var pct : String = values[i][1]
		box.find_child("Pct", true, false).text = pct.trim_suffix("%")
		box.find_child("PctSign", true, false).text = "%" if pct.ends_with("%") else ""
		_layout_odds_box.call_deferred(box.get_child(0))

func _ref_odds_row(is_p : bool, cell_w : float) -> Control:
	# Laid out exactly like the card rows above (same cell size and gaps), so the whole list
	# reads as one grid.
	var row := GridContainer.new()
	row.name = "RefOdds"
	row.columns = 2
	row.set_meta("odds_player", is_p)
	row.add_theme_constant_override("h_separation", 0)
	row.add_theme_constant_override("v_separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var cells : Array = [_odds_cell(_odds_tag("WS %", Color(0.42, 0.12, 0.62)), "OddsWS", cell_w)]
	if not is_p:
		cells.append(_odds_cell(_odds_tag("%", Color(0.42, 0.44, 0.48), _hand_tex()), "OddsHand", cell_w))
	for c in cells:
		var gap := MarginContainer.new()
		gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gap.add_theme_constant_override("margin_left", 4)
		gap.add_theme_constant_override("margin_right", 4)
		# (-8: cancels the list's 10px spacing, so the gap above matches the card rows' gaps)
		gap.add_theme_constant_override("margin_top", -8)
		gap.add_theme_constant_override("margin_bottom", 3)
		gap.add_child(c)
		row.add_child(gap)
	_update_odds_row(row)
	return row

var _odds_next_ms : int = 0
var _hand_tex_cache : Texture2D = null
func _hand_tex() -> Texture2D:
	if _hand_tex_cache == null:
		_hand_tex_cache = _hand_glyph_texture()
	return _hand_tex_cache
func _update_odds_row(row) -> void:
	if row == null or not is_instance_valid(row):
		return
	var d := _odds_data(bool(row.get_meta("odds_player", true)))
	var ws = row.find_child("OddsWS", true, false)
	if ws != null:
		_fill_odds_boxes(ws, _odds_values(d, false))
	var hd = row.find_child("OddsHand", true, false)
	if hd != null:
		_fill_odds_boxes(hd, _odds_values(d, true))

func _build_reference_list(popout : Control) -> void:
	var rows_node : Control = popout.rows
	var holder : Node = rows_node.get_parent()
	var old = holder.get_node_or_null("RefList")
	if old != null:
		holder.remove_child(old)
		old.queue_free()
	var t = game.popout_type_showing
	var T = game.CardPopoutType
	var kind := _ref_list_kind(t)
	if kind == "":
		rows_node.visible = true
		return
	if kind == "revealed":
		_build_revealed_list(popout, holder)
		return
	if kind == "topdeck":
		_build_topdeck_list(popout, holder)
		return
	if kind == "extra":
		_build_extra_list(popout, holder)
		return
	var is_p : bool = t in [T.CardPopoutType_ReferencePlayer, T.CardPopoutType_GaugePlayer, T.CardPopoutType_DiscardPlayer, T.CardPopoutType_BoostPlayer, T.CardPopoutType_SealedPlayer]
	var is_boost : bool = t in [T.CardPopoutType_BoostPlayer, T.CardPopoutType_BoostOpponent]
	var zone_name : String
	var title_kind : String
	match t:
		T.CardPopoutType_BoostPlayer, T.CardPopoutType_BoostOpponent:
			zone_name = "%sBoosts" % ("Player" if is_p else "Opponent")
			title_kind = "BOOST REFERENCE"
		T.CardPopoutType_ReferencePlayer, T.CardPopoutType_ReferenceOpponent:
			zone_name = "%sAllCopy" % ("Player" if is_p else "Opponent")
			title_kind = "DECK REFERENCE"
		T.CardPopoutType_GaugePlayer, T.CardPopoutType_GaugeOpponent:
			zone_name = "%sGauge" % ("Player" if is_p else "Opponent")
			title_kind = "GAUGE REFERENCE"
		T.CardPopoutType_SealedPlayer, T.CardPopoutType_SealedOpponent:
			zone_name = "%sSealed" % ("Player" if is_p else "Opponent")
			title_kind = "SEALED REFERENCE"
		_:
			zone_name = "%sDiscards" % ("Player" if is_p else "Opponent")
			title_kind = "DISCARD REFERENCE"
	var zone = game.get_node_or_null("AllCards/" + zone_name)
	if zone == null:
		rows_node.visible = true
		return
	rows_node.visible = false
	# The island carries the pick prompt and its OK / cancel: no prompt in the window.
	popout.instruction_box.visible = false
	# No stock title and no close button here: the list has its own title, and tapping
	# anywhere outside the rows closes the window (see _finish_reference_popout).
	var tl : Label = popout.title_label
	tl.get_parent().visible = false
	for b in popout.find_children("*", "Button", true, false):
		if str(b.text).to_lower().contains("close"):
			b.visible = false
	var db = game.game_wrapper.get_card_database()
	# Their sealed area, when they seal face down: those cards stay anonymous.
	var secret_zone : bool = t == T.CardPopoutType_SealedOpponent \
			and game.game_wrapper.is_player_sealed_area_secret(Enums.PlayerId.PlayerId_Opponent)
	var order := {"normal": 0, "special": 1, "ultra": 2}
	# Each entry: [type order, first position, representative card, count]
	var entries : Array = []
	var idx := 0
	if kind == "deck":
		for card in zone.get_children():
			if card.card_id < 0:
				continue
			var def = db.get_card(card.card_id - game.ReferenceScreenIdRangeStart).definition
			var o : int = order.get(str(def.get("type", "")), -1)
			if o < 0:
				continue
			entries.append([o, idx, card, maxi(card.get_remaining_count(), 0), [card]])
			idx += 1
	else:
		# Copies of the same card share a row (the most recently added copy represents it).
		var by_def := {}
		for card in zone.get_children():
			if not (card is CardBase) or card.card_id < 0:
				continue
			var logic_card = db.get_card(card.card_id)
			if logic_card == null:
				continue
			var def = logic_card.definition
			var o : int = order.get(str(def.get("type", "")), 3)
			var key : String = str(def.get("id", card.card_id))
			if secret_zone and not card.card_front.visible:
				# Sealed face down (e.g. a secret sealed area): one anonymous row, listed last.
				key = "__face_down"
				o = 4
			if by_def.has(key):
				by_def[key][2] = card
				by_def[key][3] += 1
				by_def[key][4].append(card)
			else:
				by_def[key] = [o, idx, card, 1, [card]]
				entries.append(by_def[key])
				idx += 1
	entries.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	var cell_w : float = floorf((W - 52.0) / 2.0)
	var title_w : float = cell_w * 2.0 + 8.0
	if is_boost:
		cell_w = title_w # one wide column: each row also carries the boost's text
	var list := VBoxContainer.new()
	list.name = "RefList"
	list.set_meta("ref_kind", kind)
	list.add_theme_constant_override("separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(list)
	var title := Label.new()
	title.name = "RefTitle"
	title.text = "%s's %s" % [_ref_player_name(is_p), title_kind]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(title_w, 0.0)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var their_ref : bool = t == T.CardPopoutType_ReferenceOpponent and popout.toggle_container.visible
	if their_ref:
		# Their deck reference: the "pre-reshuffle" toggle sits at the top right, next to the
		# title (the stock one at the bottom is hidden).
		popout.toggle_container.visible = false
		var head := HBoxContainer.new()
		head.custom_minimum_size = Vector2(title_w, 0.0)
		head.add_theme_constant_override("separation", 8)
		head.mouse_filter = Control.MOUSE_FILTER_IGNORE
		title.custom_minimum_size = Vector2.ZERO
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		head.add_child(title)
		var stock : Button = popout.toggle_button
		var tb := Button.new()
		tb.focus_mode = Control.FOCUS_NONE
		var ttxt := str(stock.text)
		if ttxt == "Show cards before reshuffle":
			ttxt = "Show cards pre-reshuffle"
		tb.text = ttxt
		tb.disabled = stock.disabled
		tb.add_theme_font_size_override("font_size", 16)
		tb.add_theme_stylebox_override("normal", _style(Color(0.08, 0.1, 0.18, 0.9), Color(1, 1, 1, 0.7), 2, 8))
		tb.add_theme_stylebox_override("hover", _style(Color(0.14, 0.16, 0.26, 0.95), Color(1, 1, 1, 0.9), 2, 8))
		tb.add_theme_stylebox_override("pressed", _style(Color(0.04, 0.05, 0.1, 0.95), Color(1, 1, 1, 0.9), 2, 8))
		tb.add_theme_stylebox_override("disabled", _style(Color(0.08, 0.1, 0.18, 0.5), Color(1, 1, 1, 0.3), 2, 8))
		tb.pressed.connect(func(): stock.pressed.emit())
		head.add_child(tb)
		list.add_child(head)
	else:
		list.add_child(title)
	if entries.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 20)
		empty.modulate = Color(1, 1, 1, 0.6)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		list.add_child(empty)
	var grid := GridContainer.new()
	grid.name = "RefGrid"
	grid.columns = 1 if is_boost else 2
	# No gaps between cells: each row's tap area reaches halfway into the space around it, so a
	# tap between rows picks the nearest row rather than closing the window.
	grid.add_theme_constant_override("h_separation", 0)
	grid.add_theme_constant_override("v_separation", 0)
	grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(grid)
	if kind == "deck" and not entries.is_empty():
		# Below the cards: the chance a card is on top of the deck (a wild swing) and, for
		# theirs, the chance it is in their hand, by how many copies of it are left.
		list.add_child(_ref_odds_row(is_p, cell_w))
	for e in entries:
		var card = e[2]
		var count : int = e[3]
		var group : Array = e[4]
		var cell := PanelContainer.new()
		cell.custom_minimum_size = Vector2(cell_w, 42.0)
		cell.add_theme_stylebox_override("panel", _ref_cell_style(false))
		cell.modulate = Color(1, 1, 1, 1.0 if count > 0 else 0.5)
		cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.set_meta("ref_cards", group)
		cell.set_meta("ref_selected", -1)
		var face_down : bool = secret_zone and not card.card_front.visible
		# The style has no content margins, so the row button below covers the border too;
		# the row's contents get their inset from this margin instead.
		var inset := MarginContainer.new()
		for side in ["left", "right", "top", "bottom"]:
			inset.add_theme_constant_override("margin_" + side, 3)
		inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cell.add_child(inset)
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 8)
		hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inset.add_child(hb)
		var cnt := Label.new()
		cnt.text = str(count)
		cnt.custom_minimum_size = Vector2(40.0, 0.0)
		cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		cnt.add_theme_font_size_override("font_size", 24)
		cnt.add_theme_stylebox_override("normal", _style(Color(0.02, 0.03, 0.06, 0.95), Color(1, 1, 1, 0.8), 2, 5))
		cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(cnt)
		cell.set_meta("ref_count_label", cnt)
		cell.set_meta("ref_count", count)
		var ic := TextureRect.new()
		ic.custom_minimum_size = Vector2(40.0, 40.0)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.texture = card.card_url_loaded_cardback if face_down else _moon_icon(card)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Roman numeral / greek letter on specials and ultras, as in the gauge.
		if str(card.badge_text) != "" and not face_down:
			ic.add_child(_make_badge_label(card, 40.0))
		hb.add_child(ic)
		if is_boost:
			# Boost name, then its text as printed (stat changes bold and in the card's colours).
			var rt := RichTextLabel.new()
			rt.bbcode_enabled = true
			rt.fit_content = true
			rt.scroll_active = false
			rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rt.custom_minimum_size = Vector2(cell_w - 40.0 - 40.0 - 16.0 - 14.0, 0.0)
			rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			for fk in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size"]:
				rt.add_theme_font_size_override(fk, 17)
			rt.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			rt.add_theme_constant_override("outline_size", 4)
			rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
			rt.text = "[b]%s[/b]\n%s" % [str(card.card_boost_name), _boost_bbcode(card)]
			hb.add_child(rt)
		else:
			var lab := Label.new()
			lab.text = "Face-down card" if face_down else "%s - %s" % [str(card.card_attack_name), str(card.card_boost_name)]
			lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lab.custom_minimum_size = Vector2(cell_w - 40.0 - 40.0 - 16.0 - 14.0, 0.0)
			lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			lab.add_theme_font_size_override("font_size", 17)
			lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
			hb.add_child(lab)
		# The whole row (border included) takes the taps: an invisible button over it.
		var row_btn := _invisible_button()
		# The row with its share of the gap around it: [gap margin -> cell] under the button.
		var slot := _gap_slot(cell)
		slot.add_child(row_btn)
		var is_deck := kind == "deck"
		var focus_row := func():
			if face_down:
				return # nothing to show
			if is_deck:
				show_popout_preview(card.card_id, card)
			elif is_instance_valid(card) and show_popout_preview(card.card_id):
				_preview_keep = true # just a look: a tap closes it
		var tap_row := func():
			if _popout_selecting(game.popout_type_showing):
				_ref_row_pick(group) # e.g. naming a card from the deck reference (Parry)
				return
			focus_row.call()
		_wire_tap_hold(row_btn, tap_row, focus_row)
		grid.add_child(slot)
	_update_ref_list_selection()

# A boost's text as on the card: stat changes in bold and in the card's stat colours.
const STAT_COLORS := {"Range": "#5aa2ff", "Power": "#ff4b4b", "Speed": "#ffd23f", "Armor": "#c27bff", "Guard": "#4fd36b"}
var _stat_re : RegEx

# Boosts shown in their card's own wording (boost box and boost reference), by boost name.
const PRINTED_BOOST_TEXT := {
	"Courtesy": "[b]Cleanup:[/b] If you were not stunned, you may return your attack to your hand. If you do, add this to your Gauge.",
	"Holy Orders": "[b][color=#ffd23f]+1 Speed[/color][/b]. [b]Hit:[/b] Gain [b]Advantage[/b].",
	"Faultless Defense": "[b][color=#4fd36b]+4 Guard[/color][/b]. At the start of your turn, add this to your Gauge.",
	"Drunkard Shade": "Attacks at Range 4+ do not hit you. At the start of your turn, add this to your Gauge.",
	"Writhe in Pain": "[b][color=#ff4b4b]+1 Power[/color][/b]. [b]Hit:[/b] Push or Pull 1. The opponent must discard a random card.",
}

# ---- Small action banner while the island waits for an action's confirmation ------------------
var _confirm_re : RegEx
var _change_count : int = 0 # the last Change Cards count shown (for its action banner)

func _update_confirm_banner(confirming : bool) -> void:
	if strike_stage == null:
		return
	var word := ""
	# (whose action it is: lettered in that player's color. Your own confirmations, unless it's a
	# move of the opponent's.)
	var word_side := 0
	if not confirming and _waiting_on_online_opponent():
		# Online, the opponent's decision: a small "WAITING..." banner (in their color) until it
		# comes, its dots appearing one at a time and starting over (spaces hold the missing dots'
		# places so the word stays put). (Not over an action banner or the held STRIKE banner.)
		var dots := int(Time.get_ticks_msec() / int(WAIT_DOT_TIME * 1000.0)) % 4
		word = "WAITING" + ".".repeat(dots) + " ".repeat(3 - dots)
		word_side = 1
	if confirming:
		var g = game
		if _confirm_re == null:
			_confirm_re = RegEx.new()
			_confirm_re.compile("\\[[^\\]]*\\]")
		var instr : String = _confirm_re.sub(str(g.action_menu.instructions_label.text), "", true).strip_edges()
		const ASK := "Are you sure you want to "
		var selecting : bool = g.ui_state == g.UIState.UIState_SelectCards
		var force_word := _strike_force_banner() if selecting else ""
		var move_word := _effect_move_banner()
		if instr.begins_with(ASK):
			var asked : String = instr.substr(ASK.length()).trim_suffix("?").strip_edges()
			# (a character action with nothing to pay: confirmed with its own banner word)
			word = UNIQUE_ACTION_BANNER if _is_character_action_name(asked) else asked.to_upper()
		elif selecting and g.game_wrapper.get_game_state() == Enums.GameState.GameState_DiscardDownToMax:
			# Discarding down to the hand size: how many are picked so far. (Confirmed, it grows into
			# the HAND LIMIT banner as the cards go.)
			var need_d := int(g.select_card_require_min)
			word = "DISCARD (%d/%d)" % [mini(g.selected_cards.size(), need_d), need_d]
		elif selecting and g.ui_sub_state == g.UISubState.UISubState_SelectCards_Mulligan:
			# The start of the match: choosing cards to mulligan. (Confirmed with cards, it grows into
			# the MULLIGAN banner as they go; passed, it fades.)
			word = "MULLIGAN"
		elif selecting and g.ui_sub_state == g.UISubState.UISubState_SelectCards_CharacterAction_Force:
			# Paying a character action's force cost.
			var need_f := int(g.select_card_require_force)
			word = "PAY %d/%d FORCE" % [mini(int(g.get_force_in_selected_cards()), need_f), need_f]
		elif selecting and g.ui_sub_state == g.UISubState.UISubState_SelectCards_CharacterAction_Gauge:
			# Paying a character action's gauge cost.
			var need_g := int(g.select_card_require_min)
			word = "PAY %d/%d GAUGE" % [mini(int(g.get_gauge_generated()), need_g), need_g]
		elif force_word != "":
			word = force_word
		elif move_word != "":
			word = move_word
			word_side = _effect_move_side
		elif selecting and g.ui_sub_state == g.UISubState.UISubState_SelectCards_PlayBoost:
			word = "BOOST"
		elif selecting and g.ui_sub_state == g.UISubState.UISubState_SelectCards_MoveActionGenerateForce:
			# Paying for a move: how many spaces.
			var here : int = g.game_wrapper.get_player_location(Enums.PlayerId.PlayerId_Player)
			word = "MOVE %d" % absi(int(g.selected_arena_location) - here)
		elif selecting and g.ui_sub_state == g.UISubState.UISubState_SelectCards_ForceForChange:
			# Changing cards: how many will be drawn, as cards / gauge are (de)selected.
			_change_count = int(g.get_force_in_selected_cards())
			word = "CHANGE CARDS %d" % _change_count
		elif selecting and g.ui_sub_state == g.UISubState.UISubState_SelectCards_StrikeGauge:
			# Paying gauge for an attack (an Ultra): how much is paid so far. (After it is confirmed,
			# the banner stays until the spent gauge has gone through the center: StrikeStage.)
			# An Ultra wild swung: it can be validated (paid for) or passed (another wild swing).
			var paid := mini(int(g.get_gauge_generated()), int(g.select_card_require_min))
			if _is_cost_wild():
				word = "VALIDATE (%d/%d) OR PASS" % [paid, int(g.select_card_require_min)]
			else:
				word = "PAY %d/%d GAUGE" % [paid, int(g.select_card_require_min)]
		elif selecting and g.ui_sub_state == g.UISubState.UISubState_SelectCards_Exceed:
			# Exceeding: grows into the EXCEED banner once confirmed.
			word = "EXCEED"
		elif (_strike_prompt_up or (selecting and g.ui_sub_state in [g.UISubState.UISubState_SelectCards_StrikeCard,
				g.UISubState.UISubState_SelectCards_StrikeCard_FromGauge, g.UISubState.UISubState_SelectCards_StrikeCard_FromSealed])) \
				and not strike_stage.strike_banner_held():
			# Starting a strike (e.g. the blue area tapped): STRIKE until the card is set (it then
			# grows into the held STRIKE banner).
			word = "EX STRIKE" if selecting and g.selected_cards.size() >= 2 else "STRIKE"
			if _ws_pending_live() or (_strike_prompt_up and _ws_prompt):
				word = "STRIKE (WILD SWING)"
		elif _is_effect_choice() and _is_seal_choice():
			# Cards to seal for an effect: grows into the SEAL banner as they go.
			word = SEAL_BANNER
		elif _my_boost_resolving() or _is_effect_choice():
			# Any other choice an effect asks of you (your boost waiting for a decision, an effect's
			# options, cards to pick for it...).
			word = "SELECT"
	strike_stage.set_mini_banner(word, word_side)

# An online match (not against the AI, not watching) whose next decision is the opponent's.
# (Shown once the wait has lasted WAIT_BANNER_DELAY, so it doesn't flicker between the opponent's
# quick back-to-back decisions.)
const WAIT_BANNER_DELAY := 0.6
const WAIT_DOT_TIME := 0.4 # (seconds per dot)
var _waiting_since : float = -1.0

func _waiting_on_online_opponent() -> bool:
	var g = game
	var waiting : bool = not g.observer_mode and g.game_wrapper != null and not g.game_wrapper.is_ai_game() \
			and g.ui_state == g.UIState.UIState_WaitingOnOpponent \
			and not action_banner_up and not (strike_stage != null and strike_stage.strike_banner_held())
	if not waiting:
		_waiting_since = -1.0
		return false
	if _waiting_since < 0.0:
		_waiting_since = _now_s()
	return _now_s() - _waiting_since >= WAIT_BANNER_DELAY

# One of your character actions' names ("Character Action" when it has none), as the game puts it
# in its "Are you sure you want to ...?" confirmation.
func _is_character_action_name(asked : String) -> bool:
	var gw = game.game_wrapper
	var a := asked.strip_edges().to_lower()
	if a == "character action":
		return true
	for i in range(gw.get_player_character_action_count(Enums.PlayerId.PlayerId_Player)):
		var ca = gw.get_player_character_action(Enums.PlayerId.PlayerId_Player, i)
		if ca is Dictionary and str(ca.get("action_name", "Character Action")).strip_edges().to_lower() == a:
			return true
	return false

# A decision an effect asks of you (not a turn action, a strike card, a payment with its own
# banner, a mulligan or discarding down to your hand size): its pre-confirmation banner is SELECT.
func _is_effect_choice() -> bool:
	var g = game
	var U = g.UISubState
	if g.observer_mode:
		return false
	if g.ui_state == g.UIState.UIState_MakeChoice:
		return true
	if g.ui_state == g.UIState.UIState_SelectArenaLocation:
		return g.ui_sub_state == U.UISubState_SelectArena_EffectChoice
	if g.ui_state != g.UIState.UIState_SelectCards:
		return false
	if g.game_wrapper.get_game_state() == Enums.GameState.GameState_DiscardDownToMax:
		return false
	return not g.ui_sub_state in [U.UISubState_None, U.UISubState_SelectCards_PlayBoost,
			U.UISubState_SelectCards_MoveActionGenerateForce, U.UISubState_SelectCards_ForceForChange,
			U.UISubState_SelectCards_Exceed, U.UISubState_SelectCards_Mulligan,
			U.UISubState_SelectCards_StrikeForce, U.UISubState_SelectCards_StrikeGauge,
			U.UISubState_SelectCards_StrikeCard, U.UISubState_SelectCards_StrikeCard_FromGauge,
			U.UISubState_SelectCards_StrikeCard_FromSealed, U.UISubState_SelectCards_StrikeResponseCard,
			U.UISubState_SelectCards_OpponentSetsFirst_StrikeCard,
			U.UISubState_SelectCards_OpponentSetsFirst_StrikeResponseCard,
			U.UISubState_SelectCards_CharacterAction_Force, U.UISubState_SelectCards_CharacterAction_Gauge,
			U.UISubState_SelectCards_ForceForBoost, U.UISubState_SelectCards_GaugeForBoost,
			U.UISubState_SelectCards_InfusionBeforeAction, U.UISubState_SelectCards_BoostCancel]

# During a strike, paying a set amount of force (an attack's force cost, or an effect's "spend X
# force"): "PAY 0/X FORCE" when it must be paid, "PAY FORCE (0/X) OR PASS" when it can be passed
# (the count follows the cards selected). "" otherwise.
func _strike_force_banner() -> String:
	var g = game
	if g.ui_state != g.UIState.UIState_SelectCards or not g.game_wrapper.has_active_strike():
		return ""
	var need := 0
	var required := true
	if g.ui_sub_state == g.UISubState.UISubState_SelectCards_ForceForArmor:
		return "PAY FORCE OR PASS" # (force to block: any amount, or none)
	if g.ui_sub_state == g.UISubState.UISubState_SelectCards_StrikeForce:
		need = int(g.select_card_require_force)
		required = not _is_cost_wild() # (a wild swing allowed instead: it can be passed)
	elif g.ui_sub_state == g.UISubState.UISubState_SelectCards_ForceForEffect:
		need = int(g.select_card_up_to_force)
		required = not g.instructions_cancel_allowed
	else:
		return ""
	if need <= 0:
		return ""
	var paid := mini(int(g.get_force_in_selected_cards()), need)
	if required:
		return "PAY %d/%d FORCE" % [paid, need]
	return "PAY FORCE (%d/%d) OR PASS" % [paid, need]

# A move chosen during an effect (an option list of moves, or a space to tap): "MOVE <name>", with
# the name of whoever is being moved. "" otherwise (your own Move action has its own banner).
func _effect_move_banner() -> String:
	var g = game
	var moves_opp := false
	var mcm := _move_choice_map()
	if not mcm.is_empty():
		moves_opp = bool(mcm.get("moves_opponent", false))
	elif g.ui_state == g.UIState.UIState_SelectArenaLocation and g.ui_sub_state == g.UISubState.UISubState_SelectArena_EffectChoice:
		var di = g.game_wrapper.get_decision_info()
		var et := str(di.effect_type) if di != null else ""
		if et in [StrikeEffects.PushOrPullToSpace, StrikeEffects.PullToSpaceAndGainPower]:
			moves_opp = true
		elif et != StrikeEffects.MoveToSpace:
			return ""
	else:
		return ""
	_effect_move_side = 1 if moves_opp else 0
	var nm := _ref_player_name(not moves_opp).strip_edges()
	return ("MOVE %s" % nm).to_upper() if nm != "" else "MOVE"

var _effect_move_side : int = 0 # (whose move _effect_move_banner last named: 0 you, 1 the opponent)

# True while one of your boosts is being played / resolving (its card still in the strike area).
func _my_boost_resolving() -> bool:
	var striking = game.get_node_or_null("AllCards/Striking")
	for c in _hidden_boost_cards:
		if is_instance_valid(c) and c.get_parent() == striking and int(c.get_meta("phone_boost_side", -1)) == 0:
			return true
	return false

# A boost card still on its way into its boost box (or its event / banner still to come).
func boost_card_arriving() -> bool:
	for c in _hidden_boost_cards:
		if is_instance_valid(c) and (c.has_meta("phone_boost_flying") or c.has_meta("phone_center_wait") \
				or c.has_meta("phone_center_hold")):
			return true
	if action_banner_up and current_action_banner == "BOOST":
		return true
	for ev in game.events_ahead:
		if ev is Dictionary and ev.get("event_type", -1) == Enums.EventType.EventType_Boost_Played:
			return true
	return false

# ---- Boosts being played: not shown over the characters -----------------------------------
# The boosted card is kept out of sight while it is played; an instant (immediate) boost's text
# shows at the top of its player's boost window until it has resolved.
var _hidden_boost_cards : Array = []
var _resolving_boost : Array = [null, null]

func boost_card_played(card, is_player : bool, facedown = false) -> void:
	facedown = facedown == true # (the event sends null for a normal, face-up boost)
	if card == null or not is_instance_valid(card):
		return
	card.set_meta("phone_boost_hidden", true)
	# It flies into its player's boost box (instead of to the strike area), shrinking as cards
	# do on their way to the discard pile / gauge, and is hidden once it arrives.
	var zone = game.get_node_or_null("PlayerBoostZone" if is_player else "OpponentBoostZone")
	var om = zone.get_node_or_null("OuterMargin") if zone != null else null
	if om != null and card.state == CardBase.CardState.CardState_Discarding:
		card.target_pos = om.get_global_rect().get_center()
		card.target_scale = CardBase.phone_discard_scale
		card.resting_scale = card.target_scale
		card.card_features.visible = true
		card.set_meta("phone_boost_flying", true)
		# Like any card going to an area: by way of the screen center (both players' boosts).
		if USE_CENTER_STOP_FLIGHTS:
			_fly_via_center(card, card.return_state, CardBase.phone_discard_scale, is_player)
	else:
		card.card_features.visible = false
	if not card in _hidden_boost_cards:
		_hidden_boost_cards.append(card)
	# Its text shows in the boost box as soon as the card gets there (_update_hidden_boosts), until
	# the boost has resolved into the box (or been discarded).
	card.set_meta("phone_boost_side", 0 if is_player else 1)
	card.set_meta("phone_boost_facedown", facedown)
	if not card.has_meta("phone_boost_flying") and not facedown:
		_show_resolving_boost(card)

func _show_resolving_boost(card) -> void:
	var side : int = int(card.get_meta("phone_boost_side", 0))
	var lc = game.game_wrapper.get_card_database().get_card(card.card_id)
	if lc != null and str(lc.definition.get("boost", {}).get("boost_type", "")) != "immediate":
		# A continuous boost: its box text (as it will read once in play), not the card's whole text.
		if not card in _pending_boosts[side]:
			_pending_boosts[side].append(card)
	else:
		_resolving_boost[side] = card
		_boost_linger[side] = false
	_refresh_boost_summary(side)

var _pending_boosts : Array = [[], []]

# Continuous boosts that have reached a side's boost box but are still resolving (Game shows them
# in the box summary already).
func pending_boost_cards(side : int) -> Array:
	var striking = game.get_node_or_null("AllCards/Striking")
	var keep := []
	for c in _pending_boosts[side]:
		if is_instance_valid(c) and c.get_parent() == striking:
			keep.append(c)
	_pending_boosts[side] = keep
	return keep

# Boost box wording: a start-of-turn trigger reads "Start:", and a boost that refers to itself
# ("add this to your Gauge", "Discard this boost", "Add card to gauge"...) names itself instead.
var _start_re : RegEx
var _self_res : Array = []
func phrase_boost_text(text : String, bname : String) -> String:
	if _start_re == null:
		_start_re = RegEx.create_from_string("(?i)\\bat (?:the )?start of (?:your |your next |next )?turn\\s*[,:]?\\s*")
		for pat in ["(?i)\\bthis boost's\\b", "(?i)\\bthis boost\\b", "(?i)\\bthis card\\b",
				"(?i)\\b(add|return|sustain|discard|seal) this\\b(?! space)",
				"(?i)\\b(add) card(?= to gauge(?! after strike))"]:
			_self_res.append(RegEx.create_from_string(pat))
	var t := text
	# (A timing already in bold loses its own bold tags first.)
	t = RegEx.create_from_string("(?i)\\[b\\]\\s*(at (?:the )?start of (?:your |your next |next )?turn\\s*[,:]?)\\s*\\[/b\\]\\s*").sub(t, "$1 ", true)
	# "Start:" (bold), with the next word capitalised.
	var out := ""
	var pos := 0
	for m in _start_re.search_all(t):
		out += t.substr(pos, m.get_start() - pos) + "[b]Start:[/b] "
		pos = m.get_end()
		if pos < t.length():
			out += t[pos].to_upper()
			pos += 1
	t = out + t.substr(pos)
	if bname != "":
		for i in range(_self_res.size()):
			var rep_s : String = (bname + "'s") if i == 0 else (("$1 " + bname) if i >= 3 else bname)
			t = _self_res[i].sub(t, rep_s, true)
	return t

# Instant boosts that read differently in the boost box while they resolve.
const RESOLVING_BOOST_TEXT := {
	"Matsuri -Rock Parade-": "Reading the opponent...",
}

# The instant boost resolving on a side, as boost window text ("" when none).
func resolving_boost_text(side : int) -> String:
	var card = _resolving_boost[side]
	if card == null or not is_instance_valid(card):
		return ""
	var own = RESOLVING_BOOST_TEXT.get(str(card.card_boost_name))
	if own != null:
		return str(own)
	var body := phrase_boost_text(_boost_bbcode(card).strip_edges().replace("\n", " "), str(card.card_boost_name))
	if body == "":
		return "[b]%s[/b]" % str(card.card_boost_name)
	return "[b]%s:[/b] %s" % [str(card.card_boost_name), body]

func _update_hidden_boosts() -> void:
	if _hidden_boost_cards.is_empty():
		return
	var striking = game.get_node_or_null("AllCards/Striking")
	var now := Time.get_ticks_msec()
	for card in _hidden_boost_cards.duplicate():
		if not is_instance_valid(card):
			_hidden_boost_cards.erase(card)
			continue
		if card.has_meta("phone_boost_flying") and (card.get_parent() != striking \
				or card.state != CardBase.CardState.CardState_Discarding):
			# Arrived in the boost box (or already sent on): gone from sight, its text up.
			card.remove_meta("phone_boost_flying")
			card.card_features.visible = false
			if card.get_parent() == striking and not bool(card.get_meta("phone_boost_facedown", false)):
				_show_resolving_boost(card)
		if card.get_parent() == striking:
			continue
		for sd in range(2):
			if card in _pending_boosts[sd]:
				_pending_boosts[sd].erase(card)
				_refresh_boost_summary(sd)
		# Resolved: it has left for the boost area / discard pile. (An instant boost that starts a
		# strike keeps its text up until that strike's card is chosen: _track_boost_linger.)
		for side in range(2):
			if _resolving_boost[side] == card and not _boost_linger[side]:
				if _boost_starts_strike(card):
					_boost_linger[side] = true
				else:
					_resolving_boost[side] = null
					_refresh_boost_summary(side)
		# Shown again once it has finished flying there (it never appears over the characters).
		if not card.has_meta("phone_unhide_at"):
			card.set_meta("phone_unhide_at", now + int(900 / ANIM_PACE))
		elif now >= int(card.get_meta("phone_unhide_at")):
			card.remove_meta("phone_unhide_at")
			card.remove_meta("phone_boost_hidden")
			if not card.has_meta("phone_parked") and not card.has_meta("ex_hidden"):
				card.card_features.visible = true
			_hidden_boost_cards.erase(card)

var _boost_linger : Array = [false, false]

func _boost_starts_strike(card) -> bool:
	var lc = game.game_wrapper.get_card_database().get_card(card.card_id)
	if lc == null:
		return false
	var b = lc.definition.get("boost", {})
	return str(b.get("boost_type", "")) == "immediate" and JSON.stringify(b).contains("\"effect_type\":\"strike")

# A lingering instant boost's text goes once its strike has been declared (the card chosen), or
# the turn is over.
func _track_boost_linger(event) -> void:
	if not (_boost_linger[0] or _boost_linger[1]):
		return
	var E = Enums.EventType
	var et = event["event_type"]
	var pid := int(event["event_player"])
	var side := 0 if pid == int(Enums.PlayerId.PlayerId_Player) else 1
	var sides : Array = []
	if et in [E.EventType_Strike_Started, E.EventType_Strike_Started_Ex, E.EventType_Strike_WildStrike,
			E.EventType_Strike_Reveal]:
		sides = [side] if et != E.EventType_Strike_Reveal else [0, 1]
	elif et == E.EventType_AdvanceTurn:
		sides = [0, 1]
	for sd in sides:
		if _boost_linger[sd]:
			_boost_linger[sd] = false
			_resolving_boost[sd] = null
			_refresh_boost_summary(sd)

# ---- Stat gem badges ------------------------------------------------------------------------
# Five badges (Range, Power, Speed, Armor, Guard: always in that order and slot) sit right above
# each player's boost / bonus box, each a cut gem in its stat's colour showing the modifier. A
# badge only shows while its stat is modified. Outside a strike they show what the boosts in play
# add; during a strike they follow every stat change as it happens (boosts, hit effects...),
# rolling up like a slot machine. Set USE_STAT_GEMS to false to go back to the stat text in the
# boost box and the floating stat notices.
const USE_STAT_GEMS := true
const GEM_STATS := ["Range", "Power", "Speed", "Armor", "Guard"]
const GEM_H := 44.0 # about a collapsed boost box
var _gems : Array = [[], []]
var _boost_stats : Array = [{}, {}]  # stat -> [lo, hi], from the boosts in play
var _strike_stats : Array = [{}, {}] # stat -> [lo, hi], from stat changes during this strike
var _gem_strike : bool = false

func set_boost_stats(side : int, totals : Dictionary) -> void:
	_boost_stats[side] = totals.duplicate(true)
	_update_gem_values()

func _track_stat_gems(event) -> void:
	if not USE_STAT_GEMS:
		return
	var E = Enums.EventType
	var et = event["event_type"]
	_track_strike_cards(event)
	if et in [E.EventType_Strike_Started, E.EventType_Strike_Started_Ex, E.EventType_Strike_WildStrike] and not _gem_strike:
		_gem_strike = true
		_strike_stats = [{}, {}]
		return
	if et == E.EventType_Strike_Cleanup:
		_gem_strike = false
		_strike_stats = [{}, {}]
		_strike_card_ids = [-1, -1]
		_strike_x = [null, null]
		_strike_revealed = false
		_update_gem_values()
		return
	var stat := ""
	match et:
		E.EventType_Strike_PowerUp: stat = "Power"
		E.EventType_Strike_SpeedUp: stat = "Speed"
		E.EventType_Strike_ArmorUp: stat = "Armor"
		E.EventType_Strike_GuardUp: stat = "Guard"
		E.EventType_Strike_RangeUp: stat = "Range"
	if stat == "" or str(event.get("reason", "")) == "powerup_per_sealed_amount":
		return
	var pid := int(event["event_player"])
	if pid != int(Enums.PlayerId.PlayerId_Player) and pid != int(Enums.PlayerId.PlayerId_Opponent):
		return
	var side := 0 if pid == int(Enums.PlayerId.PlayerId_Player) else 1
	var lo := int(event.get("number", 0))
	var hi := lo
	if stat == "Range" and str(event.get("extra_info", "")).is_valid_int():
		hi = int(event["extra_info"])
	var cur : Array = _strike_stats[side].get(stat, [0, 0])
	_strike_stats[side][stat] = [cur[0] + lo, cur[1] + hi]
	_update_gem_values()

# ---- Strike totals in the gems --------------------------------------------------------------
# During a strike, once both cards are face up, each gem adds its card's printed stat, so it
# shows the total in effect instead of the modifier. Set SHOW_STRIKE_BASE_STATS to false to go
# back to modifiers only (and fading gems).
const SHOW_STRIKE_BASE_STATS := true
var _strike_card_ids : Array = [-1, -1]
var _strike_x : Array = [null, null] # a card's X, once set
var _strike_revealed : bool = false

func _track_strike_cards(event) -> void:
	var E = Enums.EventType
	var et = event["event_type"]
	# (the reveal itself comes from StrikeStage once the plate has slid in and the cards have flipped:
	# on_strike_cards_flipped)
	if et == E.EventType_Strike_Reveal:
		return
	if not SHOW_STRIKE_BASE_STATS:
		return
	var pid := int(event["event_player"])
	if pid != int(Enums.PlayerId.PlayerId_Player) and pid != int(Enums.PlayerId.PlayerId_Opponent):
		return
	var side := 0 if pid == int(Enums.PlayerId.PlayerId_Player) else 1
	match et:
		E.EventType_Strike_Started, E.EventType_Strike_Started_Ex, E.EventType_Strike_WildStrike, \
				E.EventType_Strike_Response, E.EventType_Strike_Response_Ex:
			var num := int(event.get("number", -1))
			if num >= 0:
				_strike_card_ids[side] = num
		E.EventType_Strike_SetX:
			_strike_x[side] = int(event.get("number", 0))
			_update_gem_values()

# The strike cards have turned face up on the plate: the gems show the strike from now on.
func on_strike_cards_flipped() -> void:
	if _gem_strike and not _strike_revealed:
		_strike_revealed = true
		_update_gem_values()

# The printed stat of a side's strike card as [lo, hi] (Range: min and max), or [] when it isn't
# known yet (cards still face down, or a value like "X" not set).
func _strike_base_stat(side : int, stat : String) -> Array:
	if not SHOW_STRIKE_BASE_STATS or not _gem_strike or not _strike_revealed or _strike_card_ids[side] < 0:
		return []
	var lc = game.game_wrapper.get_card_database().get_card(_strike_card_ids[side])
	if lc == null:
		return []
	var d : Dictionary = lc.definition
	if stat == "Range":
		var lo = _stat_number(side, d.get("range_min", null))
		var hi = _stat_number(side, d.get("range_max", null))
		if lo == null or hi == null:
			return []
		return [lo, hi]
	var n = _stat_number(side, d.get(stat.to_lower(), null))
	return [] if n == null else [n, n]

func _stat_number(side : int, v):
	if v == null:
		return null
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return int(v)
	if str(v).is_valid_int():
		return int(str(v))
	if str(v) == "X" and _strike_x[side] != null:
		return int(_strike_x[side])
	return null

# ---- Life gem --------------------------------------------------------------------------------
# When a player takes damage (or gains life), a big gem (in the life bars' orange) pops up in the
# middle of their character's area showing their life, rolls down (or up) to the new total like a
# slot machine reel, then pops away. The floating "3 Damage" / "+2 Life" text is skipped then. Set USE_LIFE_GEM to false to turn it off.
const USE_LIFE_GEM := true
var _life_gems : Array = [null, null]
var _life_gem_tokens : Array = [0, 0]

func _track_life_gem(event) -> void:
	if not USE_LIFE_GEM:
		return
	# Damage (not life paid as a cost) rolls the life down; healing rolls it up.
	var et = event["event_type"]
	var change := 0
	if et == Enums.EventType.EventType_Strike_TookDamage and str(event.get("reason", "")) != "spend":
		change = -int(event.get("number", 0))
	elif et == Enums.EventType.EventType_Strike_GainLife:
		change = int(event.get("number", 0))
	if change == 0 or not str(event.get("extra_info", "")).is_valid_int():
		return
	var pid := int(event["event_player"])
	if pid != int(Enums.PlayerId.PlayerId_Player) and pid != int(Enums.PlayerId.PlayerId_Opponent):
		return
	var side := 0 if pid == int(Enums.PlayerId.PlayerId_Player) else 1
	var new_life := int(event["extra_info"])
	_show_life_gem(side, new_life - change, new_life)

func _show_life_gem(side : int, old_life : int, new_life : int) -> void:
	_life_gem_tokens[side] += 1
	var token : int = _life_gem_tokens[side]
	var g = _life_gems[side]
	if g != null and is_instance_valid(g) and g.visible and g.modulate.a > 0.5:
		g.set_value(new_life, new_life) # (still up from a hit just before: rolls on from there)
	else:
		g = load("res://scenes/game/stat_gem.gd").new()
		g.color = LIFE_BORDER
		g.absolute = true
		g.force_show = true
		g.step_time = 0.14
		g.z_index = 9 # over the characters, under focused cards
		var gw := (W / 2.0 - 8.0 - 4.0 * (GEM_STATS.size() - 1)) / GEM_STATS.size()
		g.size = Vector2(gw, GEM_H) * 2.5
		var center := Vector2(W * (0.25 if side == 0 else 0.75), stage_y + stage_h * 0.5)
		g.position = center - g.size / 2.0
		backdrop.add_child(g)
		_life_gems[side] = g
		g.set_value(old_life, old_life) # pops in showing the life before the hit
		await get_tree().create_timer(_pt(0.45)).timeout
		if not is_instance_valid(g) or token != _life_gem_tokens[side]:
			return
		g.set_value(new_life, new_life)
	# Once the reel has stopped (and a moment to read it), it pops away.
	await get_tree().create_timer(_pt(0.1)).timeout
	while is_instance_valid(g) and g.is_rolling():
		await get_tree().create_timer(_pt(0.05)).timeout
	await get_tree().create_timer(_pt(0.7)).timeout
	if is_instance_valid(g) and token == _life_gem_tokens[side]:
		_life_gems[side] = null
		g.pop_out(true)

# What each badge shows: during a strike, the changes so far (the boosts' own changes arrive as
# the strike applies them; until a stat has changed, its boost total shows); otherwise the boosts'.
func _update_gem_values() -> void:
	for side in range(2):
		if _gems[side].is_empty():
			continue
		for i in range(GEM_STATS.size()):
			var stat : String = GEM_STATS[i]
			var v : Array = [0, 0]
			# Until the strike cards are face up, the gems keep showing just the boosts in play:
			# nothing from the strike itself appears yet.
			var strike_shown : bool = _gem_strike and _strike_revealed
			if strike_shown and _strike_stats[side].has(stat):
				v = _strike_stats[side][stat]
			elif not _boost_stat_total(side, stat).is_empty():
				v = _boost_stat_total(side, stat) # (the opponent's boosts' changes too)
			# An EX attack (EX strike, or a boost like Badass! making it EX): +1 to all but Range.
			if stat != "Range" and (_boost_status[side].has("ex") or (strike_shown and _strike_status[side].has("ex"))):
				v = [int(v[0]) + 1, int(v[1]) + 1]
			# Once the strike cards are face up, the gems show the totals in effect: the card's
			# printed stat plus all of that (Range, Power and Speed always show; Armor and Guard
			# when not 0).
			var base : Array = _strike_base_stat(side, stat)
			var gem = _gems[side][i]
			if base.is_empty():
				gem.set_mode(false, false)
			else:
				v = [int(v[0]) + int(base[0]), int(v[1]) + int(base[1])]
				gem.set_mode(true, stat in ["Range", "Power", "Speed"])
			gem.set_value(int(v[0]), int(v[1]))

# Lays out a side's badges in one row whose bottom edge is at `bottom_y`; returns the row's top
# when any badge is showing (else `bottom_y`).
func _place_stat_gems(side : int, _x : float, bottom_y : float, row_w : float) -> float:
	if _gems[side].is_empty():
		for i in range(GEM_STATS.size()):
			var g = load("res://scenes/game/stat_gem.gd").new()
			g.color = Color(STAT_COLORS[GEM_STATS[i]])
			g.z_index = 2 # (under the gold turn frame, z 3, and focused cards)
			g.pop_out_on_hide = SHOW_STRIKE_BASE_STATS # (pops away like the life gem)
			backdrop.add_child(g)
			_gems[side].append(g)
		_update_gem_values()
	# The same size as when they sat in a row (a fifth of the row, less the gaps), but stacked in
	# a column down the inner edge of that side's character area (the center line), just inside
	# the gold turn frame: Range at the top, right under the TURN switch, then Power, Speed, Armor
	# and Guard. (Each keeps its own slot, so a stat without a value just leaves its gap.)
	var gap := 4.0
	var gw := (row_w - gap * (GEM_STATS.size() - 1)) / GEM_STATS.size()
	var gx : float = (W / 2.0 - GEM_CENTER_INSET - gw) if side == 0 else (W / 2.0 + GEM_CENTER_INSET)
	var top : float = _turn_switch_bottom() + GEM_SWITCH_GAP
	for i in range(GEM_STATS.size()):
		var g = _gems[side][i]
		g.size = Vector2(gw, GEM_H)
		g.position = Vector2(gx, top + i * (GEM_H + gap))
	return bottom_y # (no longer above the bonus box: nothing there moves up for them)

# From the center line to the gems' inner edge: clear of the gold turn frame (inset 3, 4 wide).
const GEM_CENTER_INSET := 7.0
const GEM_SWITCH_GAP := 4.0 # (between the TURN switch and the Range gem under it)

# The bottom of the TURN switch's track (see _update_turn_badge).
func _turn_switch_bottom() -> float:
	var y := stage_y + 36.0 + (LAST_ACTION_H - TURN_BADGE_H) / 2.0
	return y + TURN_BADGE_H + TURN_TRACK_PAD

# ---- Boost window: all the stat changes added up on the first line ---------------------------
# Lines that are only stat changes (from every boost) are summed into one first line, comma
# separated ("+2 Power, +1 Speed"); every other line is listed below it as it was.
var _stat_tok_re : RegEx
const STAT_ORDER := ["Range", "Power", "Speed", "Armor", "Guard"]
func combine_stat_lines(text : String, side : int = -1) -> String:
	if _stat_tok_re == null:
		_stat_tok_re = RegEx.new()
		_stat_tok_re.compile("([+\\-]\\d+)(?:\\s*-\\s*([+\\-]?\\d+))?\\s+(Range|Power|Speed|Armor|Guard)\\b")
	join_stat_lines("") # (makes the tag regex)
	var totals := {}
	var kept : Array[String] = []
	for ln in text.split("\n"):
		var plain := _bb_tag_re.sub(ln, "", true).strip_edges()
		if plain == "":
			continue
		if ln.contains("[TF]"):
			kept.append(ln) # transforms keep their own line (and marker)
			continue
		if _is_pure_stat(plain):
			_add_stat_totals(totals, plain)
			continue
		if USE_STAT_GEMS and side >= 0:
			# A printed line that starts with its stat change ("+4 Guard. At the start of your
			# turn..."): the stat sentence goes to the gems, the rest of the line stays.
			var segs := ln.split(". ")
			var keep_segs : Array[String] = []
			for seg in segs:
				var sp := _bb_tag_re.sub(seg, "", true).strip_edges()
				if sp != "" and _is_pure_stat(sp):
					_add_stat_totals(totals, sp)
				else:
					keep_segs.append(seg)
			if keep_segs.size() < segs.size():
				var rebuilt := ". ".join(keep_segs).strip_edges()
				if _bb_tag_re.sub(rebuilt, "", true).strip_edges() != "":
					kept.append(rebuilt)
				continue
		kept.append(ln)
	if side >= 0:
		set_boost_stats(side, totals)
		if USE_STAT_GEMS:
			return "\n".join(kept) # (the stat changes show in the gem badges instead)
	var parts : Array[String] = []
	for stat in STAT_ORDER:
		if not totals.has(stat):
			continue
		var lo : int = totals[stat][0]
		var hi : int = totals[stat][1]
		if lo == 0 and hi == 0:
			continue
		var amt := ("+%d" % lo) if lo >= 0 else str(lo)
		if hi != lo:
			amt += "-%d" % hi if hi >= 0 else "-(%d)" % hi
		parts.append("%s %s" % [amt, stat])
	if not parts.is_empty():
		kept.push_front(", ".join(parts))
	return "\n".join(kept)

# A piece of text made only of stat changes ("+1 Power", "+1 Power, +1 Speed.").
func _is_pure_stat(plain : String) -> bool:
	if _stat_tok_re.search(plain) == null:
		return false
	var rest := _stat_tok_re.sub(plain, "", true).replace(",", " ").replace(".", " ").replace(" and ", " ").strip_edges()
	return rest == "" or rest == "and"

func _add_stat_totals(totals : Dictionary, plain : String) -> void:
	for m in _stat_tok_re.search_all(plain):
		var stat := m.get_string(3)
		var lo := int(m.get_string(1))
		var hi := int(m.get_string(2)) if m.get_string(2) != "" else lo
		var cur : Array = totals.get(stat, [0, 0])
		totals[stat] = [cur[0] + lo, cur[1] + hi]

# True when this effect text will still show in the boost box (with the stat gems on, lines that
# are only stat changes go to the gems instead).
func boost_text_shows(text : String) -> bool:
	if _stat_tok_re == null:
		combine_stat_lines("") # (makes the regexes)
	for ln in text.split("\n"):
		var plain := _bb_tag_re.sub(ln, "", true).strip_edges()
		if plain == "":
			continue
		if not USE_STAT_GEMS or ln.contains("[TF]"):
			return true
		var rest := _stat_tok_re.sub(plain, "", true).replace(",", " ").replace(".", " ").replace(" and ", " ").strip_edges()
		if _stat_tok_re.search(plain) == null or (rest != "" and rest != "and"):
			return true
	return false

# Puts a boost's stat bonuses on one line ("+1 Power +1 Armor"), as printed on the cards,
# instead of one per line.
var _stat_line_re : RegEx
var _bb_tag_re : RegEx
func join_stat_lines(text : String) -> String:
	if _stat_line_re == null:
		_stat_line_re = RegEx.new()
		_stat_line_re.compile("^[+\\-]\\d+(\\s*-\\s*[+\\-]?\\d+)?\\s+(Power|Speed|Range|Armor|Guard)$")
		_bb_tag_re = RegEx.new()
		_bb_tag_re.compile("\\[[^\\]]*\\]")
	var out : Array[String] = []
	var prev_stat := false
	for ln in text.split("\n"):
		var plain := _bb_tag_re.sub(ln, "", true).strip_edges()
		var is_stat := _stat_line_re.search(plain) != null
		if is_stat and prev_stat and not out.is_empty():
			out[out.size() - 1] = out[out.size() - 1].strip_edges(false, true) + " " + ln.strip_edges()
		else:
			out.append(ln)
		prev_stat = is_stat
	return "\n".join(out)

# Printed wording in the boost windows on the board, where statuses shown as badges are left out.
const PRINTED_BOOST_AREA_TEXT := {
	"Drunkard Shade": "At the start of your turn, add this to your Gauge.",
	# Faust's items affect both players (shown in both players' boost boxes, see below).
	"Banana Peel/Donut": "[b]Before:[/b] Advance 1\n[b]After:[/b] Discard Donut",
	"Bomb/Meteors": "Take 3 non-lethal damage. Discard Meteors",
}

# A continuous boost whose effects apply to both players (Faust's Donut, Meteors...): its text is
# also listed in the other player's boost box while it is in play. Returns those lines for `side`.
func shared_boost_lines(side : int) -> Array:
	var out : Array = []
	var holder = game.get_node_or_null("AllCards/OpponentBoosts" if side == 0 else "AllCards/PlayerBoosts")
	if holder == null:
		return out
	var db = game.game_wrapper.get_card_database()
	for c in holder.get_children():
		var lc = db.get_card(c.card_id)
		if lc == null or str(lc.definition.get("boost", {}).get("boost_type", "")) != "continuous":
			continue
		var both := false
		for e in lc.definition["boost"].get("effects", []):
			if e is Dictionary and str(e.get("timing", "")).begins_with("both_players"):
				both = true
		if not both:
			continue
		var t := boost_text_override(lc.definition, true)
		if t == "":
			t = str(GameStrings.get_boost_text(lc.definition["boost"]["effects"])).strip_edges()
		if t != "":
			out.append(phrase_boost_text(t, str(lc.definition["boost"].get("display_name", ""))))
	return out

func boost_text_override(card_def : Dictionary, for_boost_area : bool = false) -> String:
	var boost = card_def.get("boost", {})
	var bname := str(boost.get("display_name", ""))
	if for_boost_area and PRINTED_BOOST_AREA_TEXT.has(bname):
		return str(PRINTED_BOOST_AREA_TEXT[bname])
	return str(PRINTED_BOOST_TEXT.get(bname, ""))

# ---- Boost effects shown as status badges ---------------------------------------------------------
# A boost's unconditional during-strike stun immunity, ignore armor, ignore guard and dodge (at a
# fixed range) are shown as badges for as long as the boost is in play, and left out of the boost
# window's text. Fills `found` (kind -> true, or the label for "dodge") and returns the effects
# that are still to be listed as text.
func extract_badge_effects(effects : Array, found : Dictionary) -> Array:
	var out : Array = []
	for e in effects:
		if e is Dictionary and str(e.get("effect_type", "")) == "opponent_wild_swings" and not e.has("condition"):
			found["forces_wild"] = true # (Scramble: a WILD SWING badge on the opponent, see below)
			continue # (shown by the badge, not in the boost box)
		if not (e is Dictionary) or str(e.get("timing", "")) != "during_strike" or e.has("condition") \
				or e.has("override_description"):
			out.append(e)
			continue
		var rest = _strip_badge_chain(e.duplicate(true), found)
		if rest != null:
			rest["timing"] = e["timing"]
			out.append(rest)
	return out

# In the boost box a boost goes by its boost name: effects that name the card by its attack
# name ("Hit: Add Issei Ougi: Sai to gauge" for Fuuga) name the boost instead.
func rename_boost_card_refs(effects : Array, card_def : Dictionary) -> Array:
	var bname := str(card_def.get("boost", {}).get("display_name", ""))
	if bname == "":
		return effects
	var out : Array = []
	for e in effects:
		out.append(_rename_ref(e, bname))
	return out

func _rename_ref(e, bname : String):
	if not (e is Dictionary):
		return e
	if not (str(e.get("effect_type", "")) in ["add_boost_to_gauge_on_strike_cleanup", "discard_this"]) and not e.has("and"):
		return e
	var d : Dictionary = e.duplicate(true)
	if str(d.get("effect_type", "")) in ["add_boost_to_gauge_on_strike_cleanup", "discard_this"] and d.has("card_name"):
		d["card_name"] = bname
	if d.has("and"):
		d["and"] = _rename_ref(d["and"], bname)
	return d

func _badge_kind(e : Dictionary) -> String:
	if e.has("condition") or e.get("opponent", false):
		return ""
	var t := str(e.get("effect_type", ""))
	if t == "dodge_at_range":
		if e.get("from_buddy", false) or e.has("special_range") or not e.has("range_min") or not e.has("range_max"):
			return ""
		return "dodge"
	if t == "dodge_attacks":
		return "dodge"
	if t == "attack_is_ex":
		return "ex" # (Badass!: the EX badge, and +1 in the four EX stat gems)
	if STATUS_BADGES.has(t):
		return t
	return ""

# Takes the badge effects out of an "and" chain; returns what is left (null if nothing).
func _strip_badge_chain(e, found : Dictionary):
	if not (e is Dictionary):
		return null
	var rest = _strip_badge_chain(e["and"], found) if e.has("and") else null
	var kind := _badge_kind(e)
	if kind != "":
		if kind == "dodge":
			found["dodge"] = "DODGE" if str(e.get("effect_type")) == "dodge_attacks" \
					else _dodge_range_label(int(e["range_min"]), int(e["range_max"]))
		else:
			found[kind] = true
		return rest
	if rest == null:
		e.erase("and")
	else:
		e["and"] = rest
	return e

# ---- Boosts that change the opponent's stats --------------------------------------------------
# A boost's unconditional during-strike change to the OPPONENT's stats ("Opponent +3 Power": Daijoubu!,
# Stylish, Zephyr, False Life, Enervation's -1 Range...) shows in the opponent's stat gems and is
# left out of the boost box, like a boost's own stat changes.
var _opp_boost_stats : Array = [{}, {}] # per side: stat -> [lo, hi], from the OTHER side's boosts
var _opp_stat_re : RegEx

func _opponent_stat_of(e : Dictionary) -> String:
	if _opp_stat_re == null:
		_opp_stat_re = RegEx.new()
		_opp_stat_re.compile("^(opponent_)?(power|speed|armor|guard|range)up(_opponent)?$")
	if e.has("condition") or e.get("describe_as_self", false):
		return ""
	var m := _opp_stat_re.search(str(e.get("effect_type", "")))
	if m == null:
		return ""
	if m.get_string(1) == "" and m.get_string(3) == "" and not e.get("opponent", false):
		return ""
	return m.get_string(2).capitalize()

# An effect's stat change as [lo, hi] (Range: amount and amount2), or [] when not a plain number.
func _stat_amounts(e : Dictionary, stat : String) -> Array:
	var a = e.get("amount", null)
	if a == null or not str(a).is_valid_float():
		return []
	var lo := int(float(str(a)))
	var hi := lo
	if stat == "Range" and e.has("amount2") and str(e["amount2"]).is_valid_float():
		hi = int(float(str(e["amount2"])))
	return [lo, hi]

# Takes a boost's opponent stat changes out of its effects (adding them up in `totals`); returns
# the effects still to be listed.
func extract_opponent_stat_effects(effects : Array, totals : Dictionary) -> Array:
	var out : Array = []
	for e in effects:
		if not (e is Dictionary) or str(e.get("timing", "")) != "during_strike" or e.has("condition") \
				or e.has("override_description"):
			out.append(e)
			continue
		var rest = _strip_opp_stat_chain(e.duplicate(true), totals)
		if rest != null:
			rest["timing"] = e["timing"]
			out.append(rest)
	return out

func _strip_opp_stat_chain(e, totals : Dictionary):
	if not (e is Dictionary):
		return null
	var rest = _strip_opp_stat_chain(e["and"], totals) if e.has("and") else null
	var stat := _opponent_stat_of(e)
	if stat != "":
		var a := _stat_amounts(e, stat)
		if not a.is_empty():
			var cur : Array = totals.get(stat, [0, 0])
			totals[stat] = [int(cur[0]) + int(a[0]), int(cur[1]) + int(a[1])]
			return rest
	if rest == null:
		e.erase("and")
	else:
		e["and"] = rest
	return e

# Game.update_boost_summary: what one side's boosts do to the other side's stats.
func set_opponent_boost_stats(target_side : int, totals : Dictionary) -> void:
	if _opp_boost_stats[target_side] == totals:
		return
	_opp_boost_stats[target_side] = totals.duplicate(true)
	_update_gem_values()

# A side's stat from the boosts in play (theirs and the opponent's), or [] when none change it.
func _boost_stat_total(side : int, stat : String) -> Array:
	var found := false
	var v := [0, 0]
	for d in [_boost_stats[side], _opp_boost_stats[side]]:
		if d.has(stat):
			found = true
			v = [v[0] + int(d[stat][0]), v[1] + int(d[stat][1])]
	return v if found else []

# ---- A boost leaving play mid-strike -----------------------------------------------------------
# When a boost leaves play during a strike (Sukiyaki!'s "After: add this to gauge, undoing its
# effects"), the game takes back what it gave the strike: so do its gems and badges, as it goes.
var _boost_card_ids : Array = [[], []]

# Game.update_boost_summary: the cards in a side's boost area now.
func note_boost_cards(side : int, ids : Array) -> void:
	var gone : Array = []
	if _gem_strike and not _in_cleanup:
		for id in _boost_card_ids[side]:
			if not id in ids:
				gone.append(id)
	_boost_card_ids[side] = ids.duplicate()
	var changed := false
	for id in gone:
		var lc = game.game_wrapper.get_card_database().get_card(id)
		if lc == null or str(lc.definition.get("boost", {}).get("boost_type", "")) != "continuous":
			continue
		for e in lc.definition["boost"].get("effects", []):
			if e is Dictionary and str(e.get("timing", "")) == "during_strike":
				changed = _revert_boost_effect(side, e) or changed
	if changed:
		_update_gem_values()

# Takes back one of the boost's during-strike effects (and those chained to it) as the game does:
# its own stat changes (Range may be the opponent's), a range dodge, EX.
func _revert_boost_effect(side : int, e : Dictionary) -> bool:
	if e.has("condition"):
		return false # (it may never have applied)
	var any := false
	var et := str(e.get("effect_type", ""))
	match et:
		"powerup", "speedup", "armorup", "guardup", "rangeup":
			var tgt := (1 - side) if e.get("opponent", false) else side
			var stat := et.trim_suffix("up").capitalize()
			var a := _stat_amounts(e, stat)
			if not a.is_empty() and _strike_stats[tgt].has(stat):
				var cur : Array = _strike_stats[tgt][stat]
				_strike_stats[tgt][stat] = [int(cur[0]) - int(a[0]), int(cur[1]) - int(a[1])]
				any = true
		"dodge_at_range":
			if _strike_dodge[side]:
				_strike_dodge[side] = false
				if not _boost_status[side].has("dodge"):
					_hide_dodge(side)
				any = true
		"attack_is_ex":
			if _strike_status[side].has("ex"):
				_strike_status[side].erase("ex")
				if not _boost_status[side].has("ex"):
					_hide_status(side, "ex")
				any = true
	if e.get("and") is Dictionary:
		any = _revert_boost_effect(side, e["and"]) or any
	return any

func _boost_bbcode(card) -> String:
	var db = game.game_wrapper.get_card_database()
	var lc = db.get_card(card.card_id)
	if lc == null:
		return ""
	var printed := boost_text_override(lc.definition)
	if printed != "":
		return printed
	var txt : String = join_stat_lines(str(GameStrings.get_boost_text(lc.definition["boost"].get("effects", []))).strip_edges())
	return color_stat_text(txt)

# Stat changes ("+1 Power", "Range -1", "+2-3 Range"...) in bold, in their stat's colour and
# with the stat capitalized, as in the boost reference. Used for the boost reference and the
# boost windows on the board. Text already inside a [color] tag is left as it is.
var _colored_span_re : RegEx
func color_stat_text(txt : String) -> String:
	if _stat_re == null:
		_stat_re = RegEx.new()
		_stat_re.compile("(?i)\\b(Range|Power|Speed|Armor|Guard)\\s*([+\\-]\\s*(?:\\d+|X)(?:\\s*-\\s*[+\\-]?\\d+)?)|([+\\-]\\s*(?:\\d+|X)(?:\\s*-\\s*[+\\-]?\\d+)?)\\s*(Range|Power|Speed|Armor|Guard)\\b")
		_colored_span_re = RegEx.new()
		_colored_span_re.compile("(?s)\\[color=[^\\]]*\\].*?\\[/color\\]")
	var out := ""
	var pos := 0
	for span in _colored_span_re.search_all(txt):
		out += _color_stats_plain(txt.substr(pos, span.get_start() - pos)) + span.get_string()
		pos = span.get_end()
	return out + _color_stats_plain(txt.substr(pos))

func _color_stats_plain(txt : String) -> String:
	var out := ""
	var pos := 0
	for m in _stat_re.search_all(txt):
		out += txt.substr(pos, m.get_start() - pos)
		var raw : String = m.get_string(1) if m.get_string(1) != "" else m.get_string(4)
		var stat := raw.capitalize()
		var shown := m.get_string()
		if m.get_string(1) != "":
			shown = stat + shown.substr(raw.length())
		else:
			shown = shown.substr(0, shown.length() - raw.length()) + stat
		out += "[b][color=%s]%s[/color][/b]" % [STAT_COLORS.get(stat, "#ffffff"), shown]
		pos = m.get_end()
	out += txt.substr(pos)
	return out

func _ref_cell_style(selected : bool) -> StyleBox:
	var sb : StyleBoxFlat
	if selected:
		sb = _style(Color(0.30, 0.10, 0.28, 0.9), Color(1.0, 0.2, 0.8), 3, 6)
	else:
		sb = _style(Color(0.04, 0.06, 0.14, 0.78), Color(0.7, 0.8, 1.0, 0.35), 1, 6)
	sb.set_content_margin_all(0)
	return sb

# The BOOSTS bars let taps through (to the red / blue Boost / Strike areas underneath) while
# they are empty, since there is nothing to show, and while a card is focused (the preview's
# controls come earlier in the scene tree and would otherwise lose those taps).
func _update_boost_zone_taps(force : bool = false) -> void:
	for pair in BOOST_ZONE_PAIRS:
		var zone = game.get_node_or_null(pair[0])
		var cards = game.get_node_or_null(pair[1])
		if zone == null or cards == null:
			continue
		var off : bool = cards.get_child_count() == 0 or (preview_button != null and preview_button.visible)
		if force or off != bool(zone.get_meta("phone_taps_off", false)):
			zone.set_meta("phone_taps_off", off)
			_set_tree_input_ignored(zone.get_node("OuterMargin"), off)
	# Phone controls: the minimized action menu shows nothing (its eye button is hidden), but its
	# empty box would still swallow taps on the top of the red / blue areas.
	var am = game.action_menu
	if am != null and GlobalSettings.phone_controls_active():
		var am_off : bool = not am.showing
		if am_off != bool(am.get_meta("phone_taps_off", false)):
			am.set_meta("phone_taps_off", am_off)
			_set_tree_input_ignored(am, am_off)

# ---- Opponent's action, spelled out in their bar ----------------------------------------
# Their hand isn't fanned out; instead the action they take (PREPARE, MOVE, STRIKE...) shows
# in big bold capitals where it used to be, for as long as that action lasts (at least 1.5s).
var _opp_action_label : Label = null
var _opp_action_text : String = ""
var _opp_action_shown_at : float = 0.0
var _opp_action_clear_at : float = -1.0
var _ui_turn : int = -1

# Animation-paced time (seconds): runs at ANIM_PACE, like the animations, so waits measured with it
# keep step with them.
func _now_s() -> float:
	return Time.get_ticks_msec() / 1000.0 * ANIM_PACE

# ---- Animation pace ------------------------------------------------------------------------------
# All animations (tweens, card flights / focus, banners, plates...) and the event pacing run at
# this speed (1.0 = as designed), without slowing the rest of the game (timers, clocks...) the way
# Engine.time_scale (the speed menu) does.
const ANIM_PACE := 0.75

# A wait (seconds) at the animation pace.
func _pt(t : float) -> float:
	return t / ANIM_PACE

# Every running tween plays at the animation pace.
func _pace_tweens() -> void:
	for tw in get_tree().get_processed_tweens():
		if tw.is_valid():
			tw.set_speed_scale(ANIM_PACE)

# Called by Game._handle_events for every game event, before it is handled. When the opponent
# takes an action, its name sweeps across the screen in a banner like STRIKE! does, and the
# returned delay (seconds) holds the action back until the banner has gone.
func on_game_event(event) -> float:
	var E = Enums.EventType
	var et = event["event_type"]
	if not event.get("phone_logged", false):
		event["phone_logged"] = true
		_logged_new_action = -1
		_log_last_action(event)
		_track_multi_actions(event)
		_track_self_topdeck(event)
		_track_stat_gems(event)
		_track_life_gem(event)
		_track_boost_linger(event)
		_track_opp_force_ask(event)
		if et == E.EventType_ChangeCards:
			_change_hold_armed_at = _now_s()
			_change_hold_seen_cards = false
		# Advantage: a badge under the character who has it, until the next turn begins.
		if et == E.EventType_Strike_GainAdvantage:
			var adv_side := 0 if int(event["event_player"]) == int(Enums.PlayerId.PlayerId_Player) else 1
			_show_advantage(adv_side)
		elif et == E.EventType_AdvanceTurn:
			if strike_stage != null:
				strike_stage._dismiss_banner() # (never left up past a turn)
			_hide_advantage(0)
			_hide_advantage(1)
			_end_strike_dodge(0)
			_end_strike_dodge(1)
			_hide_stun(0)
			_hide_stun(1)
			_end_strike_status()
		# Dodge: a coolant-green badge for the rest of the strike.
		if et in [E.EventType_Strike_DodgeAttacks, E.EventType_Strike_DodgeAttacksAtRange, E.EventType_Strike_DodgeFromOppositeBuddy]:
			var dodge_side := 0 if int(event["event_player"]) == int(Enums.PlayerId.PlayerId_Player) else 1
			_strike_dodge[dodge_side] = true
			_show_dodge(dodge_side, _dodge_label(event))
		elif et == E.EventType_Strike_Stun:
			var stun_side := 0 if int(event["event_player"]) == int(Enums.PlayerId.PlayerId_Player) else 1
			_show_stun(stun_side)
		elif et == E.EventType_Strike_ExUp:
			# An effect made the attack EX (e.g. Badass!): the EX badge for the rest of the strike.
			show_ex_badge(int(event["event_player"]) == int(Enums.PlayerId.PlayerId_Player))
		elif et == E.EventType_Strike_StatusBadge or et == E.EventType_Strike_Stun_Immunity:
			# Stun immunity, ignore armor, ignore guard: a badge for the rest of the strike.
			var st_side := 0 if int(event["event_player"]) == int(Enums.PlayerId.PlayerId_Player) else 1
			var kind := "stun_immunity" if et == E.EventType_Strike_Stun_Immunity else str(event.get("reason", ""))
			if kind == "speed_dodge":
				# Dodging by a speed comparison: the dodge badge, ">SPD" / "<SPD" (or the speed
				# threshold) telling which attacks it dodges.
				_strike_dodge[st_side] = true
				_show_dodge(st_side, str(event.get("extra_info", "DODGE")))
			elif STATUS_BADGES.has(kind):
				_strike_status[st_side][kind] = true
				_show_status(st_side, kind)
		elif et == E.EventType_Strike_Cleanup:
			_end_strike_dodge(0)
			_end_strike_dodge(1)
			_hide_stun(0)
			_hide_stun(1)
			_end_strike_status()
		# Your own action gets its banner too, once you have confirmed it.
		if _logged_new_action == 0 and strike_stage != null:
			var mine := ""
			match et:
				E.EventType_Prepare: mine = "PREPARE"
				E.EventType_Move: mine = _move_banner(event)
				E.EventType_ChangeCards: mine = "CHANGE CARDS %d" % _change_count
				E.EventType_Exceed: mine = "EXCEED"
				E.EventType_ReshuffleDiscard: mine = "RESHUFFLE"
				E.EventType_Boost_Played: mine = "BOOST"
				E.EventType_CharacterAction: mine = UNIQUE_ACTION_BANNER
				E.EventType_Transform_Added: mine = "TRANSFORM"
				E.EventType_Boost_Canceled: mine = "CANCEL"
			if mine != "" and not event.get("phone_banner_done", false):
				event["phone_banner_done"] = true
				return _banner_delay(et, strike_stage.show_action_banner(mine, 0))
	if event.get("phone_banner_done", false):
		return 0.0 # the banner already played; this is the held-back event coming through
	if et == E.EventType_ReshuffleDeck_Mulligan:
		_mulligan_done[0 if int(event["event_player"]) == int(Enums.PlayerId.PlayerId_Player) else 1] = true
	if et == E.EventType_AdvanceTurn:
		_in_cleanup = false
		_ui_turn = int(event["event_player"]) # whose turn it is now, as the UI plays it back
		if _opp_action_text != "" and _opp_action_clear_at < 0.0:
			_opp_action_clear_at = _now_s()
		return 0.0
	if event["event_player"] != Enums.PlayerId.PlayerId_Opponent:
		return 0.0
	# (The game engine runs a CPU's whole turn at once, so its own "active player" is already
	# yours again while their events are still being shown: follow the turn events instead.)
	if _ui_turn < 0:
		_ui_turn = int(game.game_wrapper.get_active_player())
	if _ui_turn != int(Enums.PlayerId.PlayerId_Opponent):
		return 0.0 # e.g. their strike response during your turn: not an action of theirs
	if et == E.EventType_Boost_ActionAfterBoost:
		# Their boost gives them another action: that one gets a banner of its own too.
		_opp_action_text = ""
		_opp_action_clear_at = -1.0
		return 0.0
	if et == E.EventType_Boost_Canceled:
		# They cancel their boost (to take another action): a CANCEL banner, and whatever they
		# do next counts as a new action with a banner of its own.
		if strike_stage == null:
			return 0.0
		_opp_action_text = ""
		_opp_action_clear_at = -1.0
		event["phone_banner_done"] = true
		return strike_stage.show_action_banner("CANCEL", 1)
	var txt := ""
	match et:
		E.EventType_Prepare: txt = "PREPARE"
		E.EventType_Move: txt = _move_banner(event)
		E.EventType_ChangeCards: txt = "CHANGE CARDS"
		E.EventType_Exceed: txt = "EXCEED"
		E.EventType_ReshuffleDiscard: txt = "RESHUFFLE"
		E.EventType_Boost_Played: txt = "BOOST"
		E.EventType_CharacterAction: txt = UNIQUE_ACTION_BANNER
		E.EventType_Transform_Added: txt = "TRANSFORM"
		E.EventType_Strike_Started: txt = "STRIKE"
		E.EventType_Strike_Started_Ex: txt = "EX STRIKE"
		E.EventType_Strike_WildStrike: txt = "WILD SWING"
	if txt == "":
		return 0.0
	# Only the action itself: effects during it (a push, a draw, a boost inside a strike...)
	# don't get a banner of their own.
	if _opp_action_text != "" and _opp_action_clear_at < 0.0:
		return 0.0
	_opp_action_text = txt
	_opp_action_shown_at = _now_s()
	_opp_action_clear_at = -1.0
	if txt in ["STRIKE", "EX STRIKE", "WILD SWING"]:
		return 0.0 # a strike already has its STRIKE! banner when the cards are revealed
	if strike_stage == null:
		return 0.0
	event["phone_banner_done"] = true
	return _banner_delay(et, strike_stage.show_action_banner(txt, 1))

# "MOVE 2": a move action's banner, with how many spaces it went.
func _move_banner(event) -> String:
	var n := int(event.get("extra_info", 0)) if str(event.get("extra_info", "")).is_valid_int() else 0
	return ("MOVE %d" % n) if n > 0 else "MOVE"

# ---- "Most recent action" boxes under the player names ------------------------------------
var _last_action : Array = ["", ""]        # text shown per side (0 = you, 1 = opponent)
var _last_action_kind : Array = ["", ""]   # what that action was ("strike", "character", ...)
var _last_action_open : Array = [true, true] # the next event of theirs is a new action
var _last_strike_card : Array = [-1, -1]   # their strike card, named once it is revealed
var _last_action_boxes : Array = [null, null]
var _logged_new_action : int = -1 # the side that just took a new action (set by _log_last_action)

func _log_last_action(event) -> void:
	var E = Enums.EventType
	var et = event["event_type"]
	var pid : int = int(event["event_player"])
	if et == E.EventType_AdvanceTurn:
		_last_action_open[0 if pid == int(Enums.PlayerId.PlayerId_Player) else 1] = true
		release_last_action_hold() # (never held past the strike's turn)
		return
	if pid != int(Enums.PlayerId.PlayerId_Player) and pid != int(Enums.PlayerId.PlayerId_Opponent):
		return
	var side := 0 if pid == int(Enums.PlayerId.PlayerId_Player) else 1
	var nm := _ref_player_name(side == 0)
	var num : int = int(event.get("number", -1))
	var db = game.game_wrapper.get_card_database()
	# A strike's cards are revealed: name the attack that was set.
	if et == E.EventType_Strike_Reveal:
		for sd in range(2):
			if _last_action_kind[sd] == "strike" and _last_strike_card[sd] >= 0:
				var cname : String = str(db.get_card_name(_last_strike_card[sd]))
				if cname != "":
					var how := "Wild Swung into" if str(_last_action[sd]).ends_with("Wild Swung") else "Struck with"
					var extra := " (Character Action)" if str(_last_action[sd]).ends_with("(Character Action)") else ""
					_set_last_action(sd, "%s %s %s%s" % [_ref_player_name(sd == 0), how, cname, extra], "strike_named")
		return
	if et == E.EventType_Strike_WildStrike and _last_action_kind[side] in ["strike", "strike_named"]:
		var wname : String = str(db.get_card_name(num)) if num >= 0 else ""
		_set_last_action(side, ("%s Wild Swung into %s" % [nm, wname]) if wname != "" else "%s Wild Swung" % nm, "strike_named")
		return
	# Only a player's own turn actions count (not a strike response or an effect in a strike).
	var turn : int = _ui_turn if _ui_turn >= 0 else int(game.game_wrapper.get_active_player())
	if turn != pid:
		return
	if et == E.EventType_Boost_Canceled:
		_set_last_action(side, "%s Canceled a boost" % nm, "cancel")
		_last_action_open[side] = true
		_logged_new_action = side
		return
	if et == E.EventType_Boost_ActionAfterBoost:
		_last_action_open[side] = true # the boost gave them another action
		return
	var is_strike : bool = et in [E.EventType_Strike_Started, E.EventType_Strike_Started_Ex, E.EventType_Strike_WildStrike]
	if not _last_action_open[side] and not (is_strike and _last_action_kind[side] == "character"):
		return
	var txt := ""
	var kind := "action"
	match et:
		E.EventType_Prepare: txt = "%s Prepared" % nm
		E.EventType_Move:
			# "Advanced 2" / "Retreated 3": the direction (toward / away from the opponent)
			# and the distance.
			var mv := int(event.get("extra_info", 0)) if str(event.get("extra_info", "")).is_valid_int() else 0
			var from_sq := int(event.get("extra_info2", -1)) if str(event.get("extra_info2", "")).is_valid_int() else -1
			var to_sq : int = int(event.get("number", -1))
			var other_id = Enums.PlayerId.PlayerId_Opponent if side == 0 else Enums.PlayerId.PlayerId_Player
			var opp_sq : int = int(game.game_wrapper.get_player_location(other_id))
			var verb := "Moved"
			if from_sq >= 0 and to_sq >= 0 and to_sq != from_sq and opp_sq != from_sq:
				verb = "Advanced" if signi(to_sq - from_sq) == signi(opp_sq - from_sq) else "Retreated"
			txt = ("%s %s %d" % [nm, verb, mv]) if mv > 0 else "%s %s" % [nm, verb]
		E.EventType_ChangeCards:
			var cf := int(event.get("extra_info", -1)) if str(event.get("extra_info", "")).is_valid_int() else -1
			txt = ("%s Changed Cards %d" % [nm, cf]) if cf >= 0 else "%s Changed Cards" % nm
		E.EventType_Exceed: txt = "%s Exceeded" % nm
		E.EventType_ReshuffleDiscard: txt = "%s Reshuffled" % nm
		E.EventType_Boost_Played:
			var bname := ""
			var lc = db.get_card(num) if num >= 0 else null
			if lc != null:
				bname = str(lc.definition.get("boost", {}).get("display_name", ""))
			txt = ("%s Boosted %s" % [nm, bname]) if bname != "" else "%s Boosted" % nm
		E.EventType_Transform_Added:
			txt = "%s Transformed" % nm
		E.EventType_CharacterAction:
			txt = "%s used their Character Action" % nm
			kind = "character"
		E.EventType_Strike_WildStrike:
			txt = "%s Wild Swung" % nm
			kind = "strike"
			_last_strike_card[side] = num
		E.EventType_Strike_Started, E.EventType_Strike_Started_Ex:
			txt = "%s %s" % [nm, "EX Struck" if et == E.EventType_Strike_Started_Ex else "Struck"]
			if _last_action_kind[side] == "character":
				txt += " (Character Action)"
			kind = "strike"
			_last_strike_card[side] = num
	if txt == "":
		return
	if side == 1 and kind == "strike":
		_last_action_hold[1] = true
	_set_last_action(side, txt, kind)
	_last_action_open[side] = false
	_logged_new_action = side

# The opponent's strike: their box keeps showing their previous action until the strike cards
# are turned face up (StrikeStage._flip_cards), then names the attack.
var _last_action_hold : Array = [false, false]
var _last_action_shown : Array = ["", ""]

func release_last_action_hold() -> void:
	_last_action_hold = [false, false]

func _set_last_action(side : int, txt : String, kind : String) -> void:
	_last_action[side] = txt
	_last_action_kind[side] = kind

func _update_last_action_boxes() -> void:
	for side in range(2):
		var box : PanelContainer = _last_action_boxes[side]
		if box == null or not is_instance_valid(box):
			box = PanelContainer.new()
			box.mouse_filter = Control.MOUSE_FILTER_IGNORE
			box.z_index = 5 # under strike cards and focused cards
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0.04, 0.05, 0.1, 0.72)
			sb.border_color = Color(0.95, 0.8, 0.45, 0.85)
			sb.set_border_width_all(2)
			sb.set_corner_radius_all(10)
			sb.shadow_color = Color(0, 0, 0, 0.45)
			sb.shadow_size = 4
			sb.content_margin_left = 10.0
			sb.content_margin_right = 10.0
			sb.content_margin_top = 3.0
			sb.content_margin_bottom = 4.0
			box.add_theme_stylebox_override("panel", sb)
			var l := Label.new()
			l.name = "Text"
			l.mouse_filter = Control.MOUSE_FILTER_IGNORE
			l.add_theme_font_size_override("font_size", 18)
			l.add_theme_color_override("font_color", Color(1.0, 0.95, 0.82))
			l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
			l.add_theme_constant_override("outline_size", 4)
			l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
			l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT if side == 0 else HORIZONTAL_ALIGNMENT_RIGHT
			l.clip_text = true
			box.add_child(l)
			backdrop.add_child(box)
			_last_action_boxes[side] = box
			# A tap on the box opens the match log (growing out of the box). The tap area is its
			# own button over the whole box plus a margin round it (a button inside the panel
			# would only cover the text, not the panel's padding), so it's easy to hit.
			var tap := _invisible_button()
			tap.name = "LastActionTap%d" % side
			tap.z_index = 6
			var box_ref : WeakRef = weakref(box)
			tap.pressed.connect(func():
				var bx = box_ref.get_ref()
				if bx != null:
					_open_log_from(bx.get_global_rect()))
			backdrop.add_child(tap)
			_last_action_taps[side] = tap
		var tap_btn : Button = _last_action_taps[side]
		var lab : Label = box.get_node("Text")
		var txt : String = _last_action[side]
		if _last_action_hold[side]:
			txt = _last_action_shown[side] # (their strike isn't shown until its card is face up)
		else:
			_last_action_shown[side] = txt
		box.visible = txt != ""
		if tap_btn != null and is_instance_valid(tap_btn):
			tap_btn.visible = box.visible
		if not box.visible:
			continue
		# A fixed height; the width fits the text, growing up to the edge of the TURN switch.
		# Text too long for that shrinks (down to 14) and then trims.
		var max_w := _last_action_box_w()
		var f : Font = lab.get_theme_font("font")
		if lab.text != txt:
			lab.text = txt
			var fs := 20
			while fs > 14 and f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 22.0 > max_w:
				fs -= 1
			lab.add_theme_font_size_override("font_size", fs)
		var text_w : float = f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, lab.get_theme_font_size("font_size")).x
		var sz := Vector2(clampf(ceilf(text_w + 22.0), LAST_ACTION_H, max_w), LAST_ACTION_H)
		lab.custom_minimum_size = Vector2(sz.x - 20.0, 0.0)
		box.custom_minimum_size = sz
		box.size = sz
		# Just under the name: yours at the left edge, theirs at the right edge.
		var y := stage_y + 36.0
		box.position = Vector2(LAST_ACTION_EDGE, y) if side == 0 else Vector2(W - LAST_ACTION_EDGE - sz.x, y)
		if tap_btn != null and is_instance_valid(tap_btn):
			# Reaches the screen edge, a little above and below, and over to the TURN track (however
			# short the box is).
			var inner : float = max_w - sz.x + LAST_ACTION_TAP_INNER
			var tr := Rect2(box.position, sz)
			tr = tr.grow_individual(
					LAST_ACTION_EDGE if side == 0 else inner,
					LAST_ACTION_TAP_V,
					inner if side == 0 else LAST_ACTION_EDGE,
					LAST_ACTION_TAP_V)
			tap_btn.position = tr.position
			tap_btn.size = tr.size

const LAST_ACTION_H := 40.0 # (fixed height of the last-action boxes)
const LAST_ACTION_EDGE := 6.0      # (gap to the screen edge)
const LAST_ACTION_TAP_V := 8.0     # (extra tap height above and below)
const LAST_ACTION_TAP_INNER := 2.0 # (the tap area stops this far short of the TURN switch)
const LAST_ACTION_TRACK_GAP := 4.0 # (gap between the widest box and the TURN switch)
var _last_action_taps : Array = [null, null]

# The widest a last-action box gets: from its screen edge to just short of the TURN switch.
func _last_action_box_w() -> float:
	var track_half := TURN_BADGE_W + TURN_KNOB_GAP + TURN_TRACK_PAD
	return floorf(W / 2.0 - LAST_ACTION_EDGE - track_half - LAST_ACTION_TRACK_GAP)

func _update_opp_action() -> void:
	var g = game
	if _opp_action_label == null:
		_opp_action_label = Label.new()
		_opp_action_label.add_theme_font_override("font", load("res://scenes/game/badge_font.gd").make_font())
		_opp_action_label.add_theme_color_override("font_color", Color(1.0, 0.92, 0.55))
		_opp_action_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.95))
		_opp_action_label.add_theme_constant_override("outline_size", 10)
		_opp_action_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_opp_action_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		_opp_action_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_opp_action_label.z_index = 8 # under a focused card (z 10)
		backdrop.add_child(_opp_action_label)
	var now := _now_s()
	if _opp_action_text != "" and _opp_action_clear_at < 0.0 \
			and _ui_turn == int(Enums.PlayerId.PlayerId_Player) \
			and not g.game_wrapper.has_active_strike():
		_opp_action_clear_at = maxf(now, _opp_action_shown_at + 1.5)
	if _opp_action_clear_at >= 0.0 and now >= _opp_action_clear_at:
		_opp_action_text = ""
		_opp_action_clear_at = -1.0
	var slot := _bottom_slot_size()
	var left := _opp_icon_pos(0).x + slot.x + 6.0
	var right := _opp_hand_right_x() - 6.0
	var rect := Rect2(left, _opp_icon_pos(0).y, right - left, slot.y)
	_opp_action_label.position = rect.position
	_opp_action_label.size = rect.size
	if _opp_action_label.text != _opp_action_text:
		_opp_action_label.text = _opp_action_text
		var font : Font = _opp_action_label.get_theme_font("font")
		var fs := 54
		while fs > 20 and font.get_string_size(_opp_action_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > rect.size.x - 8.0:
			fs -= 2
		_opp_action_label.add_theme_font_size_override("font_size", fs)
	_opp_action_label.visible = false # (the action is announced with a banner now)

# Boost windows: as see-through as the ice bonus box. While a strike's metal plate is closed,
# an open reference window or card preview (drawn above it) also gets the taps.
const BOOST_ZONES : Array[String] = ["PlayerBoostZone", "OpponentBoostZone"]
const BOOST_ZONE_PAIRS := [["PlayerBoostZone", "AllCards/PlayerBoosts"], ["OpponentBoostZone", "AllCards/OpponentBoosts"]]

func _update_strike_overlays() -> void:
	for zn in BOOST_ZONES:
		var zone = game.get_node_or_null(zn)
		if zone == null:
			continue
		# The wood / fire backdrop (every copy of it; the text isn't faded).
		for fire in zone.get_children():
			if fire is Control and fire.get_script() != null and str(fire.get_script().resource_path).ends_with("boost_fire.gd"):
				if not is_equal_approx(fire.modulate.a, 0.55):
					fire.modulate.a = 0.55
	if strike_stage == null or strike_stage.plate == null or not is_instance_valid(strike_stage.plate):
		return
	var window_open : bool = game.card_popout_parent.get_child_count() > 0 \
			or (popout_preview_root != null and is_instance_valid(popout_preview_root))
	var want : int = Control.MOUSE_FILTER_IGNORE if window_open else Control.MOUSE_FILTER_STOP
	for half in [strike_stage._left, strike_stage._right]:
		if half != null and is_instance_valid(half) and half.mouse_filter != want:
			half.mouse_filter = want

# ---- Your known hand cards ----------------------------------------------------------------
# A hand card the opponent knows about gets a green eye on its face, just under the guard
# value (left column), so it is seen while the hand is fanned out.
const KNOWN_EYE_POS := Vector2(-125.0 + 0.12 * 250.0, -175.0 + 0.71 * 350.0) # card-local centre
const KNOWN_EYE_SIZE := 46.0
const KNOWN_EYE_CLEAR_ZONES : Array[String] = ["AllCards/PlayerDiscards", "AllCards/PlayerGauge", "AllCards/Striking", "AllCards/PlayerBoosts", "AllCards/PlayerDeck", "AllCards/PlayerSealed"]

func _update_hand_known_eyes() -> void:
	var g = game
	if g.observer_mode:
		return
	var zone = g.get_hand_zone(true)
	if zone == null:
		return
	var info = g.game_wrapper.get_player_public_hand_info(Enums.PlayerId.PlayerId_Player)
	var left : Dictionary = {}
	for k in info["known"]:
		left[k] = int(info["known"][k])
	var db = g.game_wrapper.get_card_database()
	for card in zone.get_children():
		if not (card is CardBase) or card.card_id < 0:
			continue
		var lc = db.get_card(card.card_id)
		var def_id : String = str(lc.definition.get("id", "")) if lc != null else ""
		var known : bool = int(left.get(def_id, 0)) > 0
		if known:
			left[def_id] = int(left[def_id]) - 1
		# (The game's own eye icons in the middle of the card are hidden by the next card in
		# the fan; this one replaces them.)
		if card.hand_icons_obj.visible:
			card.hand_icons_obj.visible = false
		var eye = card.card_features.get_node_or_null("PhoneKnownEye")
		if known and eye == null:
			if _reveal_eye_tex == null:
				_reveal_eye_tex = load("res://assets/icons/greeneye.png")
			eye = TextureRect.new()
			eye.name = "PhoneKnownEye"
			eye.texture = _reveal_eye_tex
			eye.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			eye.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
			eye.size = Vector2(KNOWN_EYE_SIZE, KNOWN_EYE_SIZE)
			eye.position = KNOWN_EYE_POS - eye.size / 2.0
			card.card_features.add_child(eye)
		if eye != null:
			eye.visible = known
	# Cards that left the hand take their eye down with them.
	for z in KNOWN_EYE_CLEAR_ZONES:
		var n = g.get_node_or_null(z)
		if n == null:
			continue
		for card in n.get_children():
			if card is CardBase:
				var e = card.card_features.get_node_or_null("PhoneKnownEye")
				if e != null and e.visible:
					e.visible = false

# ---- Marble finish (match-available box, hamburger menu, action menu) ------------------------
# Dark polished marble with pale gold veins and a gold rim, made once from noise. Buttons are a
# lighter grey marble; the white text with a dark outline reads on both.
static var _marble_cache : Dictionary = {}

func _marble_image(sz : int, base : Color, vein : Color, rim : Color, seed_n : int) -> Image:
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.03
	noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	noise.fractal_octaves = 4
	noise.seed = seed_n
	var cloud := FastNoiseLite.new()
	cloud.frequency = 0.05
	cloud.seed = seed_n + 7
	var img := Image.create(sz, sz, false, Image.FORMAT_RGBA8)
	var radius := 12.0
	var rim_w := 3.0
	for y in range(sz):
		for x in range(sz):
			var t : float = noise.get_noise_2d(float(x), float(y))
			var s : float = sin(float(x) * 0.06 + float(y) * 0.035 + t * 9.0)
			var v : float = pow(clampf(1.0 - absf(s) * 4.0, 0.0, 1.0), 2.0)
			var cl : float = cloud.get_noise_2d(float(x), float(y)) * 0.5 + 0.5
			var c : Color = base.lerp(base.lightened(0.18), cl * 0.6).lerp(vein, v * 0.6)
			# Rounded corners and the gold rim.
			var dx : float = maxf(maxf(radius - x, x - (sz - 1 - radius)), 0.0)
			var dy : float = maxf(maxf(radius - y, y - (sz - 1 - radius)), 0.0)
			var edge : float
			if dx > 0.0 and dy > 0.0:
				edge = radius - sqrt(dx * dx + dy * dy)
			else:
				edge = minf(minf(float(x), float(y)), minf(float(sz - 1 - x), float(sz - 1 - y)))
			if edge < 0.0:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
				continue
			if edge < rim_w:
				c = rim.lerp(rim.lightened(0.35), clampf(1.0 - absf(edge - rim_w * 0.5), 0.0, 1.0))
			c.a = clampf(edge + 0.5, 0.0, 1.0)
			img.set_pixel(x, y, c)
	return img

func _marble_style(kind : String) -> StyleBoxTexture:
	if _marble_cache.has(kind):
		return _marble_cache[kind]
	var gold := Color(0.86, 0.7, 0.36)
	var img : Image
	match kind:
		"panel":
			img = _marble_image(128, Color(0.07, 0.075, 0.085), Color(0.9, 0.84, 0.66), gold, 11)
		"button":
			img = _marble_image(96, Color(0.24, 0.25, 0.28), Color(0.95, 0.95, 0.97), gold, 23)
		"button_hover":
			img = _marble_image(96, Color(0.31, 0.32, 0.36), Color(1.0, 1.0, 1.0), gold.lightened(0.2), 23)
		"button_pressed":
			img = _marble_image(96, Color(0.13, 0.14, 0.16), Color(0.85, 0.85, 0.88), gold.darkened(0.15), 23)
		_:
			img = _marble_image(96, Color(0.18, 0.18, 0.2), Color(0.6, 0.6, 0.62), Color(0.5, 0.5, 0.5), 23)
	var sb := StyleBoxTexture.new()
	sb.texture = ImageTexture.create_from_image(img)
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		sb.set_texture_margin(side, 16.0)
	sb.content_margin_left = 14.0
	sb.content_margin_right = 14.0
	sb.content_margin_top = 10.0
	sb.content_margin_bottom = 10.0
	_marble_cache[kind] = sb
	return sb

func _marble_button(b : Button) -> void:
	if b == null or b.has_meta("marbled") or b is CheckBox:
		return
	b.set_meta("marbled", true)
	b.add_theme_stylebox_override("normal", _marble_style("button"))
	b.add_theme_stylebox_override("hover", _marble_style("button_hover"))
	b.add_theme_stylebox_override("pressed", _marble_style("button_pressed"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("disabled", _marble_style("disabled"))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color(1, 0.98, 0.92))
	b.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	b.add_theme_constant_override("outline_size", 6)

func _marble_message_label(ml : Control) -> void:
	ml.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	ml.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	ml.add_theme_constant_override("outline_size", 6)

func _update_marble() -> void:
	# Hamburger menu.
	if menu_panel != null and not menu_panel.has_meta("marbled"):
		menu_panel.set_meta("marbled", true)
		menu_panel.add_theme_stylebox_override("panel", _marble_style("panel"))
		for b in menu_panel.find_children("*", "Button", true, false):
			_marble_button(b)
	# Action menu (choices appear and change as it is used).
	var am = game.action_menu
	if am != null:
		if not am.has_meta("marbled"):
			am.set_meta("marbled", true)
			am.add_theme_stylebox_override("panel", _marble_style("panel"))
		if am.visible:
			var cb = am.get_node_or_null("OuterMargin/MainVBox/ChoiceButtons")
			if cb != null:
				for b in cb.find_children("*", "Button", true, false):
					_marble_button(b)
	# The modal dialog ("Are you sure you want to quit?" and the like): marble too.
	var md = game.get_node_or_null("ModalDialog")
	if md != null and not md.has_meta("marbled"):
		var mp = md.get_node_or_null("PanelContainer")
		if mp != null:
			md.set_meta("marbled", true)
			mp.add_theme_stylebox_override("panel", _marble_style("panel"))
			for b in mp.find_children("*", "Button", true, false):
				_marble_button(b)
			var ml = mp.get_node_or_null("OuterMargin/VerticalLayout/MessageLabel")
			if ml != null:
				_marble_message_label(ml)
	# "A match is available!": marble, and above everything else on screen.
	var sd = game.slideout_dialog
	if sd != null:
		if not sd.has_meta("marbled"):
			sd.set_meta("marbled", true)
			sd.add_theme_stylebox_override("panel", _marble_style("panel"))
			for b in sd.find_children("*", "Button", true, false):
				_marble_button(b)
			var ml = sd.get_node_or_null("MarginContainer/VBoxContainer/MessageLabel")
			if ml != null:
				_marble_message_label(ml)
			sd.z_as_relative = false
			sd.z_index = 200
		if sd.visible and sd.get_parent() != null and sd.get_index() != sd.get_parent().get_child_count() - 1:
			sd.get_parent().move_child(sd, -1) # last in the tree, so it also wins every tap

# ---- Whose turn it is: a glowing border around that player's half of the stage ----------------
var _turn_frames : Array = [null, null]
var _menu_layer : CanvasLayer = null

var _adv_badges : Array = [null, null]
# Status badges (ADVANTAGE, and any added later) sit in each player's half of the stage, under
# the name and the last-action box: left to right, top to bottom, two to a row.
var _badges : Array = [[], []]
const BADGE_SIZE := Vector2(168, 40)

func _show_advantage(side : int) -> void:
	_hide_advantage(1 - side) # only one player can have it
	var b = _adv_badges[side]
	if b == null or not is_instance_valid(b):
		b = load("res://scenes/game/advantage_badge.gd").new()
		b.z_index = 9 # under a focused card (z 10)
		backdrop.add_child(b)
		b.size = _badge_size()
		_adv_badges[side] = b
	elif b.visible and b.modulate.a > 0.9 and b in _badges[side]:
		return # already showing
	if not b in _badges[side]:
		_badges[side].append(b)
	b.set_meta("slot", _badge_pos(side, _badges[side].find(b)))
	b.pop_in(_badge_pos(side, _badges[side].find(b)))

func _hide_advantage(side : int) -> void:
	var b = _adv_badges[side]
	if b != null and is_instance_valid(b) and b.visible:
		b.fade_out()
	_badges[side].erase(b)
	_place_advantage_badges()

var _dodge_badges : Array = [null, null]

# "DODGE" when it dodges at every range, "DODGE 4+" when open-ended, else "DODGE 2" / "DODGE 2-3".
func _dodge_label(event) -> String:
	if int(event["event_type"]) != int(Enums.EventType.EventType_Strike_DodgeAttacksAtRange):
		return "DODGE"
	var lo := int(event["number"])
	var hi := int(event["extra_info"]) if str(event.get("extra_info", "")).is_valid_int() else lo
	return _dodge_range_label(lo, hi)

func _dodge_range_label(lo : int, hi : int) -> String:
	if lo <= 1 and hi >= 8:
		return "DODGE"
	if hi >= 8:
		return "DODGE %d+" % lo
	if hi == lo:
		return "DODGE %d" % lo
	return "DODGE %d-%d" % [lo, hi]

func _show_dodge(side : int, label : String) -> void:
	var b = _dodge_badges[side]
	if b == null or not is_instance_valid(b):
		b = load("res://scenes/game/dodge_badge.gd").new()
		b.z_index = 9
		backdrop.add_child(b)
		b.size = _badge_size()
		_dodge_badges[side] = b
	b.set_text(label)
	if b.visible and b.modulate.a > 0.9 and b in _badges[side]:
		return # already showing; just the new text
	if not b in _badges[side]:
		_badges[side].append(b)
	b.set_meta("slot", _badge_pos(side, _badges[side].find(b)))
	b.pop_in(_badge_pos(side, _badges[side].find(b)))

func _hide_dodge(side : int) -> void:
	var b = _dodge_badges[side]
	if b != null and is_instance_valid(b) and b.visible:
		b.fade_out()
	_badges[side].erase(b)
	_place_advantage_badges()

var _stun_badges : Array = [null, null]

func _show_stun(side : int) -> void:
	var b = _stun_badges[side]
	if b == null or not is_instance_valid(b):
		b = load("res://scenes/game/stun_badge.gd").new()
		b.z_index = 9
		backdrop.add_child(b)
		b.size = _badge_size()
		_stun_badges[side] = b
	elif b.visible and b.modulate.a > 0.9 and b in _badges[side]:
		return
	if not b in _badges[side]:
		_badges[side].append(b)
	b.set_meta("slot", _badge_pos(side, _badges[side].find(b)))
	b.pop_in(_badge_pos(side, _badges[side].find(b)))

func _hide_stun(side : int) -> void:
	var b = _stun_badges[side]
	if b != null and is_instance_valid(b) and b.visible:
		b.fade_out()
	_badges[side].erase(b)
	_place_advantage_badges()

# ---- Boosts that give several actions (Out of the Box: "Take 3 bonus actions") ------------------
# While such a boost is in play, the island offers its action on the player's turn ("Take 3
# actions", on a blazing boost background). Its text in the boost window is replaced with
# "Actions left:" and one circle per action, dimmed until the action is confirmed; each circle
# fills as an action is taken, until the turn ends.
const ACTION_CIRCLE_EMPTY := "res://assets/ui/action_circle_empty.png"
const ACTION_CIRCLE_FILLED := "res://assets/ui/action_circle_filled.png"
var _actions_state : Array = [{}, {}] # per side: {"total", "used", "confirmed"}
var _multi_box : Control = null       # the boost's action, left half of the action box
var _multi_label : Label
var _multi_split : bool = false
var _ability_box_full := Rect2()
var _ability_btn_full := Rect2()

# The number of bonus actions an effect (or its "and" chain) gives, 0 if none.
func _bonus_action_amount(effect) -> int:
	var e = effect
	while e is Dictionary:
		if str(e.get("effect_type", "")) == "take_bonus_actions":
			return int(e.get("amount", 0))
		e = e.get("and")
	return 0

# For a boost card: how many actions its boost action gives (0 when it isn't such a boost).
func multi_action_amount(card_def : Dictionary) -> int:
	for e in card_def.get("boost", {}).get("effects", []):
		if e is Dictionary and str(e.get("timing", "")) == "action":
			var n := _bonus_action_amount(e)
			if n > 1:
				return n
	return 0

# The boost window line: "Actions left:" and a circle per action (filled once taken).
func actions_left_line(side : int, total : int) -> String:
	var st : Dictionary = _actions_state[side]
	var confirmed : bool = st.get("confirmed", false)
	var n : int = int(st.get("total", total)) if confirmed else total
	var used : int = int(st.get("used", 0)) if confirmed else 0
	var tint := "" if confirmed else " color=#ffffff66"
	var icons := ""
	for i in range(n):
		icons += " [img width=26 height=26%s]%s[/img]" % [tint, ACTION_CIRCLE_FILLED if i < used else ACTION_CIRCLE_EMPTY]
	if confirmed:
		return "[b]Actions left:[/b]%s" % icons
	return "[color=#ffffff66][b]Actions left:[/b][/color]%s" % icons

# The same line while the actions are being taken (the boost itself has been discarded).
func active_actions_line(side : int) -> String:
	var st : Dictionary = _actions_state[side]
	if not st.get("confirmed", false):
		return ""
	return actions_left_line(side, int(st["total"]))

func _refresh_boost_summary(side : int) -> void:
	var pid := Enums.PlayerId.PlayerId_Player if side == 0 else Enums.PlayerId.PlayerId_Opponent
	var holder = game.get_node_or_null("AllCards/PlayerBoosts" if side == 0 else "AllCards/OpponentBoosts")
	var zone = game.get_node_or_null("PlayerBoostZone" if side == 0 else "OpponentBoostZone")
	if holder != null and zone != null:
		game.update_boost_summary.call_deferred(pid, holder, zone)

# How many actions the boost action in the player's boost area gives (0 if there is none).
func _player_multi_action_amount() -> int:
	var holder = game.get_node_or_null("AllCards/PlayerBoosts")
	if holder == null:
		return 0
	var db = game.game_wrapper.get_card_database()
	for card in holder.get_children():
		if not (card is CardBase) or card.card_id < 0:
			continue
		var lc = db.get_card(card.card_id)
		if lc != null:
			var n := multi_action_amount(lc.definition)
			if n > 0:
				return n
	return 0

# While such a boost is in the player's boost area the action box is split: the boost's action
# ("Take 3 actions", on a blazing boost background) on the left, the usual action box on the right.
func _update_multi_action_box() -> void:
	if _ability_box_full.size.x <= 1.0:
		return
	var n := _player_multi_action_amount()
	_apply_action_split(n > 0)
	if _multi_box == null or not _multi_split:
		return
	_multi_label.text = "Take %d actions" % n
	_multi_box.visible = ability_label.visible
	# Bright while the action can be taken now, dimmed otherwise.
	var can := not _multi_action_offer().is_empty()
	_multi_box.modulate = Color.WHITE if can else Color(0.55, 0.55, 0.55, 1.0)

func _apply_action_split(split : bool, force : bool = false) -> void:
	if split == _multi_split and not force:
		return
	_multi_split = split
	var full := _ability_box_full
	var btn := _ability_btn_full
	if split:
		if _multi_box == null:
			_build_multi_box()
		var lw := floorf(btn.size.x * 0.5) - 3.0
		_multi_box.position = btn.position + Vector2(0, 4)
		_multi_box.size = Vector2(lw, btn.size.y - 8.0)
		_ability_box = Rect2(full.position.x + lw + 6.0, full.position.y, full.size.x - lw - 6.0, full.size.y)
		_set_rect(panels["ability_btn"], Rect2(btn.position.x + lw + 6.0, btn.position.y, btn.size.x - lw - 6.0, btn.size.y))
	else:
		_ability_box = full
		_set_rect(panels["ability_btn"], btn)
		if _multi_box != null:
			_multi_box.visible = false
	var fs := 16 if split else 19
	for k in ["normal_font_size", "italics_font_size", "bold_font_size"]:
		ability_label.add_theme_font_size_override(k, fs)
	_set_rect(ability_label, _ability_box)

func _build_multi_box() -> void:
	_multi_box = Control.new()
	_multi_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_multi_box.z_index = ability_label.z_index
	backdrop.add_child(_multi_box)
	var fire = load("res://scenes/game/boost_fire.gd").new()
	fire.set_anchors_preset(Control.PRESET_FULL_RECT)
	_multi_box.add_child(fire)
	fire.set_level(3)
	_multi_label = Label.new()
	_multi_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_multi_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_multi_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_multi_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_multi_label.add_theme_font_size_override("font_size", 22)
	_multi_label.add_theme_color_override("font_outline_color", Color(0.15, 0.04, 0.0))
	_multi_label.add_theme_constant_override("outline_size", 6)
	_multi_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_multi_box.add_child(_multi_label)
	var btn := _flat_button(_multi_box, _on_multi_action_pressed)
	btn.set_anchors_preset(Control.PRESET_FULL_RECT)

func _on_multi_action_pressed() -> void:
	var offer := _multi_action_offer()
	if offer.is_empty():
		return
	# Taken: the boost window's "Actions left" lights up straight away.
	_actions_state[0] = {"total": int(offer["multi_actions"]), "used": 0, "confirmed": true}
	_refresh_boost_summary(0)
	game.action_menu._on_choice_pressed(int(offer["ok"]))

# The boost's action, when the player can take it right now.
func _multi_action_offer() -> Dictionary:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_PickTurnAction:
		return {}
	if g.game_wrapper.get_active_player() != Enums.PlayerId.PlayerId_Player:
		return {}
	for a in g.game_wrapper.get_bonus_actions(Enums.PlayerId.PlayerId_Player):
		var n := _bonus_action_amount(a)
		if n <= 1:
			continue
		var txt := str(a.get("text", "Special Action"))
		var choices : Array = g.current_action_menu_choices
		for i in range(choices.size()):
			if str(choices[i].get("text", "")) == txt and not choices[i].get("disabled", false):
				return {"ok": i, "cancel": -1, "ok_disabled": false, "multi_actions": n}
	return {}

# Follows the actions as they are taken (from the game's events).
func _track_multi_actions(event) -> void:
	var E = Enums.EventType
	var et = event["event_type"]
	var pid : int = int(event["event_player"])
	if et == E.EventType_AdvanceTurn:
		for side in range(2):
			if not _actions_state[side].is_empty():
				_actions_state[side] = {}
				_refresh_boost_summary(side)
		return
	if pid != int(Enums.PlayerId.PlayerId_Player) and pid != int(Enums.PlayerId.PlayerId_Opponent):
		return
	var side := 0 if pid == int(Enums.PlayerId.PlayerId_Player) else 1
	var st : Dictionary = _actions_state[side]
	if et == E.EventType_Boost_ActionAfterBoost:
		# The boost's action has been taken: its actions start (the opponent's too).
		var left : int = int(event.get("number", 0))
		if not st.get("counting", false) and (st.get("confirmed", false) or left >= 2):
			_actions_state[side] = {"total": maxi(int(st.get("total", 0)), left + 1), "used": 0,
					"confirmed": true, "counting": true}
			_refresh_boost_summary(side)
		return
	if st.get("counting", false) and _logged_new_action == side:
		st["used"] = mini(int(st["used"]) + 1, int(st["total"]))
		_refresh_boost_summary(side)
		if int(st["used"]) >= int(st["total"]):
			# All the actions are taken (e.g. the last one is a strike, so the turn goes on):
			# show the last circle fill, then take the line away - the boost is fulfilled.
			st["counting"] = false
			get_tree().create_timer(_pt(1.2)).timeout.connect(func():
				if _actions_state[side] == st:
					_actions_state[side] = {}
					_refresh_boost_summary(side))

# Strike statuses with their own badge, by the event's reason.
const STATUS_BADGES := {
	"stun_immunity": "res://scenes/game/stun_immune_badge.gd",
	"ignore_armor": "res://scenes/game/ignore_armor_badge.gd",
	"ignore_guard": "res://scenes/game/ignore_guard_badge.gd",
	"ex": "res://scenes/game/ex_badge.gd",
	"wild_swing": "res://scenes/game/wild_swing_badge.gd",
}
var _status_badges : Array = [{}, {}] # per side: kind -> badge

# An EX strike was set: an EX badge for that side for the rest of the strike.
func show_ex_badge(is_player : bool) -> void:
	var side := 0 if is_player else 1
	_strike_status[side]["ex"] = true
	_show_status(side, "ex")
	_update_gem_values()

func _show_status(side : int, kind : String) -> void:
	var b = _status_badges[side].get(kind)
	if b == null or not is_instance_valid(b):
		b = load(STATUS_BADGES[kind]).new()
		b.z_index = 9
		backdrop.add_child(b)
		b.size = _badge_size()
		_status_badges[side][kind] = b
	elif b.visible and b.modulate.a > 0.9 and b in _badges[side]:
		return
	if not b in _badges[side]:
		_badges[side].append(b)
	b.set_meta("slot", _badge_pos(side, _badges[side].find(b)))
	b.pop_in(_badge_pos(side, _badges[side].find(b)))

func _hide_status(side : int, kind : String) -> void:
	var b = _status_badges[side].get(kind)
	if b != null and is_instance_valid(b) and b.visible:
		b.fade_out()
	_badges[side].erase(b)
	_place_advantage_badges()

# A status badge stays up while a strike effect or a boost in play gives it.
var _strike_status : Array = [{}, {}]   # kinds gained during the current strike
var _boost_status : Array = [{}, {}]    # kinds (and "dodge" -> label) given by boosts in play
var _strike_dodge : Array = [false, false]

# The strike is over: its statuses go, unless a boost in play still gives them.
func _end_strike_status() -> void:
	for side in range(2):
		for kind in _strike_status[side]:
			if not _boost_status[side].has(kind):
				_hide_status(side, kind)
		_strike_status[side] = {}
	_update_gem_values()

func _end_strike_dodge(side : int) -> void:
	_strike_dodge[side] = false
	if _boost_status[side].has("dodge"):
		_show_dodge(side, str(_boost_status[side]["dodge"]))
	else:
		_hide_dodge(side)

# Called with the badge statuses the boosts in a player's boost area give (see
# extract_badge_effects), whenever their boost window is updated.
func set_boost_statuses(side : int, found : Dictionary) -> void:
	var old : Dictionary = _boost_status[side]
	if old == found:
		return
	_boost_status[side] = found.duplicate()
	for kind in STATUS_BADGES:
		if found.has(kind) and not old.has(kind):
			_show_status(side, kind)
		elif old.has(kind) and not found.has(kind) and not _strike_status[side].has(kind):
			_hide_status(side, kind)
	if found.has("dodge"):
		if not _strike_dodge[side]:
			_show_dodge(side, str(found["dodge"]))
	elif old.has("dodge") and not _strike_dodge[side]:
		_hide_dodge(side)
	_update_gem_values()

# Where the i-th badge of a side goes: two to a row, between the screen edge and that side's
# column of stat gems (by the center line).
func _badge_pos(side : int, i : int) -> Vector2:
	var gap := BADGE_GAP
	var bs := _badge_size()
	# (yours from the left screen edge; theirs from just past their gem column)
	var x0 : float = gap if side == 0 else W / 2.0 + GEM_CENTER_INSET + _stat_gem_w() + gap
	var y0 := stage_y + 36.0 + 40.0 # under the name and the last-action box
	var col := i % 2
	var row := i / 2
	return Vector2(x0 + col * (bs.x + gap), y0 + row * (bs.y + gap))

const BADGE_GAP := 6.0

# The badges' size: as big as BADGE_SIZE allows while two of them (and their gaps) fit beside
# the stat gem column, keeping their proportions.
func _badge_size() -> Vector2:
	var room := W / 2.0 - GEM_CENTER_INSET - _stat_gem_w() - BADGE_GAP * 3.0
	var bw := minf(BADGE_SIZE.x, floorf(room / 2.0))
	return Vector2(bw, roundf(BADGE_SIZE.y * bw / BADGE_SIZE.x))

# A stat gem's width (see _place_stat_gems: a fifth of a half-screen row, less the gaps).
func _stat_gem_w() -> float:
	var row_w := W / 2.0 - 8.0
	return (row_w - 4.0 * (GEM_STATS.size() - 1)) / GEM_STATS.size()

func _place_advantage_badges() -> void:
	for side in range(2):
		var keep : Array = []
		for b in _badges[side]:
			if b != null and is_instance_valid(b):
				keep.append(b)
		_badges[side] = keep
		for i in range(keep.size()):
			var b = keep[i]
			var target := _badge_pos(side, i)
			if b.visible and b.scale.x >= 0.999 and b.get_meta("slot", target) != target:
				b.set_meta("slot", target)
				b.create_tween().tween_property(b, "position", _badge_pos(side, i), 0.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

# A boost like Scramble (its player's strikes make the opponent wild swing): the WILD SWING
# badge on the opponent while it's the boost's player's turn.
var _wild_shown : Array = [false, false]
func _update_wild_badges(turn : int) -> void:
	for side in range(2):
		var other_pid := int(Enums.PlayerId.PlayerId_Opponent if side == 0 else Enums.PlayerId.PlayerId_Player)
		var want : bool = _boost_status[1 - side].has("forces_wild") and turn == other_pid \
				and game.ui_state != game.UIState.UIState_GameOver
		if want and not _wild_shown[side]:
			_show_status(side, "wild_swing")
		elif _wild_shown[side] and not want:
			_hide_status(side, "wild_swing")
		_wild_shown[side] = want

func _update_turn_highlight() -> void:
	_place_advantage_badges()
	var turn : int = _ui_turn if _ui_turn >= 0 else int(game.game_wrapper.get_active_player())
	_update_wild_badges(turn)
	for side in range(2):
		var f : Panel = _turn_frames[side]
		if f == null or not is_instance_valid(f):
			f = Panel.new()
			f.mouse_filter = Control.MOUSE_FILTER_IGNORE
			f.z_index = 3
			var sb := StyleBoxFlat.new()
			sb.bg_color = Color(0, 0, 0, 0)
			sb.border_color = Color(1.0, 0.86, 0.35)
			sb.set_border_width_all(4)
			sb.set_corner_radius_all(6)
			f.add_theme_stylebox_override("panel", sb)
			# A softer second line just inside it, for a gentle glow (a StyleBoxFlat shadow
			# would tint the whole area under the frame).
			var glow := Panel.new()
			glow.name = "Glow"
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			var gsb := StyleBoxFlat.new()
			gsb.bg_color = Color(0, 0, 0, 0)
			gsb.border_color = Color(1.0, 0.86, 0.35, 0.35)
			gsb.set_border_width_all(5)
			gsb.set_corner_radius_all(4)
			glow.add_theme_stylebox_override("panel", gsb)
			f.add_child(glow)
			backdrop.add_child(f)
			_turn_frames[side] = f
		var stage : Control = panels["stage_l" if side == 0 else "stage_r"]
		f.position = stage.position + Vector2(3, 3)
		# (it runs down around that side's gauge strip too, to the top of the arena)
		f.size = Vector2(stage.size.x - 6.0, gauge_y + gauge_h - f.position.y)
		var pid := int(Enums.PlayerId.PlayerId_Player if side == 0 else Enums.PlayerId.PlayerId_Opponent)
		f.visible = turn == pid and game.ui_state != game.UIState.UIState_GameOver
		var glow_p : Panel = f.get_node("Glow")
		glow_p.position = Vector2(4, 4)
		glow_p.size = f.size - Vector2(8, 8)
		if f.visible:
			# A gentle glow.
			glow_p.modulate.a = 0.6 + 0.4 * sin(Time.get_ticks_msec() / 400.0)
	# The hamburger button and its menu sit on their own layer above the game, so nothing on
	# the board (strike plates, cards...) can take their taps.
	if _menu_layer == null and menu_button != null:
		_menu_layer = CanvasLayer.new()
		_menu_layer.layer = 2
		game.add_child(_menu_layer)
		menu_button.reparent(_menu_layer, false)
		menu_panel.reparent(_menu_layer, false)
	if _menu_layer != null:
		# Hidden while the versus splash (loading screen) is still up.
		var main_node = game.get_parent()
		var splash_up : bool = main_node != null and "splash" in main_node and main_node.splash != null \
				and is_instance_valid(main_node.splash)
		_menu_layer.visible = not splash_up

# ---- Emote window and combat log -------------------------------------------------------------
# The emote window gets the marble look; the combat log looks like an old MS-DOS screen (chunky
# green text on black, silver frame, faint scanlines). Both show above everything else.
var _dos_styled : bool = false
var _emote_styled : bool = false
const DOS_GREEN := Color(0.24, 1.0, 0.3)

func _update_dialogs() -> void:
	var g = game
	var cl = g.get_node_or_null("CombatLog")
	if cl != null:
		if not _dos_styled:
			_dos_styled = true
			_style_dos_log(cl)
		if cl.visible:
			_bring_to_front(cl)
		if cl.visible and not _log_was_open:
			_animate_log_open(cl)
		_log_was_open = cl.visible
	var ed = g.get_node_or_null("EmoteDialog")
	if ed != null:
		if not _emote_styled:
			_emote_styled = true
			_style_emotes(ed)
		if ed.visible:
			_bring_to_front(ed)

var _log_was_open : bool = false
var _log_from : Rect2 = Rect2() # (where the log grows from: the last-action box tapped)

func _open_log_from(r : Rect2) -> void:
	_log_from = r
	game._on_combat_log_button_pressed()

# The match log opens smoothly: grows out of the tapped last-action box (else the screen center)
# while fading in.
func _animate_log_open(cl : Control) -> void:
	var from := _log_from
	_log_from = Rect2()
	var origin : Vector2 = from.get_center() if from.size != Vector2.ZERO else Vector2(W / 2.0, H / 2.0)
	cl.pivot_offset = origin - cl.global_position
	cl.scale = Vector2(0.15, 0.15)
	cl.modulate.a = 0.0
	var t : Tween = cl.create_tween().set_parallel(true)
	t.tween_property(cl, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	t.tween_property(cl, "modulate:a", 1.0, 0.18)

func _bring_to_front(c : Control) -> void:
	c.z_as_relative = false
	c.z_index = 210
	var par := c.get_parent()
	if c.get_index() != par.get_child_count() - 1:
		par.move_child(c, -1)

func _dos_font() -> Font:
	var f := SystemFont.new()
	f.font_names = PackedStringArray(["Menlo", "Consolas", "Courier New", "DejaVu Sans Mono", "Droid Sans Mono", "Roboto Mono", "monospace"])
	f.font_weight = 800
	return f

func _dos_button(b : Button, font : Font) -> void:
	for st in BUTTON_STATES:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0, 0.12, 0.02) if st == "pressed" else Color(0, 0, 0)
		sb.border_color = DOS_GREEN
		sb.set_border_width_all(2)
		sb.content_margin_left = 12.0
		sb.content_margin_right = 12.0
		sb.content_margin_top = 6.0
		sb.content_margin_bottom = 6.0
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 22)
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(c, DOS_GREEN)

func _style_dos_log(cl : Control) -> void:
	var font := _dos_font()
	cl.get_node("CloseOuterClick").custom_minimum_size = Vector2(W, H)
	var panel : PanelContainer = cl.get_node("PanelContainer")
	var frame := StyleBoxFlat.new()
	frame.bg_color = Color(0, 0, 0)
	frame.border_color = Color(0.8, 0.82, 0.86) # silver
	frame.set_border_width_all(8)
	frame.set_corner_radius_all(3)
	frame.shadow_color = Color(0, 0, 0, 0.6)
	frame.shadow_size = 10
	panel.add_theme_stylebox_override("panel", frame)
	var vl : VBoxContainer = cl.get_node("PanelContainer/OuterMargin/VerticalLayout")
	vl.add_theme_constant_override("separation", 8)
	# A DOS prompt as the title.
	var title := Label.new()
	title.text = "C:\\EXCEED> TYPE COMBAT.LOG"
	title.add_theme_font_override("font", font)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", DOS_GREEN)
	vl.add_child(title)
	vl.move_child(title, 0)
	var close : Button = vl.get_node("CloseButton")
	close.text = "[ CLOSE ]"
	_dos_button(close, font)
	var copy : Button = vl.get_node("LogButtons/CopyButton")
	copy.text = "[ COPY TO CLIPBOARD ]"
	_dos_button(copy, font)
	var lt : RichTextLabel = vl.get_node("LogText")
	lt.custom_minimum_size = Vector2(W - 64.0, H * 0.58)
	for k in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		lt.add_theme_font_override(k, font)
	for k in ["normal_font_size", "bold_font_size", "italics_font_size", "bold_italics_font_size", "mono_font_size"]:
		lt.add_theme_font_size_override(k, 20)
	lt.add_theme_color_override("default_color", DOS_GREEN)
	# A soft phosphor glow around the letters.
	lt.add_theme_color_override("font_shadow_color", Color(0.2, 1.0, 0.25, 0.35))
	lt.add_theme_constant_override("shadow_outline_size", 4)
	lt.add_theme_constant_override("shadow_offset_x", 0)
	lt.add_theme_constant_override("shadow_offset_y", 0)
	lt.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	lt.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	# Scanlines over the text.
	var scan := ColorRect.new()
	scan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scan.set_anchors_preset(Control.PRESET_FULL_RECT)
	var mat := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tfloat on = step(2.0, mod(FRAGCOORD.y, 4.0));\n\tCOLOR = vec4(0.0, 0.0, 0.0, on * 0.18);\n}"
	mat.shader = sh
	scan.material = mat
	lt.add_child(scan)
	# Filters: two columns of green check boxes; the colour pickers go (the log is all green).
	var filters : HBoxContainer = vl.get_node("LogFilters")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 14)
	vl.add_child(grid)
	vl.move_child(grid, filters.get_index())
	for c in filters.get_children():
		if c is CheckBox:
			c.reparent(grid)
			c.add_theme_font_override("font", font)
			c.add_theme_font_size_override("font_size", 18)
			for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
				c.add_theme_color_override(k, DOS_GREEN)
			c.add_theme_color_override("icon_normal_color", DOS_GREEN)
			c.add_theme_color_override("icon_pressed_color", DOS_GREEN)
			c.add_theme_color_override("icon_hover_color", DOS_GREEN)
			c.add_theme_color_override("icon_hover_pressed_color", DOS_GREEN)
	filters.visible = false
	# All-green text: you in bright green, the opponent in a deeper green, cards pale.
	cl.log_player_color = "#d8ffd8"
	cl.log_opponent_color = "#5cff6a"
	cl.log_card_color = "#a8ff80"
	cl.text_filter = _dos_log_text

var _dos_color_re : RegEx
var _dos_name_re : RegEx
# The log, tidied for the DOS screen: any other colours turn green, and "Player" becomes your
# name.
func _dos_log_text(t : String) -> String:
	if _dos_color_re == null:
		_dos_color_re = RegEx.new()
		_dos_color_re.compile("\\[color=(?!#d8ffd8|#5cff6a|#a8ff80)[^\\]]*\\]")
		_dos_name_re = RegEx.new()
		_dos_name_re.compile("(\\[color=#d8ffd8\\]\\**)Player(\\[/color\\])")
	t = _dos_color_re.sub(t, "[color=#9dff9d]", true)
	var my_name := _ref_player_name(true)
	if my_name != "" and my_name != "Player":
		t = _dos_name_re.sub(t, "$1" + my_name.replace("$", "") + "$2", true)
		t = t.replace("Game Start - Player as", "Game Start - %s as" % my_name)
	# Each turn starts a new block, with a blank line before it.
	t = t.replace(" 's Turn Start!", "'s Turn Start!")
	var out : Array[String] = []
	for ln in t.split("\n"):
		if ln.contains("Turn Start!") and not out.is_empty():
			out.append("")
		out.append(ln)
	return "\n".join(out)

func _style_emotes(ed : Control) -> void:
	ed.get_node("CloseOuterClick").custom_minimum_size = Vector2(W, H)
	var panel : PanelContainer = ed.get_node("PanelContainer")
	panel.add_theme_stylebox_override("panel", _marble_style("panel"))
	var vl : VBoxContainer = ed.get_node("PanelContainer/OuterMargin/VerticalLayout")
	vl.add_theme_constant_override("separation", 18)
	var title := Label.new()
	title.text = "EMOTES"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	vl.add_child(title)
	vl.move_child(title, 0)
	var imgs : GridContainer = vl.get_node("ImageButtons")
	imgs.columns = 4
	# A gold frame around each emote picture.
	for icon in imgs.get_children():
		if icon is PanelContainer:
			var gsb := StyleBoxFlat.new()
			gsb.bg_color = Color(0.08, 0.07, 0.05, 0.6)
			gsb.border_color = Color(0.86, 0.7, 0.36)
			gsb.set_border_width_all(3)
			gsb.set_corner_radius_all(6)
			gsb.set_content_margin_all(4)
			icon.add_theme_stylebox_override("panel", gsb)
	var txts : GridContainer = vl.get_node("TextButtons")
	txts.columns = 2
	txts.add_theme_constant_override("h_separation", 12)
	txts.add_theme_constant_override("v_separation", 12)
	for b in ed.find_children("*", "Button", true, false):
		if b.name == "CloseOuterClick":
			continue
		_marble_button(b)
		b.add_theme_font_size_override("font_size", 22)
		if b.get_parent() == txts:
			b.custom_minimum_size = Vector2((W - 140.0) / 2.0, 54.0)

# ---- Exceeded characters on the arena -----------------------------------------------------
# An exceeded character's arena icon gets a thicker, flashing, glowing border.

func _update_exceed_icons() -> void:
	var gw = game.game_wrapper
	if gw == null or gw.current_game == null:
		return
	# A quicker, deeper pulse: the glow swells and fades about twice a second, and the border
	# brightens with it.
	var pulse : float = 0.5 + 0.5 * sin(Time.get_ticks_msec() / 1000.0 * 6.0)
	var icon_pairs : Array = [[p1_icon, Enums.PlayerId.PlayerId_Player], [p2_icon, Enums.PlayerId.PlayerId_Opponent]]
	for key in aux_markers:
		var mk = aux_markers[key].get("marker", null)
		if mk != null and is_instance_valid(mk) and mk.has_meta("eddie_side"):
			icon_pairs.append([mk, Enums.PlayerId.PlayerId_Player if int(mk.get_meta("eddie_side")) == 0 else Enums.PlayerId.PlayerId_Opponent])
	for pair in icon_pairs:
		var icon : TextureRect = pair[0]
		if icon == null:
			continue
		var frame : Panel = icon.get_node_or_null("Frame")
		if frame == null:
			continue
		var col : Color = icon.get_meta("border_color", Color.WHITE)
		var ex : bool = gw.is_player_exceeded(pair[1])
		var glow : Panel = icon.get_node_or_null("ExceedGlow")
		var glow_col : Color = icon.get_meta("glow_color", col)
		if ex:
			var border : Color = col.lerp(Color.WHITE, 0.15 + 0.45 * pulse)
			if icon.has_meta("eddie_side"):
				border = Color(0, 0, 0).lerp(Color(0.22, 0.22, 0.22), pulse) # Eddie stays black
			frame.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), border, 8, 6))
			# The glow is drawn behind the portrait (a box shadow would tint the portrait).
			if glow == null:
				glow = Panel.new()
				glow.name = "ExceedGlow"
				glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
				glow.show_behind_parent = true
				glow.set_anchors_preset(Control.PRESET_FULL_RECT)
				icon.add_child(glow)
			var gsb := _style(glow_col, Color(0, 0, 0, 0), 0, 6)
			gsb.shadow_color = Color(glow_col.r, glow_col.g, glow_col.b, 0.2 + 0.75 * pulse)
			gsb.shadow_size = int(4.0 + 12.0 * pulse) # up to 16px
			glow.add_theme_stylebox_override("panel", gsb)
			glow.visible = true
			frame.set_meta("exceed_on", true)
		elif frame.get_meta("exceed_on", false):
			frame.set_meta("exceed_on", false)
			if glow != null:
				glow.visible = false
			frame.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), col, 4, 4))

# ---- WILD label on wild-swung strike cards ------------------------------------------------
# The game puts "WILD" in the card's top-right corner; on the phone it sits in the middle of
# the card instead (the corner one is hidden).
const WILD_CLEAR_ZONES : Array[String] = ["AllCards/PlayerDiscards", "AllCards/OpponentDiscards", "AllCards/PlayerGauge", "AllCards/OpponentGauge",
		"AllCards/PlayerHand", "AllCards/PlayerDeck", "AllCards/OpponentDeck", "AllCards/PlayerSealed", "AllCards/OpponentSealed"]

func _update_wild_labels() -> void:
	var zone = game.get_node_or_null("AllCards/Striking")
	if zone == null:
		return
	for card in zone.get_children():
		if not (card is CardBase):
			continue
		if card.bonus_wild.visible:
			card.bonus_wild.visible = false
			card.set_meta("phone_wild", true)
		var mid : RichTextLabel = card.card_features.get_node_or_null("PhoneWild")
		var want : bool = card.get_meta("phone_wild", false)
		if want and mid == null:
			mid = card.bonus_wild.duplicate()
			mid.name = "PhoneWild"
			mid.text = "[center][color=yellow][b][i]WILD[/i][/b][/color][/center]"
			mid.add_theme_font_size_override("bold_italics_font_size", 64)
			mid.autowrap_mode = TextServer.AUTOWRAP_OFF
			mid.fit_content = true
			mid.size = Vector2(250.0, 80.0)
			mid.position = Vector2(-125.0, -40.0) # centred on the card
			card.card_features.add_child(mid)
		if mid != null:
			mid.visible = want
	# Cards that left the strike lose the label.
	for z in WILD_CLEAR_ZONES:
		var n = game.get_node_or_null(z)
		if n == null:
			continue
		for card in n.get_children():
			if card is CardBase and card.has_meta("phone_wild"):
				card.remove_meta("phone_wild")
				var m = card.card_features.get_node_or_null("PhoneWild")
				if m != null:
					m.visible = false

# ---- Opponent's revealed cards ---------------------------------------------------------
# "{opponent}'s REVEALED CARDS": a reference window split in two columns, HAND (cards of
# theirs known to be in hand) and DECK (their revealed top card). A bright green eye sits on
# their hand / deck while cards there are revealed; tapping either one opens the window. It
# opens by itself whenever something new is revealed, and can't be opened when nothing is.
# While a revealed card may be picked (e.g. Elegance: "you may discard it"), a tap on it
# selects / unselects it and the island's O confirms; otherwise a tap focuses the card.
var _reveal_entries : Dictionary = {}
var _reveal_open_at : float = -1.0 # (the revealed cards window is waiting to open since then)
var _reveal_pick_active := false
var _reveal_pick_selected := false
var _reveal_eyes : Array = [null, null, null, null] # their hand, their deck, your hand, your deck
var _reveal_my_sig := ""
var _reveal_side := 1 # whose revealed cards the window shows: 0 you, 1 the opponent
var _reveal_eye_tex : Texture2D = null
var _private_eye_cache : Dictionary = {} # neon colour (html) -> recoloured eye

# The green eye recoloured to a neon version of your side's colour (red or blue): the bright
# parts glow toward white, the dark outlines stay dark.
func _private_eye_tex() -> Texture2D:
	var neon := Color(1.0, 0.18, 0.32) if _player_first else Color(0.2, 0.75, 1.0)
	var key := neon.to_html()
	if _private_eye_cache.has(key):
		return _private_eye_cache[key]
	if _reveal_eye_tex == null:
		_reveal_eye_tex = load("res://assets/icons/greeneye.png")
	var img : Image = _reveal_eye_tex.get_image()
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for y in range(img.get_height()):
		for x in range(img.get_width()):
			var c := img.get_pixel(x, y)
			if c.a <= 0.0:
				continue
			var v := maxf(c.r, maxf(c.g, c.b)) # the green's brightness
			var white := clampf((minf(c.r, c.b) - 0.35) / 0.65, 0.0, 1.0) # (its pale highlights)
			var col := (neon * v).lerp(Color(1, 1, 1), white)
			col.a = c.a
			img.set_pixel(x, y, col)
	var tex := ImageTexture.create_from_image(img)
	_private_eye_cache[key] = tex
	return tex

func _opp_reveal_info() -> Dictionary:
	return _reveal_info(1)

# ---- Your own top card, when you put it there from your hand ---------------------------------
var _self_top_id : int = -1

func _track_self_topdeck(event) -> void:
	var E = Enums.EventType
	if int(event["event_player"]) != int(Enums.PlayerId.PlayerId_Player):
		return
	var et = event["event_type"]
	if et == E.EventType_AddToDeck:
		# (checked before the game moves the card: it is still in your hand)
		var card = game.find_card_on_board(int(event["number"]))
		if card != null and card.get_parent() == game.get_hand_zone(true):
			_self_top_id = int(event["number"])
	elif et == E.EventType_ReshuffleDiscard:
		_self_top_id = -1

# The card definition id of your top card if you put it there yourself and it is still there.
func _self_known_top() -> String:
	if _self_top_id < 0:
		return ""
	var p = game.game_wrapper._get_player(Enums.PlayerId.PlayerId_Player)
	if p == null or p.deck.is_empty() or p.deck[0].id != _self_top_id:
		_self_top_id = -1 # drawn, moved or shuffled away
		return ""
	var lc = game.game_wrapper.get_card_database().get_card(_self_top_id)
	return str(lc.definition.get("id", "")) if lc != null else ""

# What of a player's hand / deck is known: side 0 you, 1 the opponent.
func _reveal_info(side : int) -> Dictionary:
	var pid := Enums.PlayerId.PlayerId_Player if side == 0 else Enums.PlayerId.PlayerId_Opponent
	var info = game.game_wrapper.get_player_public_hand_info(pid)
	var hand := {} # card definition id -> [known count, maybe-in-hand count]
	for k in info["known"]:
		hand[k] = [int(info["known"][k]), 0]
	for k in info["questionable"]:
		if hand.has(k):
			hand[k][1] = int(info["questionable"][k])
		else:
			hand[k] = [0, int(info["questionable"][k])]
	var top := str(info["topdeck"])
	if side == 0 and top == "":
		# A card you put on top of your own deck from your hand (Stolz...): you know what it
		# is even though the opponent doesn't.
		top = _self_known_top()
	return {"hand": hand, "deck": top}

# A player's deck-reference copy of a card (any copy will do for showing it).
func _ref_card(side : int, def_id : String):
	var db = game.game_wrapper.get_card_database()
	for card in game.get_node("AllCards/%sAllCopy" % ("Player" if side == 0 else "Opponent")).get_children():
		if card.card_id < 0:
			continue
		var lc = db.get_card(card.card_id - game.ReferenceScreenIdRangeStart)
		if lc != null and str(lc.definition.get("id", "")) == def_id:
			return card
	return null

# An effect choice "discard the opponent's revealed top card / pass".
func _reveal_pick_info() -> Dictionary:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_MakeChoice or not g.action_menu_container.visible:
		return {}
	var di = g.game_wrapper.get_decision_info()
	if di == null or di.type != Enums.DecisionType.DecisionType_EffectChoice:
		return {}
	var ch : Array = di.choice
	if ch.size() != 2 or g.current_action_menu_choices.size() < 2:
		return {}
	var d := -1
	var p := -1
	for i in range(2):
		var et := str(ch[i].get("effect_type", "")) if ch[i] is Dictionary else ""
		if et == "discard_opponent_topdeck":
			d = i
		elif et == "pass":
			p = i
	if d < 0 or p < 0:
		return {}
	return {"discard": d, "pass": p}

func _revealed_showing() -> bool:
	return game.card_popout_parent.get_child_count() > 0 \
			and int(game.popout_type_showing) == int(game.CardPopoutType.CardPopoutType_RevealedOpponent)

func open_revealed_box(side : int = 1) -> void:
	var ri := _reveal_info(side)
	if ri["hand"].is_empty() and ri["deck"] == "":
		return
	_reveal_side = side
	game.reset_revealed_cards()
	game.show_popout(game.CardPopoutType.CardPopoutType_RevealedOpponent, "REVEALED CARDS",
			game.get_node("AllCards/OpponentRevealed"))

func _toggle_revealed_box(side : int = 1) -> void:
	if _revealed_showing() and _reveal_side == side:
		game.close_popout()
	else:
		open_revealed_box(side)

func _place_reveal_eye(i : int, on : bool, rect : Rect2) -> void:
	var eye : TextureRect = _reveal_eyes[i]
	if not on:
		if eye != null:
			eye.visible = false
		return
	if eye == null or not is_instance_valid(eye):
		if _reveal_eye_tex == null:
			_reveal_eye_tex = load("res://assets/icons/greeneye.png")
		eye = TextureRect.new()
		eye.texture = _reveal_eye_tex
		eye.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		eye.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		eye.mouse_filter = Control.MOUSE_FILTER_IGNORE
		eye.z_index = 8 # under a focused card (z 10)
		game.add_child(eye)
		_reveal_eyes[i] = eye
	var s := minf(56.0, minf(rect.size.x, rect.size.y) * 0.8)
	eye.size = Vector2(s, s)
	eye.global_position = rect.get_center() - Vector2(s, s) / 2.0
	eye.visible = true

var _eye_fly_until_ms : int = 0

# True when, since the last check, their known top card left the deck and the only newly known
# hand cards are that same card (they drew it).
func _reveal_moved_to_hand(ri : Dictionary) -> bool:
	var old_deck := ""
	for e in _reveal_entries:
		if str(e).begins_with("d:"):
			old_deck = str(e).substr(2)
	if old_deck == "" or ri["deck"] == old_deck:
		return false
	var any_new := false
	for k in ri["hand"]:
		var key := "h:%s:%d:%d" % [k, ri["hand"][k][0], ri["hand"][k][1]]
		if not _reveal_entries.has(key):
			if str(k) != old_deck:
				return false
			any_new = true
	return any_new

func _fly_reveal_eye(src : TextureRect, target : Rect2) -> void:
	var s := minf(56.0, minf(target.size.x, target.size.y) * 0.8)
	var fly := TextureRect.new()
	fly.texture = src.texture
	fly.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fly.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	fly.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fly.z_index = src.z_index
	game.add_child(fly)
	fly.size = src.size
	fly.global_position = src.global_position
	var dur := 0.55
	_eye_fly_until_ms = Time.get_ticks_msec() + int(dur * 1000.0 / ANIM_PACE)
	var t := fly.create_tween().set_parallel(true)
	t.tween_property(fly, "global_position", target.get_center() - Vector2(s, s) / 2.0, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_property(fly, "size", Vector2(s, s), dur)
	t.chain().tween_callback(fly.queue_free)

func _update_revealed() -> void:
	var g = game
	var ri := _opp_reveal_info()
	var hand_on : bool = not ri["hand"].is_empty()
	var deck_on : bool = ri["deck"] != ""
	var mine := _reveal_info(0)
	var r0 = hand_pile_rects[1]
	var r2 = hand_pile_rects[0]
	# They drew their known top card: its eye glides from their deck to their hand (and, as
	# nothing new was learned, the revealed cards window doesn't pop up).
	var moved := _reveal_moved_to_hand(ri)
	if moved and _reveal_eyes[1] != null and is_instance_valid(_reveal_eyes[1]) and _reveal_eyes[1].visible and r0 != null:
		_fly_reveal_eye(_reveal_eyes[1], r0.get_global_rect())
	var flying : bool = Time.get_ticks_msec() < _eye_fly_until_ms
	_place_reveal_eye(0, hand_on and not flying, r0.get_global_rect() if r0 != null else Rect2())
	_place_reveal_eye(1, deck_on, odeck_rect.get_global_rect() if odeck_rect != null else Rect2())
	_place_reveal_eye(2, not mine["hand"].is_empty(), r2.get_global_rect() if r2 != null else Rect2())
	_place_reveal_eye(3, mine["deck"] != "", deck_rect.get_global_rect() if deck_rect != null else Rect2())
	# Known only to you (you put it there yourself): the same eye, in a neon version of your colour.
	if _reveal_eyes[3] != null and is_instance_valid(_reveal_eyes[3]) and _reveal_eyes[3].visible:
		var public_top := str(g.game_wrapper.get_player_public_hand_info(Enums.PlayerId.PlayerId_Player)["topdeck"])
		var want : Texture2D = _private_eye_tex() if public_top == "" else _reveal_eye_tex
		if _reveal_eyes[3].texture != want:
			_reveal_eyes[3].texture = want
	# Your own revealed cards window (opened from your deck): keep it current.
	if _revealed_showing() and _reveal_side == 0:
		var msig := JSON.stringify(mine)
		if mine["hand"].is_empty() and mine["deck"] == "":
			g.close_popout()
		elif msig != _reveal_my_sig:
			var mp = g.card_popout_parent.get_child(0)
			if mp.has_meta("phone_fitted"):
				fit_popout(mp)
		_reveal_my_sig = msig
	# What is revealed now; anything new opens the window.
	var entries := {}
	for k in ri["hand"]:
		entries["h:%s:%d:%d" % [k, ri["hand"][k][0], ri["hand"][k][1]]] = true
	if deck_on:
		entries["d:" + ri["deck"]] = true
	var grew := false
	for e in entries:
		if not _reveal_entries.has(e):
			grew = true
	if moved:
		grew = false # the same card, just moved from their deck to their hand
	var changed : bool = grew or entries.size() != _reveal_entries.size()
	_reveal_entries = entries
	var pick_on := not _reveal_pick_info().is_empty() and deck_on
	var pick_changed : bool = pick_on != _reveal_pick_active
	if pick_changed:
		_reveal_pick_active = pick_on
		_reveal_pick_selected = false
		# The pick is over (discarded or passed, e.g. Elegance): the window it opened closes.
		# (Tap their deck or hand icon to look again.)
		if not pick_on and _revealed_showing() and _reveal_side == 1:
			g.close_popout()
	var showing := _revealed_showing() and _reveal_side == 1
	if entries.is_empty():
		_reveal_open_at = -1.0
		if showing:
			g.close_popout()
		return
	var other_pick : bool = g.card_popout_parent.get_child_count() > 0 and not showing \
			and _popout_selecting(g.popout_type_showing)
	if (grew or (pick_changed and pick_on)) and not showing and not other_pick:
		_reveal_open_at = _now_s() # (opens once a boost being played has reached its box)
	if _reveal_open_at >= 0.0:
		if showing or other_pick:
			_reveal_open_at = -1.0
		elif not boost_card_arriving() or _now_s() - _reveal_open_at > 6.0:
			_reveal_open_at = -1.0
			open_revealed_box(1)
	elif (changed or pick_changed) and showing:
		var popout = g.card_popout_parent.get_child(0)
		if popout.has_meta("phone_fitted"):
			fit_popout(popout)
	_update_reveal_selection()

func _update_reveal_selection() -> void:
	if not _revealed_showing():
		return
	var popout = game.card_popout_parent.get_child(0)
	var cell = popout.find_child("RevealDeckCell", true, false)
	if cell == null:
		return
	var sel : bool = _reveal_pick_active and _reveal_pick_selected
	if sel != bool(cell.get_meta("ref_selected_flag", false)):
		cell.set_meta("ref_selected_flag", sel)
		cell.add_theme_stylebox_override("panel", _ref_cell_style(sel))

# One list row: [count] [gauge icon] "Card name - Boost name", the whole row tappable.
# Wraps a list row so its tap button also covers its share of the gap around it: a tap between
# two rows picks the nearer row instead of falling through and closing the window.
func _gap_slot(cell : Control) -> PanelContainer:
	var slot := PanelContainer.new()
	slot.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.set_meta("ref_panel", cell)
	var gap := MarginContainer.new()
	gap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gap.add_theme_constant_override("margin_left", 4)
	gap.add_theme_constant_override("margin_right", 4)
	gap.add_theme_constant_override("margin_top", 2)
	gap.add_theme_constant_override("margin_bottom", 3)
	slot.add_child(gap)
	gap.add_child(cell)
	for c in cell.get_children():
		if c is Button:
			cell.remove_child(c)
			slot.add_child(c)
	return slot

func _make_ref_cell(card, count_text : String, cell_w : float, tap : Callable, hold : Callable) -> PanelContainer:
	var cell := PanelContainer.new()
	cell.custom_minimum_size = Vector2(cell_w, 42.0)
	cell.add_theme_stylebox_override("panel", _ref_cell_style(false))
	cell.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var inset := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		inset.add_theme_constant_override("margin_" + side, 3)
	inset.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cell.add_child(inset)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inset.add_child(hb)
	var cnt := Label.new()
	cnt.text = count_text
	cnt.custom_minimum_size = Vector2(40.0, 0.0)
	cnt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cnt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cnt.add_theme_font_size_override("font_size", 24 if count_text.length() <= 2 else 17)
	cnt.add_theme_stylebox_override("normal", _style(Color(0.02, 0.03, 0.06, 0.95), Color(1, 1, 1, 0.8), 2, 5))
	cnt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(cnt)
	var ic := TextureRect.new()
	ic.custom_minimum_size = Vector2(40.0, 40.0)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.texture = _moon_icon(card)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if str(card.badge_text) != "":
		ic.add_child(_make_badge_label(card, 40.0))
	hb.add_child(ic)
	var lab := Label.new()
	lab.text = "%s - %s" % [str(card.card_attack_name), str(card.card_boost_name)]
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.custom_minimum_size = Vector2(cell_w - 40.0 - 40.0 - 16.0 - 14.0, 0.0)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lab.add_theme_font_size_override("font_size", 17)
	lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lab)
	var row_btn := _invisible_button()
	cell.add_child(row_btn)
	_wire_tap_hold(row_btn, tap, hold)
	return cell

# The extra cards window (the asterisk): no list, the cards themselves fill the window like the
# hand does, fanned when there is more than one. A tap zooms a card (or picks it, while the game
# wants a pick from this window); a long press always zooms.
func _build_extra_list(popout : Control, holder : Node) -> void:
	var rows_node : Control = popout.rows
	rows_node.visible = false
	popout.instruction_box.visible = false
	popout.title_label.get_parent().visible = false
	for b in popout.find_children("*", "Button", true, false):
		if str(b.text).to_lower().contains("close"):
			b.visible = false
	var T = game.CardPopoutType
	var t = game.popout_type_showing
	var is_p : bool = t == T.CardPopoutType_BuddyPlayer
	var cards : Array = []
	for row in rows_node.get_children():
		for spot in row.get_children():
			for c in spot.get_children():
				if c is CardBase:
					cards.append(c)
	var list := VBoxContainer.new()
	list.name = "RefList"
	list.set_meta("ref_kind", "extra")
	list.add_theme_constant_override("separation", 0)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(list)
	var fw : float = W - 44.0
	# Tall enough for hand-sized cards (the window shrinks a little to fit if it must).
	var fh : float = maxf(hand_h - 120.0, CARD_H * hand_scale + 2.0)
	var title := Label.new()
	title.name = "RefTitle"
	var stock : String = str(popout.title_label.text).strip_edges()
	var what := "EXTRA CARDS"
	if stock != "" and not stock.to_upper().ends_with("EXTRA CARDS"):
		what = stock.to_upper()
	title.text = "%s's %s" % [_ref_player_name(is_p), what]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(fw, 0.0)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(1.0, 0.9, 1.0))
	title.add_theme_color_override("font_outline_color", Color(1.0, 0.18, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(title)
	var fan := Control.new()
	fan.name = "ExtraFan"
	fan.custom_minimum_size = Vector2(fw, fh)
	fan.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fan.set_meta("keep_mouse", true)
	list.add_child(fan)
	if cards.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		empty.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_theme_font_size_override("font_size", 22)
		empty.add_theme_color_override("font_color", Color(0.6, 1.0, 1.0, 0.8))
		empty.position = Vector2.ZERO
		empty.size = Vector2(fw, fh)
		empty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		fan.add_child(empty)
		return
	# Laid out exactly like your hand: same card size, same overlap, all upright in a row.
	var n := cards.size()
	var cw : float = CARD_W * hand_scale
	var ch : float = CARD_H * hand_scale
	var margin := 24.0 # (clear of the neon frame)
	var step : float = cw
	if n > 1:
		step = clampf((fw - 2.0 * margin - cw) / (n - 1), 34.0, cw * 0.55)
	var total : float = cw + step * (n - 1)
	var x0 : float = (fw - total) / 2.0
	for i in range(n):
		var c : CardBase = cards[i]
		var btn := _invisible_button()
		btn.position = Vector2(x0 + i * step, maxf((fh - ch) / 2.0, 0.0))
		btn.size = Vector2(cw, ch)
		btn.set_meta("extra_card_id", c.card_id)
		var img := TextureRect.new()
		img.mouse_filter = Control.MOUSE_FILTER_IGNORE
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_SCALE
		img.texture = c.card_url_loaded_image if c.card_front.visible else c.card_url_loaded_cardback
		img.set_anchors_preset(Control.PRESET_FULL_RECT)
		btn.add_child(img)
		var sel := Panel.new()
		sel.name = "Sel"
		sel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		sel.set_anchors_preset(Control.PRESET_FULL_RECT)
		sel.add_theme_stylebox_override("panel", _style(Color(0, 0, 0, 0), Color(1.0, 0.3, 0.85), 5, 8))
		sel.visible = false
		btn.add_child(sel)
		fan.add_child(btn)
		var card_ref : WeakRef = weakref(c)
		var zoom := func():
			var cc = card_ref.get_ref()
			if cc == null:
				return
			# The window's own copy is face up (the real card may be face down, set aside).
			show_popout_preview(cc.card_id, cc)
		var tap := func():
			var cc = card_ref.get_ref()
			if cc == null:
				return
			if _popout_selecting(game.popout_type_showing) and cc.card_id >= 0 \
					and not cc.card_id in [CardBase.CharacterCardReferenceId, CardBase.BuddyCardReferenceId]:
				var board = game.find_card_on_board(cc.card_id)
				if board != null:
					_selecting = true
					game.on_card_clicked(board)
					_selecting = false
					_update_extra_selection()
					return
			zoom.call()
		_wire_tap_hold(btn, tap, zoom)
	_update_extra_selection()

# Picked cards in the extra cards window get a bright pink outline.
func _update_extra_selection() -> void:
	if game.card_popout_parent.get_child_count() == 0:
		return
	var fan = game.card_popout_parent.get_child(0).find_child("ExtraFan", true, false)
	if fan == null:
		return
	var ids := {}
	for c in game.selected_cards:
		if is_instance_valid(c):
			ids[c.card_id] = true
	for btn in fan.get_children():
		if btn is Button:
			btn.get_node("Sel").visible = ids.has(int(btn.get_meta("extra_card_id", -999)))

# ---- Choosing from the top of your deck (Idealism: Boost / Strike / Pass) ----------------------
# The looked-at cards are listed in the revealed cards window (top card first); a tap selects one
# (a long press zooms it) and its options become the island's buttons.
func _topdeck_picking() -> bool:
	var g = game
	return not g.observer_mode and g.ui_state == g.UIState.UIState_SelectCards \
			and g.ui_sub_state == g.UISubState.UISubState_SelectCards_ChooseFromTopdeck

# The options for the selected card: [{text, ok (action index, -1 = pass), disabled}].
func _topdeck_options() -> Array:
	var di = game.game_wrapper.get_decision_info()
	var out : Array = []
	if di == null:
		return out
	for i in range(di.action.size()):
		out.append({"text": game.get_string_for_action_choice(di.action[i]), "ok": i, "disabled": false})
	if di.can_pass:
		out.append({"text": "Pass", "ok": -1, "disabled": false})
	return out

# The cards being chosen from, top card first.
func _topdeck_cards() -> Array:
	var di = game.game_wrapper.get_decision_info()
	var out : Array = []
	if di == null:
		return out
	for cid in game.game_wrapper.get_player_top_cards(game.current_topdeck_choosing_player, int(di.amount)):
		var c = game.find_card_on_board(cid)
		if c != null:
			out.append(c)
	return out

func _topdeck_source_name() -> String:
	var di = game.game_wrapper.get_decision_info()
	if di == null or di.choice_card_id < 0:
		return ""
	var lc = game.game_wrapper.get_card_database().get_card(di.choice_card_id)
	if lc == null:
		return ""
	var bn := str(lc.definition.get("boost", {}).get("display_name", ""))
	return bn if bn != "" else str(lc.definition.get("display_name", ""))

func _topdeck_title() -> String:
	var src := _topdeck_source_name()
	var pre := (src + ": ") if src != "" else ""
	if game.selected_cards.size() == 1:
		var opts := _topdeck_options()
		if opts.size() == 1:
			return "%s%s %s?" % [pre, str(opts[0]["text"]), str(game.selected_cards[0].card_attack_name)]
		return "%sWhat will you do with %s?" % [pre, str(game.selected_cards[0].card_attack_name)]
	return "%sSelect one of the top cards of your deck" % pre

func _topdeck_select(card) -> void:
	_selecting = true
	if card in game.selected_cards:
		game.on_card_clicked(card) # deselect
	else:
		for c in game.selected_cards.duplicate():
			game.on_card_clicked(c) # only one at a time: switch to this one
		game.on_card_clicked(card)
	_selecting = false
	_choice_key = "" # the island's buttons are rebuilt for the new selection

func _build_topdeck_list(popout : Control, holder : Node) -> void:
	popout.rows.visible = false
	popout.instruction_box.visible = false
	popout.title_label.get_parent().visible = false
	for b in popout.find_children("*", "Button", true, false):
		if str(b.text).to_lower().contains("close"):
			b.visible = false
	var cell_w : float = floorf(W - 52.0)
	var list := VBoxContainer.new()
	list.name = "RefList"
	list.set_meta("ref_kind", "topdeck")
	list.add_theme_constant_override("separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(list)
	var title := Label.new()
	title.name = "RefTitle"
	title.text = "%s's REVEALED CARDS" % _ref_player_name(true)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(cell_w + 8.0, 0.0)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(title)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 0)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(col)
	var sub := Label.new()
	sub.text = "TOP OF DECK"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 22)
	sub.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
	sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	sub.add_theme_constant_override("outline_size", 5)
	sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sub)
	var db = game.game_wrapper.get_card_database()
	var cards := _topdeck_cards()
	for i in range(cards.size()):
		var real = cards[i]
		# The deck-reference copy draws the icon (it knows whose deck it is from).
		var shown = real
		var lc = db.get_card(real.card_id)
		if lc != null:
			var ref = _ref_card(0, str(lc.definition.get("id", "")))
			if ref != null:
				shown = ref
		var tap := func(): _topdeck_select(real)
		var hold := func(): show_popout_preview(real.card_id, shown)
		var cell := _make_ref_cell(shown, str(i + 1), cell_w, tap, hold)
		cell.set_meta("td_card", real)
		cell.set_meta("ref_selected_flag", false)
		col.add_child(_gap_slot(cell))
	_update_topdeck_selection(list)

func _update_topdeck_selection(list) -> void:
	if list == null or str(list.get_meta("ref_kind", "")) != "topdeck":
		return
	for cell in list.find_children("*", "PanelContainer", true, false):
		if not cell.has_meta("td_card"):
			continue
		var sel : bool = cell.get_meta("td_card") in game.selected_cards
		if sel != bool(cell.get_meta("ref_selected_flag", false)):
			cell.set_meta("ref_selected_flag", sel)
			cell.add_theme_stylebox_override("panel", _ref_cell_style(sel))

func _build_revealed_list(popout : Control, holder : Node) -> void:
	popout.rows.visible = false
	popout.instruction_box.visible = false
	popout.title_label.get_parent().visible = false
	for b in popout.find_children("*", "Button", true, false):
		if str(b.text).to_lower().contains("close"):
			b.visible = false
	var side := _reveal_side
	var ri := _reveal_info(side)
	var db = game.game_wrapper.get_card_database()
	var cell_w : float = floorf((W - 52.0) / 2.0)
	var list := VBoxContainer.new()
	list.name = "RefList"
	list.set_meta("ref_kind", "revealed")
	list.add_theme_constant_override("separation", 10)
	list.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(list)
	var title := Label.new()
	title.name = "RefTitle"
	title.text = "%s's REVEALED CARDS" % _ref_player_name(side == 0)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.custom_minimum_size = Vector2(cell_w * 2.0 + 8.0, 0.0)
	title.clip_text = true
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	title.add_theme_constant_override("outline_size", 6)
	title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(title)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 0) # the rows' tap areas fill the gaps
	cols.mouse_filter = Control.MOUSE_FILTER_IGNORE
	list.add_child(cols)
	var order := {"normal": 0, "special": 1, "ultra": 2}
	for col_name in ["HAND", "DECK"]:
		var col := VBoxContainer.new()
		col.custom_minimum_size = Vector2(cell_w + 8.0, 0.0)
		col.add_theme_constant_override("separation", 0)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		cols.add_child(col)
		var sub := Label.new()
		sub.text = col_name
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		sub.add_theme_font_size_override("font_size", 22)
		sub.add_theme_color_override("font_color", Color(0.75, 1.0, 0.75))
		sub.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		sub.add_theme_constant_override("outline_size", 5)
		sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(sub)
		var rows : Array = [] # [type order, name, card, count text, is deck card]
		if col_name == "HAND":
			for def_id in ri["hand"]:
				var card = _ref_card(side, def_id)
				if card == null:
					continue
				var known : int = ri["hand"][def_id][0]
				var maybe : int = ri["hand"][def_id][1]
				var txt := str(known + maybe) + ("?" if maybe > 0 else "")
				var def = db.get_card(card.card_id - game.ReferenceScreenIdRangeStart).definition
				rows.append([order.get(str(def.get("type", "")), 3), str(card.card_attack_name), card, txt, false])
		elif ri["deck"] != "":
			var card = _ref_card(side, ri["deck"])
			if card != null:
				rows.append([0, "", card, "1", side == 1])
		rows.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
		if rows.is_empty():
			var none := Label.new()
			none.text = "(none)"
			none.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			none.add_theme_font_size_override("font_size", 18)
			none.modulate = Color(1, 1, 1, 0.6)
			none.mouse_filter = Control.MOUSE_FILTER_IGNORE
			col.add_child(none)
		for r in rows:
			var card = r[2]
			var is_deck_card : bool = r[4]
			var focus := func(): show_popout_preview(card.card_id, card)
			var tap := func():
				if is_deck_card and _reveal_pick_active:
					_reveal_pick_selected = not _reveal_pick_selected
					_update_reveal_selection()
					return
				focus.call()
			var cell := _make_ref_cell(card, r[3], cell_w, tap, focus)
			if is_deck_card:
				cell.name = "RevealDeckCell"
			col.add_child(_gap_slot(cell))
	_update_reveal_selection()

# ---- "A pick is waiting" glow ------------------------------------------------------
# While the game is asking for cards from a gauge / discard reference, that window's border
# and the icon that opens it glow gently in the selection colour, so a player who closed the
# window to check something can see where the pick is waiting.
const PICK_GLOW_COLOR := Color(1.0, 0.2, 0.8)
var _pick_glow_t : float = 0.0
var _pick_glows : Dictionary = {} # popout type -> Panel (icon glow)
var _pick_glow_window : Panel = null
var _hand_pick_glow : Panel = null
var _hand_pick_on : bool = false
var _hand_pick_check_t : float = 0.0

# True while you are choosing cards and some card in your hand can be chosen (an action's or an
# effect's cost, discarding down to hand size at the end of the turn, a mulligan, ...).
func _hand_pick_wanted() -> bool:
	var g = game
	if g.observer_mode or g.ui_state != g.UIState.UIState_SelectCards:
		return false
	for card in g.get_hand_zone(true).get_children():
		if is_instance_valid(card) and (card.selected or g.can_select_card(card)):
			return true
	return false

# The hand area glows like the gauge / deck / discard icons do while a pick there is awaited.
func _update_hand_pick_glow(pulse : float, popout_waiting) -> void:
	_hand_pick_check_t -= get_process_delta_time()
	if _hand_pick_check_t <= 0.0:
		_hand_pick_check_t = 0.15 # (checking every card every frame isn't needed)
		_hand_pick_on = popout_waiting == null and _hand_pick_wanted()
	if not _hand_pick_on:
		if _hand_pick_glow != null and is_instance_valid(_hand_pick_glow):
			_hand_pick_glow.visible = false
		return
	if _hand_pick_glow == null or not is_instance_valid(_hand_pick_glow):
		_hand_pick_glow = Panel.new()
		_hand_pick_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_hand_pick_glow.z_index = 8 # under a focused card (z 10)
		game.add_child(_hand_pick_glow)
	_hand_pick_glow.position = Vector2(4.0, hand_y + 4.0)
	_hand_pick_glow.size = Vector2(W - 8.0, hand_h - 8.0)
	_hand_pick_glow.add_theme_stylebox_override("panel", _pick_glow_style(pulse, 4))
	_hand_pick_glow.visible = true

# Choosing a strike card: your deck icon glows along with the hand area (a tap on it wild swings).
var _deck_ws_glow : Panel = null

func _update_deck_ws_glow(pulse : float) -> void:
	var target : Control = panels.get("deck_btn_p")
	var on : bool = _is_strike_pick() and target != null and target.is_visible_in_tree()
	if not on:
		if _deck_ws_glow != null and is_instance_valid(_deck_ws_glow):
			_deck_ws_glow.visible = false
		return
	if _deck_ws_glow == null or not is_instance_valid(_deck_ws_glow):
		_deck_ws_glow = Panel.new()
		_deck_ws_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_deck_ws_glow.z_index = 8 # under a focused card (z 10)
		game.add_child(_deck_ws_glow)
	var r : Rect2 = target.get_global_rect()
	_deck_ws_glow.global_position = r.position - Vector2(2, 2)
	_deck_ws_glow.size = r.size + Vector2(4, 4)
	# (brighter, steady, while the wild swing is picked and waiting for its confirmation)
	_deck_ws_glow.add_theme_stylebox_override("panel", _pick_glow_style(1.0 if _ws_pending_live() else pulse, 4 if _ws_pending_live() else 3))
	_deck_ws_glow.visible = true

func _pick_glow_style(pulse : float, width : int) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.draw_center = false
	sb.border_color = Color(PICK_GLOW_COLOR, 0.55 + 0.45 * pulse)
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(8)
	sb.shadow_color = Color(PICK_GLOW_COLOR, 0.25 + 0.35 * pulse)
	sb.shadow_size = int(4.0 + 8.0 * pulse)
	return sb

func _pick_glow_target(t) -> Control:
	var T = game.CardPopoutType
	match t:
		T.CardPopoutType_DiscardPlayer: return game.get_node_or_null("AllCards/PlayerDiscardButton")
		T.CardPopoutType_DiscardOpponent: return game.get_node_or_null("AllCards/OpponentDiscardButton")
		T.CardPopoutType_GaugePlayer: return panels.get("gauge_btn_p")
		T.CardPopoutType_GaugeOpponent: return panels.get("gauge_btn_o")
		T.CardPopoutType_RevealedOpponent: return panels.get("deck_btn_o")
		T.CardPopoutType_ReferencePlayer: return panels.get("deck_btn_p")
		T.CardPopoutType_ReferenceOpponent: return panels.get("deck_btn_o")
		T.CardPopoutType_BoostPlayer: return game.get_node_or_null("PlayerBoostZone/OuterMargin/Focus")
		T.CardPopoutType_BoostOpponent: return game.get_node_or_null("OpponentBoostZone/OuterMargin/Focus")
	return null

func _update_pick_glows() -> void:
	_pick_glow_t += get_process_delta_time()
	var pulse : float = 0.5 + 0.5 * sin(_pick_glow_t * 3.0)
	var T = game.CardPopoutType
	var waiting = null
	var info = game.popout_instruction_info
	if info and game.ui_state == game.UIState.UIState_SelectCards:
		var it : int = int(info.get("popout_type", -1))
		if it in [T.CardPopoutType_DiscardPlayer, T.CardPopoutType_DiscardOpponent,
				T.CardPopoutType_GaugePlayer, T.CardPopoutType_GaugeOpponent,
				T.CardPopoutType_ReferencePlayer, T.CardPopoutType_ReferenceOpponent,
				T.CardPopoutType_BoostPlayer, T.CardPopoutType_BoostOpponent]:
			waiting = it
	if _reveal_pick_active:
		waiting = int(T.CardPopoutType_RevealedOpponent)
	# Icon glows.
	for t in [T.CardPopoutType_DiscardPlayer, T.CardPopoutType_DiscardOpponent,
			T.CardPopoutType_GaugePlayer, T.CardPopoutType_GaugeOpponent, T.CardPopoutType_RevealedOpponent,
			T.CardPopoutType_ReferencePlayer, T.CardPopoutType_ReferenceOpponent,
			T.CardPopoutType_BoostPlayer, T.CardPopoutType_BoostOpponent]:
		var glow : Panel = _pick_glows.get(t, null)
		var target := _pick_glow_target(t)
		var on : bool = waiting != null and int(waiting) == int(t) and target != null and target.is_visible_in_tree()
		if not on:
			if glow != null:
				glow.visible = false
			continue
		if glow == null or not is_instance_valid(glow):
			glow = Panel.new()
			glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
			glow.z_index = 8 # under a focused card (z 10)
			game.add_child(glow)
			_pick_glows[t] = glow
		var r : Rect2 = target.get_global_rect()
		glow.global_position = r.position - Vector2(2, 2)
		glow.size = r.size + Vector2(4, 4)
		glow.add_theme_stylebox_override("panel", _pick_glow_style(pulse, 3))
		glow.visible = true
	_update_hand_pick_glow(pulse, waiting)
	_update_deck_ws_glow(pulse)
	# Window border glow, while the waiting pick's window is the one showing.
	var popout = game.card_popout_parent.get_child(0) if game.card_popout_parent.get_child_count() > 0 else null
	var window_on : bool = popout != null and popout.has_meta("phone_fitted") and waiting != null \
			and int(game.popout_type_showing) == int(waiting) \
			and popout.rows.get_parent().get_node_or_null("RefList") != null
	if not window_on:
		if _pick_glow_window != null and is_instance_valid(_pick_glow_window):
			_pick_glow_window.visible = false
		return
	if _pick_glow_window == null or not is_instance_valid(_pick_glow_window) or _pick_glow_window.get_parent() != popout:
		_pick_glow_window = Panel.new()
		_pick_glow_window.name = "RefPickGlow"
		_pick_glow_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
		popout.add_child(_pick_glow_window)
	var container : Control = popout.popout_container
	_pick_glow_window.position = container.position
	_pick_glow_window.size = container.size
	_pick_glow_window.add_theme_stylebox_override("panel", _pick_glow_style(pulse, 4))
	_pick_glow_window.visible = true


# A tap on a row while picking: selects another copy of that card when one can be selected,
# otherwise unselects the copies of it that are selected.
func _ref_row_pick(group : Array) -> void:
	var picked := false
	_selecting = true
	for c in group:
		if is_instance_valid(c) and not (c in game.selected_cards) and _can_toggle_selection(c):
			game.on_card_clicked(c)
			picked = true
			break
	if not picked:
		for c in group:
			if is_instance_valid(c) and c in game.selected_cards:
				game.on_card_clicked(c)
	_selecting = false
	_update_ref_list_selection()

# Rows with selected copies get a bright pink outline, like selected gauge boxes do, and their
# count shows how many of the copies are selected ("1/2").
func _update_ref_list_selection() -> void:
	_update_extra_selection()
	if game.card_popout_parent.get_child_count() == 0:
		return
	var popout = game.card_popout_parent.get_child(0)
	var grid = popout.find_child("RefGrid", true, false)
	if grid == null:
		return
	for slot in grid.get_children():
		var cell = slot.get_meta("ref_panel", slot)
		var n_sel := 0
		for c in cell.get_meta("ref_cards", []):
			if is_instance_valid(c) and c in game.selected_cards:
				n_sel += 1
		if n_sel == int(cell.get_meta("ref_selected", -1)):
			continue
		cell.set_meta("ref_selected", n_sel)
		cell.add_theme_stylebox_override("panel", _ref_cell_style(n_sel > 0))
		var cnt : Label = cell.get_meta("ref_count_label")
		var total : int = int(cell.get_meta("ref_count", 0))
		if n_sel > 0 and total > 1:
			cnt.text = "%d/%d" % [n_sel, total]
			cnt.add_theme_font_size_override("font_size", 17)
		else:
			cnt.text = str(total)
			cnt.add_theme_font_size_override("font_size", 24)

# Keeps an open list window in step with the game: when a pick from it starts or ends, the
# list is rebuilt (one row per card while picking), and selection outlines follow the game.
func _reconcile_ref_list_popout() -> void:
	if game.card_popout_parent.get_child_count() == 0:
		return
	var popout = game.card_popout_parent.get_child(0)
	if not popout.has_meta("phone_fitted"):
		return
	var list = popout.rows.get_parent().get_node_or_null("RefList")
	if list == null:
		# The top-of-deck pick opens its window a moment before the game enters the pick
		# state: once it has, redo the window as the revealed cards list.
		if _ref_list_kind(game.popout_type_showing) == "topdeck":
			fit_popout(popout)
		return
	var kind := _ref_list_kind(game.popout_type_showing)
	if kind != "" and kind != str(list.get_meta("ref_kind", "")):
		fit_popout(popout)
		return
	if popout.instruction_box.visible:
		popout.instruction_box.visible = false
	_update_ref_list_selection()
	_update_topdeck_selection(list)
	if Time.get_ticks_msec() >= _odds_next_ms:
		_odds_next_ms = Time.get_ticks_msec() + 500
		_update_odds_row(list.get_node_or_null("RefOdds"))

func fit_popout(popout : Control) -> void:
	# A newly opened window is laid out a frame later (below); keep it invisible until then,
	# or it flashes at its default size / position first. (Refreshes of an open window keep
	# showing it, so they don't blink.)
	var first_fit := not popout.has_meta("phone_fitted")
	if first_fit:
		popout.modulate.a = 0.0
	_build_reference_list(popout)
	popout.custom_minimum_size = Vector2.ZERO
	popout.z_index = 30
	# The window fills the hand area; tapping outside no longer closes it (that would
	# fight with the toggle behaviour of the buttons that open it). CLOSE WINDOW or
	# tapping the same opener button closes it.
	popout.set_close_on_outside_click(false)
	# Display-only reference cards (character / extra cards) are not wired to the
	# game; let them open the focus preview too.
	for row in popout.rows.get_children():
		for spot in row.get_children():
			if spot.get_child_count() == 0:
				continue
			var ref_card = spot.get_child(0)
			if ref_card is CardBase and ref_card.card_id in [CardBase.CharacterCardReferenceId, CardBase.BuddyCardReferenceId]:
				if not ref_card.clicked_card.is_connected(_on_reference_card_clicked):
					ref_card.clicked_card.connect(_on_reference_card_clicked)
	var container : Control = popout.popout_container
	container.custom_minimum_size = Vector2.ZERO
	container.reset_size()
	var margin = container.get_node_or_null("PopoutVBox/Margin")
	if margin != null:
		margin.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	await get_tree().process_frame
	if not is_instance_valid(popout):
		return
	var cs := container.get_combined_minimum_size()
	var area := Rect2(4.0, hand_y + 2.0, W - 8.0, hand_h - 4.0)
	var s := minf(1.0, minf(area.size.x / maxf(cs.x, 1.0), area.size.y / maxf(cs.y, 1.0)))
	popout.scale = Vector2(s, s)
	popout.position = area.position
	container.custom_minimum_size = area.size / s
	container.size = area.size / s
	_finish_reference_popout(popout, container)
	popout.set_meta("phone_fitted", true)
	var old_t = popout.get_meta("phone_window_tween", null)
	if old_t is Tween and old_t.is_valid():
		old_t.kill()
	if first_fit and ANIMATE_WINDOWS:
		# Opens smoothly: grows from a little smaller (from its center) while fading in.
		var t := popout.create_tween().set_parallel(true)
		popout.set_meta("phone_window_tween", t)
		t.tween_method(func(k : float):
			popout.scale = Vector2(s * k, s * k)
			popout.position = area.position + area.size * (1.0 - k) / 2.0,
			WINDOW_FROM, 1.0, WINDOW_IN).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		t.tween_property(popout, "modulate:a", 1.0, WINDOW_IN * 0.7)
	else:
		popout.scale = Vector2(s, s)
		popout.position = area.position
		popout.modulate.a = 1.0

# List windows open and close with a quick grow / shrink and fade.
const ANIMATE_WINDOWS := true
const WINDOW_FROM := 0.88
const WINDOW_IN := 0.2
const WINDOW_OUT := 0.16
var _closing_windows : Node2D = null

# Game.close_popout: a fitted list window leaves smoothly. It is taken out of the popout parent at
# once (so the game sees it closed), into a holder drawn at the same place, and freed once faded.
func close_window_animated(popout) -> bool:
	if not ANIMATE_WINDOWS or not (popout is Control) or not popout.has_meta("phone_fitted") \
			or not is_instance_valid(popout) or popout.is_queued_for_deletion():
		return false
	var parent = game.card_popout_parent
	if _closing_windows == null or not is_instance_valid(_closing_windows):
		_closing_windows = Node2D.new()
		_closing_windows.name = "PhoneClosingWindows"
		parent.get_parent().add_child(_closing_windows)
		parent.get_parent().move_child(_closing_windows, parent.get_index() + 1)
	_closing_windows.transform = parent.transform
	_closing_windows.z_index = parent.z_index
	_closing_windows.z_as_relative = parent.z_as_relative
	var old_t = popout.get_meta("phone_window_tween", null)
	if old_t is Tween and old_t.is_valid():
		old_t.kill()
	popout.reparent(_closing_windows, false)
	# No more taps on it.
	for n in popout.find_children("*", "Control", true, false):
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	popout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var s0 : Vector2 = popout.scale
	var p0 : Vector2 = popout.position
	var full : Vector2 = popout.popout_container.size * s0
	var t : Tween = popout.create_tween().set_parallel(true)
	t.tween_method(func(k : float):
		popout.scale = s0 * k
		popout.position = p0 + full * (1.0 - k) / 2.0,
		1.0, WINDOW_FROM, WINDOW_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_property(popout, "modulate:a", 0.0, WINDOW_OUT).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.chain().tween_callback(popout.queue_free)
	return true

# Backdrops for the list windows, as theme sets (one can be picked with `window_theme`; a
# settings choice can switch it later). Kept artwork for future sets:
#   res://scenes/game/sky_bg.gd — the daytime sky first used for the revealed cards.
#   res://scenes/game/racetrack_bg.gd — the top-down racetrack first used for the gauge.
const WINDOW_THEMES := {
	"default": {
		"deck": "res://scenes/game/space_bg.gd",      # deck reference: outer space
		"gauge": "res://scenes/game/flower_of_life_bg.gd", # glowing Flower of Life, mandala stars
		"discard": "res://scenes/game/sea_bg.gd",     # under the sea
		"revealed": "res://scenes/game/sunset_bg.gd", # late sunset with a passing plane
		"boost": "res://scenes/game/boost_fire.gd",   # glowing embers
		"extra": "res://scenes/game/neon_bg.gd",      # cyberpunk neon sign
		"sealed": "res://scenes/game/graveyard_bg.gd", # graveyard at night
	},
}
var window_theme : String = "default"

# Deck / gauge / discard list windows: outer-space backdrop, and any tap outside the gauge
# icons closes it.
func _finish_reference_popout(popout : Control, container : Control) -> void:
	if popout.rows.get_parent().get_node_or_null("RefList") == null:
		return
	container.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	var bg : Control = popout.get_node_or_null("RefBg")
	if bg == null:
		# Each kind of window has its own backdrop: discards under the sea, revealed cards in
		# the sky, boosts on glowing embers, everything else in outer space.
		var T = game.CardPopoutType
		var t = game.popout_type_showing
		var theme : Dictionary = WINDOW_THEMES.get(window_theme, WINDOW_THEMES["default"])
		var script_path : String = theme["deck"]
		if t in [T.CardPopoutType_DiscardPlayer, T.CardPopoutType_DiscardOpponent]:
			script_path = theme["discard"]
		elif t in [T.CardPopoutType_GaugePlayer, T.CardPopoutType_GaugeOpponent]:
			script_path = theme.get("gauge", theme["deck"])
		elif t == T.CardPopoutType_RevealedOpponent or _ref_list_kind(t) == "topdeck":
			script_path = theme["revealed"]
		elif t in [T.CardPopoutType_BoostPlayer, T.CardPopoutType_BoostOpponent]:
			script_path = theme["boost"]
		elif t in [T.CardPopoutType_BuddyPlayer, T.CardPopoutType_BuddyOpponent]:
			script_path = theme["extra"]
		elif t in [T.CardPopoutType_SealedPlayer, T.CardPopoutType_SealedOpponent]:
			script_path = theme["sealed"]
		bg = load(script_path).new()
		bg.name = "RefBg"
		popout.add_child(bg)
		popout.move_child(bg, 0)
		if bg.has_method("set_level"):
			bg.set_level(1) # glowing embers
		if "glow_labels" in bg:
			var rt = popout.find_child("RefTitle", true, false)
			if rt != null:
				bg.glow_labels = [rt]
	bg.position = Vector2.ZERO
	bg.size = container.size
	if popout.get_node_or_null("RefCloser") == null:
		var closer := _invisible_button()
		closer.name = "RefCloser"
		closer.pressed.connect(func(): popout.close_window.emit())
		popout.add_child(closer)
		popout.move_child(closer, 1)
	# Covers the whole screen (in the window's own scaled / offset coordinates). It must not be
	# a top-level node: those are picked before everything else and would swallow icon taps.
	var closer_node : Control = popout.get_node("RefCloser")
	var sc : float = maxf(popout.scale.x, 0.01)
	closer_node.position = -popout.position / sc
	closer_node.size = Vector2(W, H) / sc
	for n in container.find_children("*", "Control", true, false):
		if n is BaseButton or n.has_meta("keep_mouse"):
			continue
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
	container.mouse_filter = Control.MOUSE_FILTER_IGNORE

# --- Focus preview for cards shown inside a popup window -----------------------
# Tapping a card in a popup shows it large (like focusing a hand card). When the
# game is waiting for a card selection a Select / Deselect button is offered.
var popout_preview_root : Node2D = null
var popout_preview_id : int = -1
var popout_preview_select : Button = null

func show_popout_preview(card_id : int, src_override = null) -> bool:
	# Character / extra-card reference cards only exist inside the popup (they are
	# not on the board), so the popup's own card is the source for those.
	var src = src_override if src_override != null else game.find_card_on_board(card_id)
	if src == null:
		return false
	close_popout_preview()
	popout_preview_id = card_id
	popout_preview_root = Node2D.new()
	popout_preview_root.z_index = 40
	game.add_child(popout_preview_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dim.position = Vector2.ZERO
	dim.size = Vector2(W, H)
	popout_preview_root.add_child(dim)
	var close_btn := _flat_button(popout_preview_root, close_popout_preview)
	close_btn.position = Vector2.ZERO
	close_btn.size = Vector2(W, H)
	if GlobalSettings.phone_controls_active():
		# Phone controls: tap selects (when possible, otherwise closes); long press closes.
		close_btn.pressed.disconnect(close_popout_preview)
		close_btn.pressed.connect(_on_popout_preview_tap)
		close_btn.button_down.connect(_on_popout_preview_down)
		_popout_close_btn = close_btn

	var card : CardBase = load("res://scenes/card/card_base.tscn").instantiate()
	popout_preview_root.add_child(card)
	card.initialize_simple(card_id, src.card_url_loaded_image, src.card_url_loaded_cardback, src.card_attack_name, src.card_boost_name)
	if src.badge_text != "":
		card.set_badge(src.badge_text, src.badge_color, src.badge_s6)
	card.flip_card_to_front(src.card_front.visible)
	card.change_state(CardBase.CardState.CardState_InPopout)
	card.set_card_and_focus(CardBase.phone_focus_center, 0, CardBase.phone_focus_scale)
	card.focus_feature.get_node("Focus").mouse_filter = Control.MOUSE_FILTER_IGNORE
	card._set_preview_input_ignored(true)
	# It grows out of where it was tapped (a gauge box, a card in a window), like a hand card
	# does when it is focused.
	var grow_from : Vector2 = popout_preview_root.get_local_mouse_position()
	var grow_s := Vector2(hand_scale, hand_scale) * 0.6
	card.set_card_and_focus(grow_from, 0, grow_s)
	var grow := card.create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	for f in [card.card_features, card.focus_feature]:
		grow.tween_property(f, "position", CardBase.phone_focus_center, 0.14)
		grow.tween_property(f, "scale", CardBase.phone_focus_scale, 0.14)
	dim.modulate.a = 0.0
	dim.create_tween().tween_property(dim, "modulate:a", 1.0, 0.14)

	popout_preview_select = _text_button(popout_preview_root, "Select", _on_popout_select_pressed, 28)
	var pv_s : float = CardBase.phone_focus_scale.x
	var pv_c : Vector2 = CardBase.phone_focus_center
	var pv_h := CARD_H * pv_s
	popout_preview_select.position = Vector2(pv_c.x - 95.0, pv_c.y - pv_h / 2.0 + 0.595 * pv_h - 28.0)
	popout_preview_select.size = Vector2(190, 56)
	var can_select : bool = src_override == null and (not game.observer_mode) and (game.ui_state == game.UIState.UIState_SelectCards \
			or game.ui_state == game.UIState.UIState_PickTurnAction)
	_popout_can_select = can_select
	# Phone controls select with a tap instead, so the button is not shown.
	popout_preview_select.visible = can_select and not GlobalSettings.phone_controls_active()
	_refresh_popout_select()
	return true

func _on_reference_card_clicked(card) -> void:
	show_popout_preview(card.card_id, card)

var _preview_keep : bool = false # a preview opened straight from a gauge box (no popup behind it)
var _preview_from_gauge : bool = false # ... and it is one of your gauge cards

func close_popout_preview() -> void:
	_preview_keep = false
	_preview_from_gauge = false
	if popout_preview_root != null and is_instance_valid(popout_preview_root):
		popout_preview_root.queue_free()
	popout_preview_root = null
	popout_preview_select = null
	popout_preview_id = -1

func _refresh_popout_select() -> void:
	if popout_preview_select == null or not is_instance_valid(popout_preview_select):
		return
	var is_selected := false
	for c in game.selected_cards:
		if is_instance_valid(c) and c.card_id == popout_preview_id:
			is_selected = true
	popout_preview_select.text = "Deselect" if is_selected else "Select"

func _on_popout_select_pressed() -> void:
	var board_card = game.find_card_on_board(popout_preview_id)
	if board_card != null:
		game.on_card_clicked(board_card)
		_refresh_popout_select()
		_refresh_popout_select.call_deferred()

# Opens a popup via `opener`, or closes it if that same popup is already showing.
func _toggle_popout(popout_type : int, opener : Callable) -> void:
	if game.card_popout_parent.get_child_count() > 0 and int(game.popout_type_showing) == popout_type:
		game.close_popout()
		return
	opener.call()

func _rewire_popout_buttons() -> void:
	var T = game.CardPopoutType
	for entry in [
			["AllCards/PlayerDiscardButton", "pressed", "_on_player_discard_button_pressed", T.CardPopoutType_DiscardPlayer],
			["AllCards/OpponentDiscardButton", "pressed", "_on_opponent_discard_button_pressed", T.CardPopoutType_DiscardOpponent],
			["PlayerBoostZone", "clicked_zone", "_on_player_boost_zone_clicked_zone", T.CardPopoutType_BoostPlayer],
			["OpponentBoostZone", "clicked_zone", "_on_opponent_boost_zone_clicked_zone", T.CardPopoutType_BoostOpponent],
			["ChoicePopoutShowButton", "pressed", "_on_choice_popout_show_button_pressed", T.CardPopoutType_ChoiceZone]]:
		var node = game.get_node_or_null(entry[0])
		if node == null:
			continue
		var original := Callable(game, entry[2])
		if node.is_connected(entry[1], original):
			node.disconnect(entry[1], original)
		var ptype : int = entry[3]
		node.connect(entry[1], func(): _toggle_popout(ptype, original))

func slideout_start() -> Vector2:
	return Vector2(W, stage_y + stage_full_h * 0.7)
