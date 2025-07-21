# advance

**Category**: Movement
**Description**: Move the character forward by a specified amount.

## Parameters

- `amount` (required): Number of spaces to advance
  - **Type**: Integer or String
  - **Special Values**:
    - `"strike_x"` - Use the current strike's X value
    - Any integer value (1, 2, 3, etc.)
- `stop_on_buddy_space` (optional): Buddy index to stop on if reached
  - **Type**: Integer
- `and` (optional): Chained effect that executes after this one
  - **Type**: Effect object

## Supported Timings

- `before` - Before strike resolution
- `after` - After strike resolution
- `hit` - When attack hits

## Examples

**Basic advance:**
```json
{
  "timing": "before",
  "effect_type": "advance",
  "amount": 2
}
```

**Advance using strike X:**
```json
{
  "timing": "hit",
  "effect_type": "advance",
  "amount": "strike_x"
}
```

**Advance with chained effect:**
```json
{
  "timing": "before",
  "effect_type": "advance",
  "amount": 1,
  "and": {
    "effect_type": "strike"
  }
}
```

## Implementation Notes

- Triggers character effects at timing "on_advance_or_close"
- May trigger "advanced_through" conditions if passing opponent
- Movement amount can be modified by `strike_stat_boosts.increase_movement_effects_by`
- Stops at arena boundaries (spaces 1-9)

## Related Effects

- [close](close.md) - Move toward opponent
- [retreat](retreat.md) - Move away from opponent
- [move_to_space](move_to_space.md) - Move to specific space

## Real Usage Examples

From card definitions:
- Taokaka's "Vigilant Dash": `{ "timing": "before", "effect_type": "advance", "amount": 2 }`
- Merkava's "Wing Blade": Uses strike_x for advance amount
- Nu-13's "Gravity Seed": `{ "timing": "hit", "effect_type": "advance", "amount": 3 }`