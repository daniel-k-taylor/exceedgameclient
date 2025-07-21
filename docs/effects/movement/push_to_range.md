# push_to_range

**Category**: Movement
**Description**: Push the opponent to a specific range. Forces the opponent to move to the exact specified range distance.

## Parameters

- `amount` (required): Target range to push opponent to
  - **Type**: Integer
  - **Range**: 1-9 (valid arena ranges)

## Supported Timings

- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Push to medium range:**
```json
{
  "timing": "hit",
  "effect_type": "push_to_range",
  "amount": 4
}
```

**Push to far range:**
```json
{
  "timing": "hit",
  "effect_type": "push_to_range",
  "amount": 7
}
```

**Push after strike:**
```json
{
  "timing": "after",
  "effect_type": "push_to_range",
  "amount": 5
}
```

## Implementation Notes

- Forces opponent to exact range, not just further away
- If opponent is already at target range, no movement occurs
- If opponent is further than target range, they are pulled closer instead
- Movement amount can be modified by opponent's movement effect modifiers
- Creates appropriate push or pull log messages based on direction
- Does not trigger opponent's movement-related character effects
- Often used for spacing control and zoning

## Related Effects

- [push](push.md) - Push opponent by specific amount
- [pull_to_range](pull_to_range.md) - Pull opponent to specific range
- [push_to_attack_max_range](push_to_attack_max_range.md) - Push to attack's max range
- [move_to_space](move_to_space.md) - Move yourself to specific space

## Real Usage Examples

From card definitions:
- Axl's "Rensen": Push to optimal zoning range
- Dhalsim-style characters: Push to long range for keepaway
- May's "Great Yamada Attack": Push for spacing control
- Various projectile attacks that control positioning