# add_to_gauge_immediately

**Category**: Gauge
**Description**: Immediately add the specified boost card to gauge.

## Parameters

None - this effect immediately moves the boost card to gauge.

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
  "effect_type": "add_to_gauge_immediately"
}
```

**On successful attack:**
```json
{
  "timing": "during_strike",
  "effect_type": "add_to_gauge_immediately",
  "and": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

**Combined with other effects:**
```json
{
  "timing": "immediate",
  "effect_type": "add_to_gauge_immediately",
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
- This is immediate - no delay or cleanup phase required
- Useful for converting active boost effects into gauge resources right away
- Cannot be used without a valid boost card context
- The boost effect stops immediately when moved to gauge

## Related Effects

- [add_to_gauge_boost_play_cleanup](add_to_gauge_boost_play_cleanup.md) - Delayed gauge addition during cleanup
- [add_boost_to_gauge_on_strike_cleanup](add_boost_to_gauge_on_strike_cleanup.md) - Move boost to gauge on strike cleanup
- [add_to_gauge_immediately_mid_strike_undo_effects](add_to_gauge_immediately_mid_strike_undo_effects.md) - Similar with undo capability

## Real Usage Examples

From card definitions:
- Boost cards that sacrifice themselves for immediate gauge benefit
- Hit effects that reward successful attacks with instant gauge building
- Strategic boost conversion for immediate resource needs