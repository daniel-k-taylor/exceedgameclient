# reset_character_positions

**Category**: Movement
**Description**: Reset both characters to their starting arena positions.

## Parameters

- No parameters - automatically moves characters to their starting locations

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `after` - After strike resolution

## Examples

**Basic position reset:**
```json
{
  "timing": "during_strike",
  "effect_type": "reset_character_positions"
}
```

**Conditional reset:**
```json
{
  "condition": "used_character_bonus",
  "effect_type": "reset_character_positions"
}
```

**Reset with chained effect:**
```json
{
  "condition": "not_initiated_strike",
  "effect_type": "reset_character_positions",
  "and": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

## Implementation Notes

- Moves performing character to their `starting_location`
- Moves opponent to their `starting_location`
- Both movements are instantaneous and ignore normal movement restrictions
- Can move characters to spaces that would normally be blocked
- Does not trigger movement-related character effects
- Useful for resetting board state after complex positioning

## Related Effects

- [move_to_space](move_to_space.md) - Move self to specific position
- [move_to_any_space](move_to_any_space.md) - Choose position to move to
- [advance](advance.md) - Forward movement
- [retreat](retreat.md) - Backward movement

## Real Usage Examples

From card definitions:
- Tinker Tank: `{ "condition": "used_character_bonus", "effect_type": "reset_character_positions" }`
- Character abilities: `{ "condition": "not_initiated_strike", "effect_type": "reset_character_positions" }`
- Stage control effects: Reset positioning after complex maneuvers
- Defensive options: Return to safe starting positions