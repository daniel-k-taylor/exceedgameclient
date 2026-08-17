class_name CardImageLoader
extends Node2D

var loaded_images = {}
var image_load_queue = []
var image_load_atlas_map = {}
var image_load_requested_indices = {}
var processing_queue = false
var test_mode : bool = false
var http_request : HTTPRequest
var is_tearing_down : bool = false

signal finished_loading_image(image)
signal image_queue_advanced

const CARD_WIDTH = 750.0
const CARD_HEIGHT = 1024.0
# On mobile web, downscale card textures to conserve GPU memory.
const MOBILE_WEB_CARD_SCALE = 0.6
# Never upload a texture whose largest dimension exceeds this (GPU/browser cap).
const MOBILE_WEB_MAX_ATLAS_DIMENSION = 4096
# Yield to the main loop every N created sub-textures to avoid frame hitches.
const MOBILE_WEB_YIELD_EVERY_TEXTURES = 6
# Tolerance (in px) for absorbing slightly-off atlas dimensions into a clean grid.
const ATLAS_DIMENSION_TOLERANCE = 8

func _is_mobile_web() -> bool:
	return OS.has_feature("web") and (
		OS.has_feature("mobile")
		or OS.has_feature("web_android")
		or OS.has_feature("web_ios")
	)

func _get_target_card_size() -> Vector2i:
	var scale_factor = MOBILE_WEB_CARD_SCALE if _is_mobile_web() else 1.0
	return Vector2i(
		int(round(CARD_WIDTH * scale_factor)),
		int(round(CARD_HEIGHT * scale_factor))
	)

func _should_resize_single_card_for_runtime(image_atlas_details, loaded_image: Image) -> bool:
	var is_season7 = image_atlas_details.get('season', 0) == 7
	var is_season6 = image_atlas_details.get('season', 0) == 6
	var is_season1 = image_atlas_details.get('season', 0) == 1
	if is_season1 or is_season6 or is_season7:
		return true
	if not _is_mobile_web():
		return false
	var target_card_size = _get_target_card_size()
	return loaded_image.get_width() > target_card_size.x or loaded_image.get_height() > target_card_size.y

func _should_avoid_full_atlas_texture(image_atlas_details, loaded_image: Image) -> bool:
	var is_season7 = image_atlas_details.get('season', 0) == 7
	var is_season6 = image_atlas_details.get('season', 0) == 6
	var is_season1 = image_atlas_details.get('season', 0) == 1
	if _is_mobile_web() and image_atlas_details.get('multiple_cards', false):
		# On mobile web, always skip the "upload the whole atlas as one GPU texture"
		# path for multi-card atlases. Crop each sub-card first to reduce the risk of
		# crashes on large atlases.
		return true
	if is_season1 or is_season6 or is_season7:
		return true
	if image_atlas_details.get('recalculate_card_sizes', false):
		return true
	return max(loaded_image.get_width(), loaded_image.get_height()) > MOBILE_WEB_MAX_ATLAS_DIMENSION

func _create_card_texture_from_image(source_image: Image) -> Texture2D:
	var image_to_upload = source_image
	if _is_mobile_web():
		var target_card_size = _get_target_card_size()
		if source_image.get_width() != target_card_size.x or source_image.get_height() != target_card_size.y:
			image_to_upload = ImageResizer.resize_to(source_image, target_card_size.x, target_card_size.y)
	return ImageTexture.create_from_image(image_to_upload)

func _get_scaled_mobile_atlas_size(source_image: Image) -> Vector2i:
	return Vector2i(
		max(1, int(round(source_image.get_width() * MOBILE_WEB_CARD_SCALE))),
		max(1, int(round(source_image.get_height() * MOBILE_WEB_CARD_SCALE))))

