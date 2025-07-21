# opponent_cant_move_past_buddy

**Category**: Movement
**Description**: Prevent the opponent from moving past or through a specific buddy's position.

## Parameters

- `buddy_name` (required): Name of the buddy that blocks opponent movement
  - **Type**: String
  - **Values**: Any valid buddy name (e.g., "card", specific buddy names)

## Supported Timings

- `during_strike` - During strike resolution
- `now` - Immediately when played

## Examples

**Block movement past buddy:**
```json
{
  "condition": "buddy_in_play",
  "effect_type": "opponent_cant_move_past_buddy",
  "buddy_name": "card"
}
```

## Implementation Notes

- Sets `cannot_move_past_opponent_buddy_id` flag on the opponent with specific buddy ID
- Opponent cannot advance through or past the specified buddy's position
- Effect only applies if the named buddy is currently in play
- Uses buddy ID internally but references buddy by name in card definitions
- Creates event `EventType_Strike_OpponentCantMovePast` with buddy name
- Generates log message indicating the buddy cannot be advanced through
- More specific than character-based blocking - targets individual buddies

## Related Effects

- [remove_opponent_cant_move_past_buddy](remove_opponent_cant_move_past_buddy.md) - Remove buddy pass-through restriction
- [opponent_cant_move_past](opponent_cant_move_past.md) - Block passing through character
- [block_opponent_move](block_opponent_move.md) - Complete movement block
- [buddy_immune_to_flip](../special/buddy_immune_to_flip.md) - Buddy protection effects

## Real Usage Examples

From card definitions:
- Buddy control: `{ "condition": "buddy_in_play", "effect_type": "opponent_cant_move_past_buddy", "buddy_name": "card" }`
- Positional control: Using buddies as movement barriers
- Strategic positioning: Creating chokepoints with buddy placement