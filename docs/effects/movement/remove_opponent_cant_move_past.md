# remove_opponent_cant_move_past

**Category**: Movement
**Description**: Remove the restriction preventing the opponent from moving past the performing character.

## Parameters

- No parameters - simply removes the pass-through restriction

## Supported Timings

- `cleanup` - During cleanup phase
- `discarded` - When the effect source is discarded
- `now` - Immediately when played

## Examples

**Remove restriction during cleanup:**
```json
{
  "timing": "cleanup",
  "effect_type": "remove_opponent_cant_move_past"
}
```

**Remove restriction when discarded:**
```json
{
  "timing": "discarded",
  "effect_type": "remove_opponent_cant_move_past"
}
```

## Implementation Notes

- Sets `cannot_move_past_opponent` flag to false on the opponent
- Restores opponent's ability to move through the performing character's position
- Typically paired with [`opponent_cant_move_past`](opponent_cant_move_past.md) for temporary restrictions
- Generates log message indicating the character is no longer blocking opponent movement
- Has no effect if opponent movement past character is not currently restricted
- Often triggered automatically by timing events like cleanup or discard

## Related Effects

- [opponent_cant_move_past](opponent_cant_move_past.md) - Block opponent from moving past character
- [remove_opponent_cant_move_past_buddy](remove_opponent_cant_move_past_buddy.md) - Remove buddy pass-through restriction
- [remove_block_opponent_move](remove_block_opponent_move.md) - Remove complete movement block
- [may_ignore_movement_limit](may_ignore_movement_limit.md) - Override movement restrictions

## Real Usage Examples

From card definitions:
- Cleanup effects: `{ "timing": "cleanup", "effect_type": "remove_opponent_cant_move_past" }`
- Discard triggers: `{ "timing": "discarded", "effect_type": "remove_opponent_cant_move_past" }`
- Temporary restrictions: Paired with opponent_cant_move_past for limited duration blocks
- Positional control cleanup: Restoring normal movement after strategic blocking