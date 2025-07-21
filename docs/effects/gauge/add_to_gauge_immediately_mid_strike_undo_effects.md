# add_to_gauge_immediately_mid_strike_undo_effects

**Category**: Gauge
**Description**: Immediately add the specified boost card to gauge with mid-strike undo capability.

## Parameters

None - this effect immediately moves the boost card to gauge with undo support.

## Supported Timings

- `during_strike` - During strike resolution
- `hit` - When attack hits
- `after` - After strike resolution
- `immediate` - Immediately when triggered

## Examples

**Basic usage:**
```json
{
  "timing": "during_strike",
  "effect_type": "add_to_gauge_immediately_mid_strike_undo_effects"
}
```

**On hit effect:**
```json
{
  "timing": "hit",
  "effect_type": "add_to_gauge_immediately_mid_strike_undo_effects",
  "and": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

**Combined with other effects:**
```json
{
  "timing": "immediate",
  "effect_type": "add_to_gauge_immediately_mid_strike_undo_effects",
  "and": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

## Implementation Notes

- Requires a boost card context (card_id must be provided)
- Immediately removes the boost card from continuous boosts and adds it to gauge
- Creates appropriate log message showing which card was moved
- This version supports mid-strike undo effects, allowing the move to be reversed if needed
- Used in situations where the gauge addition might need to be undone during strike resolution
- Cannot be used without a valid boost card context
- The boost effect stops immediately when moved to gauge
- Functionally similar to [`add_to_gauge_immediately`](add_to_gauge_immediately.md) but with undo support

## Related Effects

- [add_to_gauge_immediately](add_to_gauge_immediately.md) - Same effect without undo capability
- [add_to_gauge_boost_play_cleanup](add_to_gauge_boost_play_cleanup.md) - Delayed gauge addition during cleanup
- [add_boost_to_gauge_on_strike_cleanup](add_boost_to_gauge_on_strike_cleanup.md) - Move boost to gauge on strike cleanup

## Real Usage Examples

From card definitions:
- Complex strike effects that need undo capability for boost management
- Conditional boost conversions that might be reversed based on strike outcome
- Advanced boost strategies requiring fine-grained control over timing