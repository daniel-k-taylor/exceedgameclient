class_name ImageResizer
extends RefCounted

## Image resizing helper.
## Scales an image's width and height to the requested pixel size.

## Scale image to target_width x target_height pixels and return a new Image.
## The source image is not modified. Uses Lanczos interpolation, suitable for
## both upscaling and downscaling.
static func resize_to(image: Image, target_width: int, target_height: int) -> Image:
	var resized = image.duplicate()
	resized.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return resized

## Scale image in place to target_width x target_height pixels and return it.
## Use when mutating the source is acceptable; avoids allocating a full copy.
static func resize_in_place(image: Image, target_width: int, target_height: int) -> Image:
	if image.get_width() == target_width and image.get_height() == target_height:
		return image
	image.resize(target_width, target_height, Image.INTERPOLATE_LANCZOS)
	return image
