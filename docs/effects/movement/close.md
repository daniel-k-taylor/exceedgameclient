# close

**Category**: Movement
**Description**: Move toward the opponent by a specified amount. Characters move closer together by reducing the distance between them.

## Parameters

- `amount` (required): Number of spaces to close
  - **Type**: Integer
  - **Range**: Any positive integer
- `save_spaces_as_strike_x` (optional): Save the number of spaces actually closed as strike X
  - **Type**: Boolean
  - **Default**: false
- `save_spaces_not_closed_as_strike_x` (optional): Save the number of spaces not closed as strike X
  - **Type**: Boolean
  - **Default**: false
- `and` (optional): Chained effect that executes after closing
  - **Type**: Effect object

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `after` - After strike resolution

## Examples

**Basic close:**
```json
{
  "timing": "before",
  "effect_type": "close",
  "amount": 1
}
```

**Close with strike X tracking:**
```json
{
  "timing": "hit",
  "effect_type": "close",
  "amount": 3,
  "save_spaces_as_strike_x": true
}
```

**Close with chained effect:**
```json
{
  "timing": "before",
  "effect_type": "close",
  "amount": 2,
  "and": {
    "effect_type": "strike"
  }
}
```

**Track spaces not closed:**
```json
{
  "timing": "after",
  "effect_type": "close",
  "amount": 4,
  "save_spaces_not_closed_as_strike_x": true
}
```

## Implementation Notes

- Triggers character effects at timing "on_advance_or_close"
- Movement amount can be modified by `strike_stat_boosts.increase_movement_effects_by`
- May not be able to close the full amount due to arena boundaries or opponent position
- The difference between requested amount and actual movement can be tracked
- Sets `local_conditions.fully_closed` if the full amount was achieved
- Sets `local_conditions.movement_amount` to actual spaces moved

## Related Effects

- [advance](advance.md) - Move forward
- [retreat](retreat.md) - Move away from opponent
- [pull](pull.md) - Pull opponent toward you
- [close_damagetaken](close_damagetaken.md) - Close based on damage taken

## Real Usage Examples

From card definitions:
- Zangief's "Green Hand": `{ "timing": "before", "effect_type": "close", "amount": 2 }`
- Potemkin's "Garuda Impact": Close with strike tracking
- Waldstein's "Verfolgung": Close then strike patterns
- Tager's "Magnetic Coil": Close with conditional effects