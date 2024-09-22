extends Node

const image_cache_dir = "user://exceedcache/"
const image_cache_map_file = "user://exceedcache_dir.json"

const characters = "abcdefghijklmnopqrstuvwxyz1234567890-"
const random_filename_length = 10

var image_cache_map = {}
var rng = RandomNumberGenerator.new()

func load_image_cache() -> bool:  # returns success code
	if not DirAccess.dir_exists_absolute(image_cache_dir):
		DirAccess.make_dir_absolute(image_cache_dir)

	if not FileAccess.file_exists(image_cache_map_file):
		print("Unable to find image cache map file.")
		return false # Image cache dictionary not found

	var file = FileAccess.open(image_cache_map_file, FileAccess.READ)
	var text = file.get_as_text()
	var json = JSON.parse_string(text)
	print("Image cache map json: %s" % text)
	image_cache_map.merge(json)
	return true

func cache_image(url : String, new_image : Image):
	var filename = _generate_image_filename()
	new_image.save_png(filename)
	image_cache_map[url] = filename

	var file = FileAccess.open(image_cache_map_file, FileAccess.WRITE)
	file.store_line(JSON.stringify(image_cache_map))

func load_image(url : String):
	if url not in image_cache_map:
		return null
	return Image.load_from_file(image_cache_map[url])

func _generate_image_filename():
	var random_filename = ""
	for i in range(random_filename_length):
		random_filename += characters[rng.randi_range(0, len(characters)-1)]
	return image_cache_dir + str(len(image_cache_map)) + "_" + random_filename + ".png"