func _get_scaled_mobile_atlas_layout(grid_w: int, grid_h: int, card_width: float, card_height: float, offset_x: int, offset_y: int) -> Dictionary:
	var scaled_offset_x = int(round(offset_x * MOBILE_WEB_CARD_SCALE))
	var scaled_offset_y = int(round(offset_y * MOBILE_WEB_CARD_SCALE))
	var scaled_card_width = max(1, int(round(card_width * MOBILE_WEB_CARD_SCALE)))
	var scaled_card_height = max(1, int(round(card_height * MOBILE_WEB_CARD_SCALE)))
	return {
		"offset_x": scaled_offset_x,
		"offset_y": scaled_offset_y,
		"card_width": scaled_card_width,
		"card_height": scaled_card_height,
		"atlas_size": Vector2i(
			scaled_offset_x + grid_w * scaled_card_width,
			scaled_offset_y + grid_h * scaled_card_height)
	}

func _should_use_scaled_mobile_atlas_texture(image_atlas_details, source_image: Image) -> bool:
	if not _is_mobile_web() or not image_atlas_details.get('multiple_cards', false):
		return false
	var scaled_atlas_size = _get_scaled_mobile_atlas_size(source_image)
	return max(scaled_atlas_size.x, scaled_atlas_size.y) <= MOBILE_WEB_MAX_ATLAS_DIMENSION

func _normalize_image_url(raw_url: String) -> String:
	if raw_url.begins_with("http://"):
		return "https://" + raw_url.trim_prefix("http://")
	return raw_url

func _detect_image_type(headers, body: PackedByteArray) -> String:
	if body.size() >= 8 and body[0] == 0x89 and body[1] == 0x50 and body[2] == 0x4E and body[3] == 0x47 and body[4] == 0x0D and body[5] == 0x0A and body[6] == 0x1A and body[7] == 0x0A:
		return "png"
	if body.size() >= 3 and body[0] == 0xFF and body[1] == 0xD8 and body[2] == 0xFF:
		return "jpg"

	for header in headers:
		var header_lower = header.to_lower()
		if header_lower.begins_with("content-type"):
			var mime_part = header_lower.split("/")[-1].split(";")[0].strip_edges()
			if mime_part == "png":
				return "png"
			if mime_part in ["jpeg", "jpg"]:
				return "jpg"
			break

	return "jpg"

func _init(testing_mode = false):
	test_mode = testing_mode
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._image_request_completed)

func teardown():
	is_tearing_down = true
	image_load_queue.clear()
	image_load_atlas_map.clear()
	image_load_requested_indices.clear()
	loaded_images.clear()
	processing_queue = false
	finished_loading_image.emit(null)
	image_queue_advanced.emit()
	if http_request:
		http_request.cancel_request()
		if http_request.request_completed.is_connected(self._image_request_completed):
			http_request.request_completed.disconnect(self._image_request_completed)
		http_request.queue_free()
		http_request = null

func _process(_delta):
	if is_tearing_down:
		return
	if not processing_queue and len(image_load_queue) > 0:
		_process_request_queue()

func _register_requested_index(image_url : String, image_index : int):
	if image_url not in image_load_requested_indices:
		image_load_requested_indices[image_url] = {}
	image_load_requested_indices[image_url][image_index] = true

static func merge_image_atlas_details(existing_details: Dictionary, incoming_details: Dictionary) -> Dictionary:
	var merged_details = existing_details.duplicate(true)
	for key in incoming_details.keys():
		var incoming_value = incoming_details[key]
		if not merged_details.has(key):
			merged_details[key] = incoming_value
			continue

		if key == "multiple_cards":
			merged_details[key] = merged_details[key] or incoming_value
			continue
		if key == "force_cropped_textures":
			merged_details[key] = merged_details[key] or incoming_value
			continue

		var existing_value = merged_details[key]
		if existing_value == null:
			merged_details[key] = incoming_value
		elif typeof(existing_value) == TYPE_STRING and existing_value == "":
			merged_details[key] = incoming_value
		elif typeof(existing_value) == TYPE_BOOL and not existing_value and incoming_value != false:
			merged_details[key] = incoming_value
		elif typeof(existing_value) == TYPE_INT and existing_value == 0 and incoming_value != 0:
			merged_details[key] = incoming_value
	return merged_details

static func should_materialize_all_multi_card_textures(is_mobile_web: bool, image_atlas_details: Dictionary) -> bool:
	return is_mobile_web and image_atlas_details.get('multiple_cards', false)

