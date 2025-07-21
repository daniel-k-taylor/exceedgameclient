# add_boost_to_gauge_on_strike_cleanup

**Category**: Gauge
**Description**: Add the specified boost card to gauge, either immediately or during strike cleanup.

## Parameters

- `not_immediate` (optional): If true, boost goes to gauge during strike cleanup instead of immediately
  - **Type**: Boolean
  - **Default**: false (immediate)
  - **Note**: Affects timing of when boost is moved to gauge

## Supported Timings

- `during_strike` - During strike resolution
- `hit` - When attack hits
- `after` - After strike resolution
- `immediate` - Immediately when triggered

## Examples

**Immediate boost to gauge:**
```json
{
  "timing": "hit",
  "effect_type": "add_boost_to_gauge_on_strike_cleanup"
}
```

**Delayed boost to gauge:**
```json
{
  "timing": "during_strike",
  "effect_type": "add_boost_to_gauge_on_strike_cleanup",
  "not_immediate": true
}
```

**On successful hit:**
```json
{
  "timing": "hit",
  "effect_type": "add_boost_to_gauge_on_strike_cleanup",
  "and": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

## Implementation Notes

- Requires a boost card context (card_id must be provided)
- If `not_immediate` is false or not specified, boost is moved to gauge immediately
- If `not_immediate` is true, boost is scheduled to move to gauge during strike cleanup
- Creates appropriate log message indicating when boost will be moved
- The boost card is removed from continuous boosts and added to gauge
- Useful for converting temporary boost effects into permanent gauge resources
- Cannot be used without a valid boost card context

## Related Effects

- [add_boost_to_gauge_on_move](add_boost_to_gauge_on_move.md) - Move boost to gauge when moving
- [add_boost_to_overdrive_during_strike_immediately](add_boost_to_overdrive_during_strike_immediately.md) - Similar for overdrive
- [add_to_gauge_boost_play_cleanup](add_to_gauge_boost_play_cleanup.md) - Move boost to gauge after boost play

## Real Usage Examples

From card definitions:
- Boost cards that convert themselves to gauge after providing their effect
- Hit effects that reward successful attacks by building gauge
- Strategic boost management that turns temporary effects into lasting resources