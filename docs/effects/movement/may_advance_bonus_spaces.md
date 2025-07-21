# may_advance_bonus_spaces

**Category**: Movement
**Description**: Grant the player the option to advance additional spaces beyond normal movement limits.

## Parameters

- `amount` (required): Number of bonus spaces that may be advanced
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `after` - After strike resolution

## Examples

**Basic bonus advance option:**
```json
{
  "character_effect": true,
  "effect_type": "may_advance_bonus_spaces",
  "amount": 1
}
```

## Implementation Notes

- Creates a decision choice for the player during movement phases
- Player can choose to use or not use the bonus movement
- Bonus movement is in addition to any other movement effects
- Does not stack with multiple instances - uses the highest amount available
- Applies to advance-type movements only, not other movement effects
- Player maintains full control over when and whether to use the bonus

## Related Effects

- [advance](advance.md) - Basic forward movement
- [may_ignore_movement_limit](may_ignore_movement_limit.md) - Ignore movement restrictions
- [close](close.md) - Move toward opponent
- [move_to_space](move_to_space.md) - Move to specific position

## Real Usage Examples

From card definitions:
- Character passive abilities: `{ "character_effect": true, "effect_type": "may_advance_bonus_spaces", "amount": 1 }`
- Equipment or stance effects: Additional mobility options
- Strategic positioning: Extra movement for tactical advantage