static func should_create_atlas_texture(requested_indices : Dictionary, image_index : int) -> bool:
	return requested_indices.has(-1) or requested_indices.has(image_index)

# Loads card images if they haven't yet been accessed
func load_image_page(image_atlas):
	load_image_page_indexed(image_atlas, -1)

func load_image_page_indexed(image_atlas, image_index : int):
	if test_mode or is_tearing_down:
		return

	var image_url = _normalize_image_url(image_atlas['url'])
	var normalized_image_atlas = image_atlas.duplicate(true)
	normalized_image_atlas['url'] = image_url
	_register_requested_index(image_url, image_index)

	if image_url in image_load_atlas_map:
		image_load_atlas_map[image_url] = merge_image_atlas_details(image_load_atlas_map[image_url], normalized_image_atlas)
	else:
		image_load_atlas_map[image_url] = normalized_image_atlas

	if image_url not in loaded_images and image_url not in image_load_queue:
		image_load_queue.append(image_url)

func _process_request_queue():
	if is_tearing_down or image_load_queue.is_empty():
		return
	processing_queue = true
	var image_url = image_load_queue[0]
	var image_atlas_details = image_load_atlas_map[image_url]
	var is_multiple = image_atlas_details['multiple_cards']

	var loaded_image = ImageCache.load_image(image_url)
	if not loaded_image: # not found in cache; send http request
		var error = http_request.request(image_url)
		if error != OK:
			push_error("[CardImageLoader] Failed to start HTTP request, error %d, URL: %s" % [error, image_url])
			loaded_images[image_url] = null
			image_load_queue.pop_at(0)
			processing_queue = false
			image_queue_advanced.emit()
			return
		loaded_image = await finished_loading_image
		if is_tearing_down:
			return
		if loaded_image:
			ImageCache.cache_image(image_url, loaded_image)
		else:
			push_error("[CardImageLoader] Image decode failed, URL: " + image_url)

	var image_texture = null
	if loaded_image:
		var is_season7 = image_atlas_details.get('season', 0) == 7
		var is_season6 = image_atlas_details.get('season', 0) == 6
		var is_season1 = image_atlas_details.get('season', 0) == 1
		var target_card_size = _get_target_card_size()
		if not is_multiple and _should_resize_single_card_for_runtime(image_atlas_details, loaded_image):
			loaded_image = ImageResizer.resize_in_place(loaded_image, target_card_size.x, target_card_size.y)
		if is_multiple:
			var card_width = CARD_WIDTH
			var card_height = CARD_HEIGHT
			var region_width = loaded_image.get_width()
			var region_height = loaded_image.get_height()
			if image_atlas_details.get('recalculate_card_sizes', false):
				if image_atlas_details['sprite_region_width'] > 0:
					region_width = image_atlas_details['sprite_region_width']
				if image_atlas_details['sprite_region_height'] > 0:
					region_height = image_atlas_details['sprite_region_height']
				card_width = region_width / image_atlas_details['sprite_count_width']
				card_height = region_height / image_atlas_details['sprite_count_height']
			elif is_season7:
				# Season 7: derive per-card size from the atlas using fixed columns/rows.
				const S7_3ROW_CHARS = ["happychaos", "jacko", "may", "nago", "testament"]
				var deck_id = image_atlas_details.get('deck_id', '')
				var s7_rows = 3 if deck_id in S7_3ROW_CHARS else 4
				card_width = float(region_width) / 6.0
				card_height = float(region_height) / float(s7_rows)
			elif is_season6:
				# Season 6: fixed 2 rows x 4 columns.
				card_width = float(region_width) / 4.0
				card_height = float(region_height) / 2.0
			elif is_season1:
				# Season 1: fixed 2 rows x 4 columns.
				card_width = float(region_width) / 4.0
				card_height = float(region_height) / 2.0

			var grid_width = region_width / card_width
			var grid_height = region_height / card_height
			var offset_x = image_atlas_details.get('sprite_offset_x', 0)
			var offset_y = image_atlas_details.get('sprite_offset_y', 0)
			if not (is_season7 or is_season6 or is_season1):
				var rounded_grid_width = int(round(grid_width))
				var rounded_grid_height = int(round(grid_height))
				var width_difference = abs(region_width - rounded_grid_width * card_width)
				var height_difference = abs(region_height - rounded_grid_height * card_height)
				if rounded_grid_width > 0 and width_difference > 0 and width_difference <= ATLAS_DIMENSION_TOLERANCE:
					card_width = float(region_width) / rounded_grid_width
					grid_width = rounded_grid_width
				if rounded_grid_height > 0 and height_difference > 0 and height_difference <= ATLAS_DIMENSION_TOLERANCE:
					card_height = float(region_height) / rounded_grid_height
					grid_height = rounded_grid_height

			if not (is_season7 or is_season6 or is_season1) and (grid_width <= 0 or grid_height <= 0 or int(grid_width) != grid_width or int(grid_height) != grid_height):
				push_error("[CardImageLoader] Atlas size (%dx%d) not divisible by card size (%.1fx%.1f); slicing will be wrong. URL: %s" % [region_width, region_height, card_width, card_height, image_url])

			var grid_w = int(round(grid_width))
			var grid_h = int(round(grid_height))
			var image_grid = []
			var requested_indices = image_load_requested_indices.get(image_url, {})
			var force_cropped_textures = image_atlas_details.get('force_cropped_textures', false)
			var use_scaled_mobile_atlas_texture = not force_cropped_textures and _should_use_scaled_mobile_atlas_texture(image_atlas_details, loaded_image)
			var use_cropped_textures = not use_scaled_mobile_atlas_texture and _should_avoid_full_atlas_texture(image_atlas_details, loaded_image)
			var materialize_all_textures = should_materialize_all_multi_card_textures(_is_mobile_web(), image_atlas_details)
			var scaled_layout = {}
			if use_scaled_mobile_atlas_texture:
				scaled_layout = _get_scaled_mobile_atlas_layout(grid_w, grid_h, card_width, card_height, offset_x, offset_y)
				var scaled_atlas_size = scaled_layout["atlas_size"]
				var scaled_atlas_image = ImageResizer.resize_to(loaded_image, scaled_atlas_size.x, scaled_atlas_size.y)
				image_texture = ImageTexture.create_from_image(scaled_atlas_image)
				scaled_atlas_image = null
			elif not use_cropped_textures:
				image_texture = ImageTexture.create_from_image(loaded_image)
			for y in range(grid_h):
				for x in range(grid_w):
					var image_index = y * grid_w + x
					if not materialize_all_textures and not should_create_atlas_texture(requested_indices, image_index):
						image_grid.append(null)
						continue
					if use_scaled_mobile_atlas_texture:
						var atlas_texture = AtlasTexture.new()
						atlas_texture.atlas = image_texture
						atlas_texture.region = Rect2(
							scaled_layout["offset_x"] + x * scaled_layout["card_width"],
							scaled_layout["offset_y"] + y * scaled_layout["card_height"],
							scaled_layout["card_width"],
							scaled_layout["card_height"])
						image_grid.append(atlas_texture)
					elif use_cropped_textures:
						# Avoid uploading the whole atlas to the GPU: crop each sub-card
						# first, then create a texture, reducing peak memory and large-texture risk.
						var rx = int(round(offset_x + x * card_width))
						var ry = int(round(offset_y + y * card_height))
						var rw = int(round(card_width))
						var rh = int(round(card_height))
						var cropped = loaded_image.get_region(Rect2i(rx, ry, rw, rh))
						if is_season7 or is_season6 or is_season1 or _is_mobile_web():
							image_grid.append(_create_card_texture_from_image(cropped))
						else:
							image_grid.append(ImageTexture.create_from_image(cropped))
						cropped = null
					else:
						var atlas_texture = AtlasTexture.new()
						atlas_texture.atlas = image_texture
						atlas_texture.region = Rect2(
							offset_x + (x * card_width), offset_y + (y * card_height),
							card_width, card_height)
						image_grid.append(atlas_texture)
					if _is_mobile_web() and image_grid.size() % MOBILE_WEB_YIELD_EVERY_TEXTURES == 0:
						await get_tree().process_frame
						if is_tearing_down:
							return
			loaded_images[image_url] = image_grid
		else:
			loaded_images[image_url] = [_create_card_texture_from_image(loaded_image)]
	else:
		push_error("[CardImageLoader] Final image is null, skipping load. URL: " + image_url)
		loaded_images[image_url] = null
	loaded_image = null
	image_texture = null
	image_load_queue.pop_at(0)
	processing_queue = false
	image_queue_advanced.emit()

