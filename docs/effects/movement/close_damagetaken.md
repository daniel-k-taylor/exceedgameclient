# close_damagetaken

**Category**: Movement
**Description**: Move toward the opponent by a specified amount for each point of damage taken.

## Parameters

- `amount` (required): Number of spaces to close for each damage taken
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Special Values**: None

## Supported Timings

- `before` - Before strike resolution

## Examples

**Basic close per damage:**
```json
{
  "timing": "before",
  "effect_type": "close_damagetaken",
  "amount": 1
}
```

## Implementation Notes

- For each point of damage taken, executes a close effect with the specified amount
- Uses the internal [`close_INTERNAL`](close_internal.md) effect for actual movement
- Damage amount is determined at the time of effect execution
- Movement is cumulative - multiple damage points result in multiple close movements
- Triggers character effects at timing "on_advance_or_close"

## Related Effects

- [close](close.md) - Basic close movement toward opponent
- [close_INTERNAL](close_internal.md) - Internal implementation used by this effect
- [advance](advance.md) - Forward movement by fixed amount
- [retreat](retreat.md) - Backward movement away from opponent

## Real Usage Examples

From card definitions:
- Various character cards: `{ "timing": "before", "effect_type": "close_damagetaken", "amount": 1 }`
- Used for reactive movement mechanics where taking damage triggers closing in on the opponent