# pull_to_buddy

**Category**: Movement
**Description**: Pull the opponent to buddy location. Forces the opponent to move to the space where a buddy is located.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic buddy pull:**
```json
{
  "timing": "hit",
  "effect_type": "pull_to_buddy"
}
```

**Pre-strike positioning:**
```json
{
  "timing": "before",
  "effect_type": "pull_to_buddy"
}
```

**Post-strike setup:**
```json
{
  "timing": "after",
  "effect_type": "pull_to_buddy"
}
```

## Implementation Notes

- Requires at least one buddy to be placed on the arena
- If multiple buddies exist, typically uses the closest or most recently placed
- Opponent is pulled to the exact space occupied by the buddy
- If opponent is already at buddy location, no movement occurs
- Movement amount can be modified by opponent's movement effect modifiers
- Does not remove or affect the buddy itself
- Creates pull log message with buddy reference

## Related Effects

- [pull](pull.md) - Pull opponent by specific amount
- [pull_to_range](pull_to_range.md) - Pull opponent to specific range
- [move_to_buddy](move_to_buddy.md) - Move yourself to buddy location
- [place_buddy_onto_opponent](../buddy/place_buddy_onto_opponent.md) - Place buddy on opponent

## Real Usage Examples

From card definitions:
- Carl Clover's "Nirvana" mechanics: Pull to doll location
- Eddie puppet mechanics: Pull to shadow position
- Various puppet fighter abilities
- Setup and trap-based characters using buddy positioning