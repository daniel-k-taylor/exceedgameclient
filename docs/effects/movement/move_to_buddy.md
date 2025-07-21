# move_to_buddy

**Category**: Movement
**Description**: Move to buddy location. Character moves to the space where a buddy is located.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `before` - Before strike resolution
- `after` - After strike resolution

## Examples

**Basic buddy teleport:**
```json
{
  "timing": "before",
  "effect_type": "move_to_buddy"
}
```

**Post-strike repositioning:**
```json
{
  "timing": "after",
  "effect_type": "move_to_buddy"
}
```

## Implementation Notes

- Requires at least one buddy to be placed on the arena
- If multiple buddies exist, typically uses the closest or most recently placed
- Character moves to the exact space occupied by the buddy
- If already at buddy location, no movement occurs
- Movement triggers appropriate character effects based on direction
- Does not remove or affect the buddy itself
- Can be used for teleport-like positioning mechanics

## Related Effects

- [pull_to_buddy](pull_to_buddy.md) - Pull opponent to buddy location
- [move_to_space](move_to_space.md) - Move to specific space
- [move_to_any_space](move_to_any_space.md) - Choose any space to move to
- [switch_spaces_with_buddy](../buddy/switch_spaces_with_buddy.md) - Swap positions with buddy

## Real Usage Examples

From card definitions:
- Carl Clover's "Via Dolorosa": Teleport to Nirvana's position
- Eddie shadow mechanics: Move to shadow location
- Various puppet and summon-based teleportation
- Setup characters using buddy positioning for mobility