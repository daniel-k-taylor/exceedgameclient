# gauge_costs_reduced_passive

**Category**: Gauge
**Description**: Reduce all gauge costs by a specified amount for the duration of the effect.

## Parameters

- `amount` (required): Amount to reduce gauge costs by
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `immediate` - Immediately when triggered
- `now` - Immediately when played
- `passive` - Ongoing passive effect

## Examples

**Basic cost reduction:**
```json
{
  "timing": "immediate",
  "effect_type": "gauge_costs_reduced_passive",
  "amount": 1
}
```

**Large reduction:**
```json
{
  "timing": "now",
  "effect_type": "gauge_costs_reduced_passive",
  "amount": 2
}
```

## Implementation Notes

- Reduces all gauge costs for the player by the specified amount
- Applies to gauge spending for effects and abilities
- Cannot reduce costs below 0
- Effect persists until removed or overridden
- Stacks with other cost reduction effects
- Creates log message about cost reduction

## Related Effects

- [force_costs_reduced_passive](force_costs_reduced_passive.md) - Force cost reduction
- [gauge_for_effect](gauge_for_effect.md) - Spend gauge for effects
- [spend_all_gauge_and_save_amount](spend_all_gauge_and_save_amount.md) - Spend all gauge

## Real Usage Examples

From card definitions:
- Character abilities that provide ongoing gauge efficiency
- Temporary cost reduction buffs
- Strategic effects that enable expensive gauge actions