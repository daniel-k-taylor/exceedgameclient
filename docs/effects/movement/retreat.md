# retreat

**Category**: Movement
**Description**: Move away from the opponent by a specified amount. Character moves backward, increasing distance.

## Parameters

- `amount` (required): Number of spaces to retreat
  - **Type**: Integer
  - **Range**: Any positive integer
- `and` (optional): Chained effect that executes after retreating
  - **Type**: Effect object

## Supported Timings

- `before` - Before strike resolution
- `after` - After strike resolution

## Examples

**Basic retreat:**
```json
{
  "timing": "before",
  "effect_type": "retreat",
  "amount": 1
}
```

**Retreat with chained effect:**
```json
{
  "timing": "after",
  "effect_type": "retreat",
  "amount": 2,
  "and": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

**Large retreat:**
```json
{
  "timing": "before",
  "effect_type": "retreat",
  "amount": 3
}
```

## Implementation Notes

- Triggers character effects at timing "on_retreat"
- Movement amount can be modified by `strike_stat_boosts.increase_movement_effects_by`
- May not be able to retreat the full amount due to arena boundaries (space 1 minimum)
- Sets `local_conditions.movement_amount` to actual spaces moved
- Character cannot retreat past space 1

## Related Effects

- [advance](advance.md) - Move forward
- [close](close.md) - Move toward opponent
- [push](push.md) - Push opponent away
- [move_to_space](move_to_space.md) - Move to specific space

## Real Usage Examples

From card definitions:
- Millia's "Bad Moon": `{ "timing": "after", "effect_type": "retreat", "amount": 1 }`
- Chipp's "Alpha Blade": Retreat with draw effect
- Leo's "Zweites Kaltes Gestöber": Retreat for positioning
- Various defensive maneuvers across multiple characters