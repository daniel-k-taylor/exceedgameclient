# block_opponent_move

**Category**: Movement
**Description**: Prevent the opponent from moving for the duration of the effect.

## Parameters

- No parameters - simply blocks all opponent movement

## Supported Timings

- `during_strike` - During strike resolution
- `now` - Immediately when played
- `after` - After strike resolution

## Examples

**Block movement during strike:**
```json
{
  "timing": "during_strike",
  "effect_type": "block_opponent_move"
}
```

**Immediate movement block:**
```json
{
  "timing": "now",
  "effect_type": "block_opponent_move"
}
```

**Block with automatic removal:**
```json
[
  {
    "timing": "during_strike",
    "effect_type": "block_opponent_move"
  },
  {
    "timing": "cleanup",
    "effect_type": "remove_block_opponent_move"
  }
]
```

## Implementation Notes

- Sets a flag preventing all opponent movement effects
- Blocks advance, retreat, close, pull, push, and all other movement types
- Effect persists until explicitly removed or end of strike
- Creates event `EventType_BlockMovement` for game state tracking
- Generates appropriate log message indicating movement prevention
- Does not affect non-movement positioning effects

## Related Effects

- [remove_block_opponent_move](remove_block_opponent_move.md) - Remove movement block
- [opponent_cant_move_past](opponent_cant_move_past.md) - Block passing through character
- [opponent_cant_move_if_in_range](opponent_cant_move_if_in_range.md) - Conditional movement block
- [may_ignore_movement_limit](may_ignore_movement_limit.md) - Override movement restrictions

## Real Usage Examples

From card definitions:
- Control effects: `{ "timing": "during_strike", "effect_type": "block_opponent_move" }`
- Boost cards: `{ "timing": "now", "effect_type": "block_opponent_move" }`
- Positioning control: Combined with cleanup removal for temporary blocks
- Defensive abilities: Prevent opponent repositioning during critical moments