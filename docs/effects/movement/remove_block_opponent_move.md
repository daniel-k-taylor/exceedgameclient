# remove_block_opponent_move

**Category**: Movement
**Description**: Remove the movement block on the opponent, restoring their ability to move.

## Parameters

- No parameters - simply removes the movement block

## Supported Timings

- `cleanup` - During cleanup phase
- `discarded` - When the effect source is discarded
- `now` - Immediately when played

## Examples

**Remove block during cleanup:**
```json
{
  "timing": "cleanup",
  "effect_type": "remove_block_opponent_move"
}
```

**Remove block when discarded:**
```json
{
  "timing": "discarded",
  "effect_type": "remove_block_opponent_move"
}
```

**Chained removal:**
```json
{
  "and": {
    "effect_type": "remove_block_opponent_move"
  }
}
```

## Implementation Notes

- Removes the movement block flag from the opponent
- Restores opponent's normal movement capabilities
- Typically paired with [`block_opponent_move`](block_opponent_move.md) for temporary blocks
- Generates appropriate log message indicating movement is restored
- Has no effect if opponent movement is not currently blocked
- Often triggered automatically by timing events like cleanup or discard

## Related Effects

- [block_opponent_move](block_opponent_move.md) - Block opponent movement
- [remove_opponent_cant_move_past](remove_opponent_cant_move_past.md) - Remove pass-through restriction
- [opponent_cant_move_if_in_range](opponent_cant_move_if_in_range.md) - Conditional movement restriction
- [may_ignore_movement_limit](may_ignore_movement_limit.md) - Override movement limits

## Real Usage Examples

From card definitions:
- Cleanup effects: `{ "timing": "cleanup", "effect_type": "remove_block_opponent_move" }`
- Discard triggers: `{ "timing": "discarded", "effect_type": "remove_block_opponent_move" }`
- Automatic restoration: Paired with temporary movement blocks
- Control card cleanup: Removing temporary positioning restrictions