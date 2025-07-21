# multiply_positive_power_bonuses

**Category**: Stats
**Description**: Multiply all positive power bonuses by the specified amount. Enhances power gains but not base power.

## Parameters

- `amount` (required): Multiplier for positive power bonuses
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Double positive power bonuses:**
```json
{
  "timing": "during_strike",
  "effect_type": "multiply_positive_power_bonuses",
  "amount": 2
}
```

**Triple positive power bonuses:**
```json
{
  "timing": "during_strike",
  "effect_type": "multiply_positive_power_bonuses",
  "amount": 3
}
```

## Implementation Notes

- Only affects positive power bonuses, not base power or negative modifiers
- Applied after all power bonuses are calculated
- Stacks multiplicatively with other multiplier effects
- Can create explosive power scaling with multiple bonuses
- Commonly found on high-cost or conditional effects

## Related Effects

- [multiply_power_bonuses](multiply_power_bonuses.md) - Multiply all power bonuses
- [multiply_speed_bonuses](multiply_speed_bonuses.md) - Multiply speed bonuses
- [powerup](powerup.md) - Basic power increase

## Real Usage Examples

From card definitions:
- Sol Badguy's "Dragon Install": Massive power scaling
- Various exceed and ultimate effects with power multiplication
- High-risk, high-reward attack enhancements