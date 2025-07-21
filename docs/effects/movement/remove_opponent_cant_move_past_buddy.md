# remove_opponent_cant_move_past_buddy

**Category**: Movement
**Description**: Remove the restriction preventing the opponent from moving past a specific buddy.

## Parameters

- `buddy_name` (required): Name of the buddy to remove movement restriction for
  - **Type**: String
  - **Values**: Any valid buddy name (e.g., "card", specific buddy names)

## Supported Timings

- `cleanup` - During cleanup phase
- `discarded` - When the effect source is discarded
- `now` - Immediately when played

## Examples

**Remove buddy restriction when discarded:**
```json
{
  "condition": "buddy_in_play",
  "effect_type": "remove_opponent_cant_move_past_buddy",
  "buddy_name": "card"
}
```

## Implementation Notes

- Clears the `cannot_move_past_opponent_buddy_id` flag for the specified buddy
- Restores opponent's ability to move through the specified buddy's position
- Must specify the same buddy name that was used in the original restriction
- Typically paired with [`opponent_cant_move_past_buddy`](opponent_cant_move_past_buddy.md) for temporary restrictions
- Has no effect if the specified buddy is not currently blocking opponent movement
- Often triggered automatically by timing events like cleanup or discard

## Related Effects

- [opponent_cant_move_past_buddy](opponent_cant_move_past_buddy.md) - Block opponent from moving past buddy
- [remove_opponent_cant_move_past](remove_opponent_cant_move_past.md) - Remove character pass-through restriction
- [remove_block_opponent_move](remove_block_opponent_move.md) - Remove complete movement block
- [buddy_immune_to_flip](../special/buddy_immune_to_flip.md) - Buddy protection effects

## Real Usage Examples

From card definitions:
- Discard cleanup: `{ "condition": "buddy_in_play", "effect_type": "remove_opponent_cant_move_past_buddy", "buddy_name": "card" }`
- Temporary buddy blocking: Paired with opponent_cant_move_past_buddy for limited duration
- Buddy management: Removing positional restrictions when buddy effects end