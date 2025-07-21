# may_ignore_movement_limit

**Category**: Movement
**Description**: Grant the player the option to ignore normal movement restrictions and limitations.

## Parameters

- No parameters - simply grants the movement freedom option

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `after` - After strike resolution

## Examples

**Basic movement limit ignore:**
```json
{
  "condition": "exceeded",
  "effect_type": "may_ignore_movement_limit"
}
```

## Implementation Notes

- Creates a decision choice for the player during movement phases
- Player can choose whether to use normal movement rules or ignore limitations
- When activated, bypasses restrictions like:
  - Movement distance limits
  - Blocked movement effects
  - Other positional constraints
- Player maintains full control over when to activate this ability
- Typically tied to exceed conditions or special character states

## Related Effects

- [may_advance_bonus_spaces](may_advance_bonus_spaces.md) - Additional movement spaces
- [block_opponent_move](block_opponent_move.md) - Prevent opponent movement
- [advance](advance.md) - Basic forward movement
- [move_to_space](move_to_space.md) - Move to specific position

## Real Usage Examples

From card definitions:
- Exceed abilities: `{ "condition": "exceeded", "effect_type": "may_ignore_movement_limit" }`
- Character-specific mechanics: Temporary movement freedom
- Special state abilities: Breaking normal positioning rules
- Tactical options: Override movement restrictions when needed