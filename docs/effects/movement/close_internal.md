# close_INTERNAL

**Category**: Movement
**Description**: Internal implementation of close movement that handles the actual character positioning toward the opponent.

## Parameters

- `amount` (required): Number of spaces to move toward the opponent
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

**Basic internal close:**
```json
{
  "timing": "during_strike",
  "effect_type": "close_INTERNAL",
  "amount": 2
}
```

**Close using strike X:**
```json
{
  "timing": "hit",
  "effect_type": "close_INTERNAL",
  "amount": "strike_x"
}
```

## Implementation Notes

- This is an internal effect typically called by other close-related effects
- Performs the actual movement calculation and character positioning
- Triggers character effects at timing "on_advance_or_close"
- Movement amount can be modified by `strike_stat_boosts.increase_movement_effects_by`
- Stops at arena boundaries (spaces 1-9)
- Cannot move to space occupied by opponent

## Related Effects

- [close](close.md) - Public close effect that uses this internally
- [close_damagetaken](close_damagetaken.md) - Close based on damage taken
- [advance](advance.md) - Forward movement by fixed amount
- [retreat_INTERNAL](retreat_internal.md) - Internal retreat implementation

## Real Usage Examples

From card definitions:
- Used internally by close and close_damagetaken effects
- Not typically used directly in card definitions
- Part of the movement system's internal implementation