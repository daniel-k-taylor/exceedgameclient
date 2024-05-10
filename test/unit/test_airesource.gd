extends GutTest

class TestResource extends AIResource:
	var scalar
	var list
	var json
	
	func _init(the_source):
		self.source = the_source
		self.scalar = randi_range(1, 1000000)
		self.list = ["string", randi_range(1, 1000000), Resource.new()]
		self.json = {
				'name': 'json',
				17: Resource.new(),
				'nested_list': [{ 'more': ['json'], 'and': TestSubresource.new(self) }, 'lmao'],
			}

	func copy(deep: bool = true):
		return self.copy_impl(TestResource, deep)

class TestSubresource extends AIResource:
	var data

	func _init(the_source):
		self.source = the_source
		self.data = randi_range(1, 1000000)

	func copy(deep: bool = true):
		return self.copy_impl(TestSubresource, deep)


func test_original_equals_copy():
	var source = Node.new()
	var original = TestResource.new(source)
	var copy = original.copy()

	assert_not_same(original, copy, 'Copy is just a reference to the original')
	assert_same(original.source, copy.source, 'Source was duplicated when it should not have been')
	assert_eq(original.scalar, copy.scalar, 'Scalar %s incorrectly copied' % original.scalar)
	assert_eq(original.list, copy.list, 'List %s incorrectly copied' % [original.list])
	assert_same(original.list[2], copy.list[2], 'Generic object was not copied by reference')
	assert_not_same(original.json, copy.json, 'Dictionary copied by reference')

	var json_diff = compare_deep(original.json, copy.json)
	# A deep Godot-native comparison should detect one difference, which is the
	# nested TestSubresource that will get cloned by copy(). The Resource should
	# be copied by reference.
	assert_eq(json_diff.differences.size(), 1)
	assert_has(json_diff.differences, 'nested_list')
	assert_has(json_diff.differences['nested_list'].differences, 0)
	assert_has(json_diff.differences['nested_list'].differences[0].differences, 'and')
	assert_same(original.json[17], copy.json[17])
	assert_not_same(original.json['nested_list'][0]['and'], copy.json['nested_list'][0]['and'])
	assert_true(AIResource.equals(original.json['nested_list'][0]['and'], copy.json['nested_list'][0]['and']))
	assert_true(AIResource.equals(original.json, copy.json))
	
	assert_true(AIResource.equals(original, copy), 'Bespoke equality check failed')
	source.free()


func test_original_not_equals_modified_copy():
	var source = Node.new()
	var original = TestResource.new(source)
	var copy = original.copy()

	copy.scalar -= 1
	copy.list.append('more datums')
	copy.json['nested_list'][0]['even'] = 'more'
	copy.json['nested_list'][0]['and'].data *= 2

	assert_ne(original.scalar, copy.scalar)
	assert_ne(original.list.size(), copy.list.size())
	assert_does_not_have(original.json['nested_list'][0], 'even')
	assert_ne(original.json['nested_list'][0]['and'], copy.json['nested_list'][0]['and'])
	source.free()
