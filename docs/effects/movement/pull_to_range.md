# pull_to_range

**Category**: Movement
**Description**: Pull the opponent to a specific range. Forces the opponent to move to the exact specified range distance.

## Parameters

- `amount` (required): Target range to pull opponent to
  - **Type**: Integer
  - **Range**: 1-9 (valid arena ranges)

## Supported Timings

- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Pull to close range:**
```json
{
  "timing": "hit",
  "effect_type": "pull_to_range",
  "amount": 1
}
```

**Pull to medium range:**
```json
{
  "timing": "before",
  "effect_type": "pull_to_range",
  "amount": 3
}
```

**Pull to far range:**
```json
{
  "timing": "after",
  "effect_type": "pull_to_range",
  "amount": 6
}
```

## Implementation Notes

- Forces opponent to exact range, not just closer
- If opponent is already at target range, no movement occurs
- If opponent is closer than target range, they are pushed away instead
- Movement amount can be modified by opponent's movement effect modifiers
- Creates appropriate pull or push log messages based on direction
- Does not trigger opponent's movement-related character effects

## Related Effects

- [pull](pull.md) - Pull opponent by specific amount
- [push_to_range](push_to_range.md) - Push opponent to specific range
- [move_to_space](move_to_space.md) - Move yourself to specific space
- [pull_to_buddy](pull_to_buddy.md) - Pull opponent to buddy location

## Real Usage Examples

From card definitions:
- Tager's "Atomic Collider": Pull to optimal grappling range
- Waldstein's command grabs: Pull to range 1 for throws
- Potemkin's "Giganter Kai": Pull to specific range for follow-ups
- Various grappler effects that need exact positioning