func _image_request_completed(result, response_code, headers, body):
	if is_tearing_down:
		return

	# result != OK indicates a network-layer error (connection failed, timeout, SSL error, etc.)
	if result != HTTPRequest.RESULT_SUCCESS:
		push_error("[CardImageLoader] Network request failed, HTTPRequest result=%d (0=success, see HTTPRequest.Result)" % result)
		finished_loading_image.emit(null)
		return

	# A non-200 status usually means a permissions issue, an un-followed redirect, or a missing resource.
	if response_code != 200:
		push_error("[CardImageLoader] Unexpected HTTP status: %d, body (first 256 bytes): %s" % [response_code, body.slice(0, min(256, body.size())).get_string_from_utf8()])
		finished_loading_image.emit(null)
		return

	var image_type = _detect_image_type(headers, body)

	var image = Image.new()
	var load_success = false

	if image_type == "png":
		var error = image.load_png_from_buffer(body)
		if error == OK:
			load_success = true
		else:
			push_error("[CardImageLoader] PNG decode failed, error=%d, body_size=%d" % [error, body.size()])
	else:
		var error = image.load_jpg_from_buffer(body)
		if error == OK:
			load_success = true
		else:
			push_error("[CardImageLoader] JPG decode failed, error=%d, body_size=%d, first 4 bytes (hex): %s" % [error, body.size(), body.slice(0, min(4, body.size())).hex_encode()])

	if load_success:
		finished_loading_image.emit(image)
	else:
		finished_loading_image.emit(null)

