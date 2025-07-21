# push

**Category**: Movement
**Description**: Push the opponent away from you by a specified amount. Forces the opponent to move further away.

## Parameters

- `amount` (required): Number of spaces to push the opponent
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic push:**
```json
{
  "timing": "hit",
  "effect_type": "push",
  "amount": 1
}
```

**Strong push:**
```json
{
  "timing": "hit",
  "effect_type": "push",
  "amount": 3
}
```

**Push after strike:**
```json
{
  "timing": "after",
  "effect_type": "push",
  "amount": 2
}
```

## Implementation Notes

- Forces opponent movement, unlike voluntary movement effects
- Movement amount can be modified by opponent's `strike_stat_boosts.increase_move_opponent_effects_by`
- Opponent may not be able to be pushed the full amount due to arena boundaries (space 9 maximum)
- Creates a "pushed" log message and visual effect
- Does not trigger opponent's movement-related character effects
- Can be blocked by certain defensive abilities
- Often used for spacing control and follow-up positioning

## Related Effects

- [pull](pull.md) - Pull opponent toward you
- [push_to_range](push_to_range.md) - Push to specific range
- [push_to_attack_max_range](push_to_attack_max_range.md) - Push to attack's maximum range
- [retreat](retreat.md) - Move away yourself

## Real Usage Examples

From card definitions:
- Gordeau's "Assimilation": `{ "timing": "hit", "effect_type": "push", "amount": 1 }`
- May's "Great Yamada Attack": Push for spacing
- Jin's "Ice Spike": Push after ice attacks
- Various projectile and blast effects across multiple characters