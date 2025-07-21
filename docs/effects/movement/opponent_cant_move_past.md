# opponent_cant_move_past

**Category**: Movement
**Description**: Prevent the opponent from moving past or through the performing character's position.

## Parameters

- No parameters - blocks movement past the performing character

## Supported Timings

- `during_strike` - During strike resolution
- `now` - Immediately when played

## Examples

**Block opponent pass-through during strike:**
```json
{
  "timing": "during_strike",
  "effect_type": "opponent_cant_move_past"
}
```

**Immediate pass-through block:**
```json
{
  "timing": "now",
  "effect_type": "opponent_cant_move_past"
}
```

**Block with automatic removal:**
```json
[
  {
    "timing": "during_strike",
    "effect_type": "opponent_cant_move_past"
  },
  {
    "timing": "cleanup",
    "effect_type": "remove_opponent_cant_move_past"
  }
]
```

## Implementation Notes

- Sets `cannot_move_past_opponent` flag on the opponent
- Opponent cannot advance through or past the performing character's space
- Does not block all movement - only movement that would cross the character's position
- Creates event `EventType_Strike_OpponentCantMovePast` for game state tracking
- Generates log message indicating the character cannot be advanced through
- Effect persists until explicitly removed or end of strike

## Related Effects

- [remove_opponent_cant_move_past](remove_opponent_cant_move_past.md) - Remove pass-through restriction
- [opponent_cant_move_past_buddy](opponent_cant_move_past_buddy.md) - Block passing through buddy
- [block_opponent_move](block_opponent_move.md) - Complete movement block
- [opponent_cant_move_if_in_range](opponent_cant_move_if_in_range.md) - Range-based movement restriction

## Real Usage Examples

From card definitions:
- Defensive positioning: `{ "timing": "during_strike", "effect_type": "opponent_cant_move_past" }`
- Boost effects: `{ "timing": "now", "effect_type": "opponent_cant_move_past" }`
- Temporary blocking: Combined with cleanup removal effects
- Zone control: Prevent opponent from crossing through strategic positions