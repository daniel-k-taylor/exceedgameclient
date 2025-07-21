# add_boost_to_gauge_on_move

**Category**: Gauge
**Description**: Schedule the specified boost card to be added to gauge when the player moves.

## Parameters

None - this effect sets a flag for the specified boost card to move to gauge on next movement.

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
  "effect_type": "add_boost_to_gauge_on_move"
}
```

**Combined with movement:**
```json
{
  "timing": "after",
  "effect_type": "add_boost_to_gauge_on_move",
  "and": {
    "effect_type": "advance",
    "amount": 2
  }
}
```

**On successful attack:**
```json
{
  "timing": "hit",
  "effect_type": "add_boost_to_gauge_on_move",
  "and": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

## Implementation Notes

- Requires a boost card context (card_id must be provided)
- Sets a flag on the player to move the specified boost to gauge on next movement
- The boost remains active until movement occurs
- Once player moves, the boost is automatically moved to gauge
- Useful for boost cards that provide movement-based gauge generation
- Creates appropriate log messages when boost is scheduled and when moved
- Cannot be used without a valid boost card context

## Related Effects

- [add_boost_to_gauge_on_strike_cleanup](add_boost_to_gauge_on_strike_cleanup.md) - Move boost to gauge on strike cleanup
- [advance](../movement/advance.md) - Movement effect that can trigger this
- [close](../movement/close.md) - Another movement effect that can trigger this
- [add_to_gauge_immediately](add_to_gauge_immediately.md) - Immediate gauge addition

## Real Usage Examples

From card definitions:
- Boost cards that convert to gauge when repositioning
- Movement-based strategies that build gauge through positioning
- Tactical boosts that reward active movement with resource generation