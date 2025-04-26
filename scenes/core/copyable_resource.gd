## A data structure for AI manipulation. Behaves mostly like a named tuple (qv.
## Python), in that it's like a dictionary with extra steps.
##
## This mainly exists so that there's specific support for object duplication
## and value-based equality checking. By default, Godot objects cannot be
## duplicated (and Resources only support duplication for objects whose _init
## contains no required arguments), and always check equality by reference only.
##
## A class that extends CopyableResource should implement:
##
##   * _init
##     * Takes zero required arguments.
##     * If all arguments have their default value, the resulting object should
##       be as close to a blank slate as possible; for example, if there are
##       _init behaviors that perform a sync-to-original, these should *not*
##       happen if all values are default.
##   * copy
##     * This is probably just a call to copy_impl but also passes in the
##       identity of the subclass.

class_name CopyableResource
extends Resource

# CopyableResources usually reflect data coming from a particular source. We
# retain a reference to that source since we'll sometimes want to sync our
# values to it. Copies of an CopyableResource instead point to the original.
var original

const IGNORE_PROPERTIES = {  # Don't duplicate these properties in copy()
	# Godot built-ins
	'RefCounted': 1, 'script': 1, 'Built-in script': 1, 'Resource': 1,
	'resource_name': 1, 'resource_path': 1, 'resource_local_to_scene': 1,
	}

func copy_impl(klass, deep: bool = true):
	var new_resource = klass.new()
	for property in self.get_property_list():
		var name = property['name']
		if name in IGNORE_PROPERTIES:
			continue
		if name == 'original':
			new_resource.original = self
			continue

		var value = self.get(name)
		# We have to check value type directly instead of using property['type']
		# because get_property_list() also uses 'type': Variant.Type.TYPE_NIL to
		# indicate a property with an *unspecified* type.
		var type = typeof(value)

		# While Godot supports .duplicate() for arrays and dictionaries, if any
		# of the collection contents are objects we have to handle the recursion
		# ourselves.
		if deep and type == Variant.Type.TYPE_ARRAY:
			new_resource.set(name, CopyableResource.deep_copy_array(value))
		elif deep and type == Variant.Type.TYPE_DICTIONARY:
			new_resource.set(name, CopyableResource.deep_copy_dictionary(value))
		elif deep and type == Variant.Type.TYPE_OBJECT and value.has_method('copy'):
			new_resource.set(name, value.copy(true))
		else:
			new_resource.set(name, value)
	return new_resource


func true_original():
	if original is CopyableResource:
		if original.original == null:
			return original
		else:
			return original.true_original()
	return original


static func deep_copy_array(x: Array):
	# We do a shallow duplicate first, then iterate element by element and do
	# our own version of deep copy where appropriate. (If we just do the deep
	# copy from the very beginning, we'll get Godot's built-in Object-phobic
	# duplicate instead of recursing into this function.)
	var new_array = x.duplicate()
	for i in range(new_array.size()):
		match typeof(new_array[i]):
			Variant.Type.TYPE_ARRAY:
				new_array[i] = deep_copy_array(new_array[i])
			Variant.Type.TYPE_DICTIONARY:
				new_array[i] = deep_copy_dictionary(new_array[i])
			Variant.Type.TYPE_OBJECT:
				if new_array[i].has_method('copy'):
					new_array[i] = new_array[i].copy(true)
				# Otherwise the shallow copy is good as it is.
			# No default case; we just leave the shallow copy be.
	return new_array


static func deep_copy_dictionary(x: Dictionary):
	# We do a deep copy of dictionary *values*, but not of dictionary *keys*,
	# since the duplicated dictionary must still respond correctly to a lookup
	# of any original objects used by keys, and we have to respect Godot's
	# opinion of equality there.
	var new_dict = x.duplicate()
	for key in new_dict:
		match typeof(new_dict[key]):
			Variant.Type.TYPE_ARRAY:
				new_dict[key] = deep_copy_array(new_dict[key])
			Variant.Type.TYPE_DICTIONARY:
				new_dict[key] = deep_copy_dictionary(new_dict[key])
			Variant.Type.TYPE_OBJECT:
				if new_dict[key].has_method('copy'):
					new_dict[key] = new_dict[key].copy(true)
				# Otherwise the shallow copy is good as it is.
			# No default case; we just leave the shallow copy be.
	return new_dict


# Do value-based comparison for two things. Basically a way to get around
# the fact that Godot only natively supports reference equality for objects.
# We don't expect to call this often except for testing purposes.
static func equals(a: Variant, b: Variant):
	if typeof(a) != typeof(b):
		return false

	match typeof(a):
		# While Godot already does recursive value comparison for arrays
		# and dictionaries, if any of the collection contents are
		# objects we have to handle the recursion ourselves.
		Variant.Type.TYPE_ARRAY:
			if a.size() != b.size():
				return false
			for i in range(a.size()):
				if not CopyableResource.equals(a[i], b[i]):
					return false
			return true
		Variant.Type.TYPE_DICTIONARY:
			var a_keys = a.keys()
			var b_keys = b.keys()
			a_keys.sort()
			b_keys.sort()
			if not CopyableResource.equals(a_keys, b_keys):
				return false
			for key in a_keys:
				if not CopyableResource.equals(a[key], b[key]):
					return false
			return true
		# For generic objects, we'll only do recursion for CopyableResource,
		# i.e. objects that mostly behave like Python named tuples. There are
		# just as many objects that we definitely don't want to compare in
		# linear time; for example, LocalGame.
		Variant.Type.TYPE_OBJECT:
			if not (a is CopyableResource and b is CopyableResource):
				return a == b
			var a_properties = a.get_property_list()
			var b_properties = b.get_property_list()
			a_properties.sort_custom(func(x, y): return x['name'] < y['name'])
			b_properties.sort_custom(func(x, y): return x['name'] < y['name'])
			if a_properties != b_properties:
				# At least we can rely on these to just be Array[Dictionary[String -> Primitive]]
				return false
			for property in a_properties:
				var name = property['name']
				if name in IGNORE_PROPERTIES or name == 'original':
					continue
				if not CopyableResource.equals(a.get(name), b.get(name)):
					return false
			return true
		Variant.Type.TYPE_FLOAT:
			# There are also a bunch of vector-like built-ins that use their own
			# built-in .is_equal_approx(), but unfortunately
			# @Global.is_equal_approx() doesn't support them as inputs, and
			# there's no quick way to check for them other than listing them all
			# out (i.e. you can't do maybe_vector.has_method('is_equal_approx')
			# because they don't have .has_method; and you can't just try it and
			# see because this language doesn't have error handling). So we're
			# just going to hope that this is enough. If it isn't, either add an
			# appropriate branch to this match statement, or use an Array
			# instead of a vector-like.
			return is_equal_approx(a, b)
		_:
			return a == b
