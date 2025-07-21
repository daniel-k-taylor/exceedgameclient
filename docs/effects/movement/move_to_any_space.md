# move_to_any_space

**Category**: Movement
**Description**: Choose any space to move to. Player selects from all valid arena spaces.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `before` - Before strike resolution
- `after` - After strike resolution

## Examples

**Basic free movement:**
```json
{
  "timing": "before",
  "effect_type": "move_to_any_space"
}
```

**Post-strike repositioning:**
```json
{
  "timing": "after",
  "effect_type": "move_to_any_space"
}
```

## Implementation Notes

- Creates a decision state where player chooses target space
- Player can select any valid arena space (1-9)
- Cannot move to space occupied by opponent
- Movement triggers appropriate character effects based on direction
- If already in optimal position, player can choose current space (no movement)
- Movement amount modifiers still apply to distance traveled

## Related Effects

- [move_to_space](move_to_space.md) - Move to specific space
- [move_to_buddy](move_to_buddy.md) - Move to buddy location
- [choice](../choice/choice.md) - General choice mechanics
- [advance](advance.md) - Move forward by amount

## Real Usage Examples

From card definitions:
- Chaos's "Focus": Ultimate positioning freedom
- I-No's teleport effects: Choose optimal positioning
- Various mobility ultimates and exceed effects
- High-cost movement abilities with maximum flexibility