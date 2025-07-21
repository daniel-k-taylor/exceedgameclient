# push_or_pull_to_space

**Category**: Movement
**Description**: Push or pull the opponent to a specific arena space, automatically choosing the appropriate direction.

## Parameters

- `amount` (required): Target arena space to move opponent to
  - **Type**: Integer
  - **Range**: 1-9 (valid arena spaces)

## Supported Timings

- `hit` - When attack hits
- `during_strike` - During strike resolution

## Examples

**Push or pull to space 5:**
```json
{
  "timing": "hit",
  "effect_type": "push_or_pull_to_space",
  "amount": 5
}
```

**Target specific space:**
```json
{
  "effect_type": "push_or_pull_to_space",
  "amount": 2
}
```

## Implementation Notes

- Automatically determines whether to push or pull based on opponent's current position
- If opponent is closer to performing character than target space, pushes opponent away
- If opponent is farther from performing character than target space, pulls opponent closer
- Calculates the shortest path to move opponent to the target space
- Cannot move opponent to a space occupied by the performing character
- Creates appropriate log messages indicating whether opponent was pushed or pulled

## Related Effects

- [push_or_pull_to_any_space](push_or_pull_to_any_space.md) - Choose target space dynamically
- [move_to_space](move_to_space.md) - Move self to specific space
- [push](push.md) - Basic push movement
- [pull](pull.md) - Basic pull movement

## Real Usage Examples

From card definitions:
- Used internally by push_or_pull_to_any_space effect
- Precise positioning control for tactical advantages
- Combines push and pull logic into single flexible effect