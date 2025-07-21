# retreat_INTERNAL

**Category**: Movement
**Description**: Internal implementation of retreat movement that handles the actual character positioning away from the opponent.

## Parameters

- `amount` (required): Number of spaces to move away from the opponent
  - **Type**: Integer or String
  - **Range**: Any positive integer
  - **Special Values**:
    - `"strike_x"` - Use the current strike's X value

## Supported Timings

- `before` - Before strike resolution
- `after` - After strike resolution
- `hit` - When attack hits
- `during_strike` - During strike resolution

## Examples

**Basic internal retreat:**
```json
{
  "timing": "during_strike",
  "effect_type": "retreat_INTERNAL",
  "amount": 2
}
```

**Retreat using strike X:**
```json
{
  "timing": "hit",
  "effect_type": "retreat_INTERNAL",
  "amount": "strike_x"
}
```

## Implementation Notes

- This is an internal effect typically called by other retreat-related effects
- Performs the actual movement calculation and character positioning
- Movement amount can be modified by `strike_stat_boosts.increase_movement_effects_by`
- Stops at arena boundaries (spaces 1-9)
- Cannot move to space occupied by opponent
- Movement direction is away from the opponent (backward)

## Related Effects

- [retreat](retreat.md) - Public retreat effect that uses this internally
- [advance](advance.md) - Forward movement toward opponent
- [close_INTERNAL](close_internal.md) - Internal close implementation
- [move_to_space](move_to_space.md) - Move to specific arena position

## Real Usage Examples

From card definitions:
- Used internally by retreat and other retreat-based effects
- Not typically used directly in card definitions
- Part of the movement system's internal implementation