func get_card_image(image_url, image_index, image_atlas_details = {}):
	if test_mode:
		var placeholder = Image.create(1, 1, false, Image.FORMAT_RGBA8)
		placeholder.fill(Color(1, 1, 1, 1))
		return ImageTexture.create_from_image(placeholder)
	if is_tearing_down:
		return null
	image_url = _normalize_image_url(image_url)
	_register_requested_index(image_url, image_index)
	if image_atlas_details:
		var normalized_image_atlas = image_atlas_details.duplicate(true)
		normalized_image_atlas['url'] = image_url
		if image_url in image_load_atlas_map:
			image_load_atlas_map[image_url] = merge_image_atlas_details(image_load_atlas_map[image_url], normalized_image_atlas)
		else:
			image_load_atlas_map[image_url] = normalized_image_atlas

	while image_url not in loaded_images:
		if is_tearing_down:
			return null
		if image_url not in image_load_queue:
			image_load_queue.append(image_url)
			if image_url not in image_load_atlas_map:
				image_load_atlas_map[image_url] = {
					"url": image_url,
					"multiple_cards": false
				}
		await image_queue_advanced
		if is_tearing_down:
			return null

	var image_set = loaded_images[image_url]
	if image_set:
		return image_set[image_index]
	else:
		return null

func get_animation_images(
		image_url,
		sprite_offset_x,
		sprite_offset_y,
		sprite_region_width,
		sprite_region_height,
		sprite_count_width,
		sprite_count_height):
	if test_mode:
		return []
	if is_tearing_down:
		return []
	image_url = _normalize_image_url(image_url)
	_register_requested_index(image_url, -1)

	while image_url not in loaded_images:
		if is_tearing_down:
			return []
		if image_url not in image_load_queue:
			image_load_queue.append(image_url)
			image_load_atlas_map[image_url] = {
				"url": image_url,
				"multiple_cards": true,
				"recalculate_card_sizes": true,
				"sprite_offset_x": sprite_offset_x,
				"sprite_offset_y": sprite_offset_y,
				"sprite_region_width": sprite_region_width,
				"sprite_region_height": sprite_region_height,
				"sprite_count_width": sprite_count_width,
				"sprite_count_height": sprite_count_height
			}
		await image_queue_advanced
		if is_tearing_down:
			return []

	return loaded_images[image_url]
