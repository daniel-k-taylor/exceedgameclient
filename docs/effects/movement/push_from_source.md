# push_from_source

**Category**: Movement
**Description**: Push the opponent away from the attack source location by a specified amount.

## Parameters

- `amount` (required): Number of spaces to push the opponent away from the attack source
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `hit` - When attack hits
- `during_strike` - During strike resolution

## Examples

**Basic push from source:**
```json
{
  "timing": "hit",
  "effect_type": "push_from_source",
  "amount": 2
}
```

**Push from source on hit:**
```json
{
  "timing": "hit",
  "effect_type": "push_from_source",
  "amount": 1
}
```

## Implementation Notes

- Uses `get_attack_origin()` to determine the source location of the attack
- Pushes opponent away from that source location rather than away from the performing character
- Calculates direction based on opponent's position relative to the attack source
- If opponent is at the same location as the attack source, uses default push direction
- Useful for attacks that originate from projectiles, buddies, or other sources
- Respects arena boundaries and cannot move opponent to occupied spaces
- Creates appropriate log messages showing movement from the attack source

## Related Effects

- [push](push.md) - Basic push away from performing character
- [pull_from_source](pull_from_source.md) - Pull toward attack source
- [push_to_range](push_to_range.md) - Push to optimal attack range
- [push_to_attack_max_range](push_to_attack_max_range.md) - Push to maximum attack range

## Real Usage Examples

From card definitions:
- Various character attacks: `{ "timing": "hit", "effect_type": "push_from_source", "amount": 2 }`
- Projectile-based attacks: Push opponent away from where projectile hit
- Buddy-initiated attacks: Push away from buddy that performed the attack
- Area effect attacks: Push from the center of the effect