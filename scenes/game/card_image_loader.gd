class_name CardImageLoader
extends Node2D

var loaded_images = {}
var image_load_queue = []
var image_load_atlas_map = {}
var processing_queue = false
var test_mode : bool = false
var http_request : HTTPRequest

signal finished_loading_image(image)
signal image_queue_advanced

const CARD_WIDTH = 750.0
const CARD_HEIGHT = 1024.0

func _init(testing_mode = false):
	test_mode = testing_mode
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(self._image_request_completed)

func _process(_delta):
	if not processing_queue and len(image_load_queue) > 0:
		_process_request_queue()

# Loads card images if they haven't yet been accessed
func load_image_page(image_atlas):
	if test_mode:
		return

	var image_url = image_atlas['url']

	if image_url not in loaded_images and image_url not in image_load_queue:
		image_load_queue.append(image_url)
		image_load_atlas_map[image_url] = image_atlas

func _process_request_queue():
	processing_queue = true
	var image_url = image_load_queue[0]
	var is_multiple = image_load_atlas_map[image_url]['multiple_cards']

	var loaded_image = ImageCache.load_image(image_url)
	if not loaded_image: # not found in cache; send http request
		var error = http_request.request(image_url)

		if error != OK:
			push_error("Error loading card image: " + image_url)
		loaded_image = await finished_loading_image
		if loaded_image:
			ImageCache.cache_image(image_url, loaded_image)

	if loaded_image:
		var image_texture = ImageTexture.create_from_image(loaded_image)
		if is_multiple:
			var grid_width = image_texture.get_width() / CARD_WIDTH
			var grid_height = image_texture.get_height() / CARD_HEIGHT
			var image_grid = []
			for y in range(grid_height):
				for x in range(grid_width):
					var atlas_texture = AtlasTexture.new()
					atlas_texture.atlas = image_texture
					atlas_texture.region = Rect2(x * CARD_WIDTH, y * CARD_HEIGHT, CARD_WIDTH, CARD_HEIGHT)
					image_grid.append(atlas_texture)
			loaded_images[image_url] = image_grid
		else:
			loaded_images[image_url] = [image_texture]
	else:
		loaded_images[image_url] = null
	image_load_queue.pop_at(0)
	processing_queue = false
	image_queue_advanced.emit()

func _image_request_completed(_result, _response_code, headers, body):
	var image_type = "jpg"
	for header in headers:
		if header.begins_with("Content-Type"):
			# The header should look something like "Content-Type: image/png"
			if header.split("/")[-1] == "png":
				image_type = "png"
				break
	var image = Image.new()
	var load_success = false

	if image_type == "png":
		var error = image.load_png_from_buffer(body)
		if error == OK:
			load_success = true
	else:
		var error = image.load_jpg_from_buffer(body)
		if error == OK:
			load_success = true

	if load_success:
		finished_loading_image.emit(image)
	else:
		push_error("Error loading card image")
		finished_loading_image.emit(null)

func get_card_image(image_url, image_index):
	if test_mode:
		return ImageTexture.create_from_image(Image.new())

	while image_url not in loaded_images:
		if image_url not in image_load_queue:
			image_load_queue.append(image_url)
			image_load_atlas_map[image_url] = {
				"url": image_url,
				"multiple_cards": false
			}
		await image_queue_advanced

	var image_set = loaded_images[image_url]
	if image_set:
		return image_set[image_index]
	else:
		return null
