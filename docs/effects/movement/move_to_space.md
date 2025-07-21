# move_to_space

**Category**: Movement
**Description**: Move to a specific space on the arena. Character moves to the exact specified space number.

## Parameters

- `amount` (required): Target space to move to
  - **Type**: Integer
  - **Range**: 1-9 (valid arena spaces)

## Supported Timings

- `before` - Before strike resolution
- `after` - After strike resolution

## Examples

**Move to close space:**
```json
{
  "timing": "before",
  "effect_type": "move_to_space",
  "amount": 3
}
```

**Move to center:**
```json
{
  "timing": "after",
  "effect_type": "move_to_space",
  "amount": 5
}
```

**Move to far space:**
```json
{
  "timing": "before",
  "effect_type": "move_to_space",
  "amount": 8
}
```

## Implementation Notes

- Character moves to exact space regardless of current position
- If already at target space, no movement occurs
- Movement amount can be modified by `strike_stat_boosts.increase_movement_effects_by`
- May trigger "advanced_through" conditions if passing opponent
- Triggers character effects at timing "on_advance_or_close" or "on_retreat" depending on direction
- Cannot move to space occupied by opponent

## Related Effects

- [move_to_any_space](move_to_any_space.md) - Choose any space to move to
- [move_to_buddy](move_to_buddy.md) - Move to buddy location
- [advance](advance.md) - Move forward by amount
- [retreat](retreat.md) - Move backward by amount

## Real Usage Examples

From card definitions:
- Nu-13's "Gravity Seed": Teleport to specific positioning
- Chaos's "I-No Drive": Move to optimal space for follow-ups
- Various teleport and positioning abilities
- Stage control and setup moves