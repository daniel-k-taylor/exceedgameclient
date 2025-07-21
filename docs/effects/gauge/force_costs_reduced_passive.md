# force_costs_reduced_passive

**Category**: Force
**Description**: Reduce all force costs by a specified amount for the duration of the effect.

## Parameters

- `amount` (required): Amount to reduce force costs by
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
  "effect_type": "force_costs_reduced_passive",
  "amount": 1
}
```

**Large reduction:**
```json
{
  "timing": "now",
  "effect_type": "force_costs_reduced_passive",
  "amount": 3
}
```

## Implementation Notes

- Reduces all force costs for the player by the specified amount
- Applies to movement, change cards, and other force expenditures
- Cannot reduce costs below 0
- Effect persists until removed or overridden
- Stacks with other cost reduction effects
- Creates log message about cost reduction

## Related Effects

- [remove_force_costs_reduced_passive](remove_force_costs_reduced_passive.md) - Remove cost reduction
- [gauge_costs_reduced_passive](gauge_costs_reduced_passive.md) - Gauge cost reduction
- [force_for_effect](force_for_effect.md) - Spend force for effects

## Real Usage Examples

From card definitions:
- Character abilities that provide ongoing force efficiency
- Temporary cost reduction buffs
- Strategic effects that enable expensive force actions