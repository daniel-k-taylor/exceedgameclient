extends GutTest

# force_for_effect / gauge_for_effect decisions are read by the UI with plain
# key access (e.g. effect['overall_effect']), so an effect that omits a key
# raises a runtime error the moment the decision is shown. Engine tests never
# catch this because they drive the decision directly and never build the UI.
#
# These checks scan every card and deck definition so a newly authored effect
# has to declare both halves explicitly, even when one of them is null.

const REQUIRED_KEYS := {
	"force_for_effect": ["per_force_effect", "overall_effect"],
	"gauge_for_effect": ["per_gauge_effect", "overall_effect"],
}

func _collect_effects(data, source : String, found : Array) -> void:
	if data is Dictionary:
		var effect_type = data.get("effect_type", "")
		if effect_type in REQUIRED_KEYS:
			found.append({ "source": source, "effect": data })
		for key in data:
			_collect_effects(data[key], source, found)
	elif data is Array:
		for entry in data:
			_collect_effects(entry, source, found)

func _all_effects() -> Array:
	var found = []
	for card_id in CardDataManager.card_data:
		var card_definition = CardDataManager.card_data[card_id]
		_collect_effects(card_definition, "card '%s'" % card_id, found)
	for deck_id in CardDataManager.decks:
		_collect_effects(CardDataManager.decks[deck_id], "deck '%s'" % deck_id, found)
	return found

func test_scan_actually_finds_the_effects_it_validates():
	# Guards against the checks below passing vacuously if the traversal breaks.
	var found = _all_effects()
	assert_gt(found.size(), 100, "Expected to scan many force/gauge_for_effect definitions.")
	var sources = []
	for entry in found:
		sources.append(entry["source"])
	assert_true(sources.has("card 'minato_cabstand'"), "Expected to scan minato_cabstand.")

func test_force_and_gauge_for_effect_declare_both_effect_keys():
	var problems = []
	for entry in _all_effects():
		var effect = entry["effect"]
		for required_key in REQUIRED_KEYS[effect["effect_type"]]:
			if not (required_key in effect):
				problems.append("%s: %s is missing '%s' (use null if unused)" % [
					entry["source"], effect["effect_type"], required_key])
	assert_eq(problems.size(), 0,
		"Effects must declare both keys so the UI can read them:\n" + "\n".join(problems))

func test_force_for_effect_does_not_define_both_per_force_and_overall():
	# do_force_for_effect applies the per-force effect OR the overall effect,
	# never both, so authoring both silently drops the overall one.
	var problems = []
	for entry in _all_effects():
		var effect = entry["effect"]
		if effect["effect_type"] != "force_for_effect":
			continue
		if effect.get("per_force_effect") != null and effect.get("overall_effect") != null:
			problems.append("%s defines both per_force_effect and overall_effect" % entry["source"])
	assert_eq(problems.size(), 0,
		"force_for_effect supports only one of the two:\n" + "\n".join(problems))
