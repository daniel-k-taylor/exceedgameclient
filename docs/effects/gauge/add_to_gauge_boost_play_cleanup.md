# add_to_gauge_boost_play_cleanup

**Category**: Gauge
**Description**: Schedule the specified boost card to be added to gauge during boost play cleanup.

## Parameters

None - this effect schedules the boost card for cleanup to gauge.

## Supported Timings

- `during_strike` - During strike resolution
- `hit` - When attack hits
- `after` - After strike resolution
- `immediate` - Immediately when triggered

## Examples

**Basic usage:**
```json
{
  "timing": "hit",
  "effect_type": "add_to_gauge_boost_play_cleanup"
}
```

**On successful attack:**
```json
{
  "timing": "during_strike",
  "effect_type": "add_to_gauge_boost_play_cleanup",
  "and": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

**Combined with other effects:**
```json
{
  "timing": "after",
  "effect_type": "add_to_gauge_boost_play_cleanup",
  "and": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

## Implementation Notes

- Requires a boost card context (card_id must be provided)
- Adds the card ID to the active boost's cleanup_to_gauge_card_ids list
- The boost card will be moved to gauge when boost play cleanup occurs
- This is different from immediate gauge addition - it's deferred until cleanup
- Useful for boost cards that want to convert to gauge after their effect resolves
- Cannot be used without a valid boost card context
- The actual move to gauge happens during boost cleanup phase

## Related Effects

- [add_to_gauge_immediately](add_to_gauge_immediately.md) - Immediate gauge addition
- [add_boost_to_gauge_on_strike_cleanup](add_boost_to_gauge_on_strike_cleanup.md) - Move boost to gauge on strike cleanup
- [add_boost_to_gauge_on_move](add_boost_to_gauge_on_move.md) - Move boost to gauge on movement

## Real Usage Examples

From card definitions:
- Boost cards that provide temporary effects then convert to permanent gauge
- Strategic boost management for resource conversion
- Effects that reward boost usage with gauge building