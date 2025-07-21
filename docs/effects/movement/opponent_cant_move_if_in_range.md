# opponent_cant_move_if_in_range

**Category**: Movement
**Description**: Prevent the opponent from moving while they are within the performing character's attack range.

## Parameters

- No parameters - automatically uses the character's current attack range

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic range-based movement restriction:**
```json
{
  "timing": "during_strike",
  "effect_type": "opponent_cant_move_if_in_range"
}
```

## Implementation Notes

- Sets `cannot_move_if_in_opponents_range` flag on the opponent
- Opponent cannot move while they are within the performing character's attack range
- Range is calculated dynamically based on current attack range modifiers
- If opponent moves out of range through other means, movement restriction is lifted
- Creates appropriate log message indicating the range-based movement restriction
- More flexible than absolute movement blocks as it allows movement outside range

## Related Effects

- [block_opponent_move](block_opponent_move.md) - Complete movement block
- [opponent_cant_move_past](opponent_cant_move_past.md) - Block passing through character
- [opponent_cant_move_past_buddy](opponent_cant_move_past_buddy.md) - Block passing through buddy
- [may_ignore_movement_limit](may_ignore_movement_limit.md) - Override movement restrictions

## Real Usage Examples

From card definitions:
- Zone control effects: `{ "timing": "during_strike", "effect_type": "opponent_cant_move_if_in_range" }`
- Defensive positioning: Prevent opponent from repositioning while in attack range
- Pressure mechanics: Lock opponent in place when they're in danger zone