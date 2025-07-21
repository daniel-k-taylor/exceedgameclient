# armorup_times_gauge

**Category**: Stats
**Description**: Gain armor equal to gauge size times specified amount. Scales armor with gauge resources.

## Parameters

- `amount` (required): Multiplier for gauge size
  - **Type**: Integer

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Gauge-based armor:**
```json
{
  "timing": "during_strike",
  "effect_type": "armorup_times_gauge",
  "amount": 1
}
```

**Double gauge armor:**
```json
{
  "timing": "during_strike",
  "effect_type": "armorup_times_gauge",
  "amount": 2
}
```

## Implementation Notes

- Armor = gauge size × amount
- Encourages gauge hoarding for defensive benefits
- Creates scaling defensive options
- Can provide significant armor with large gauge

## Related Effects

- [armorup](armorup.md) - Basic armor increase
- [powerup_per_gauge](powerup_per_gauge.md) - Power based on gauge
- [guardup_per_gauge](guardup_per_gauge.md) - Guard based on gauge

## Real Usage Examples

From card definitions:
- Gauge-focused defensive builds
- Resource management strategies
- Scaling defensive abilities