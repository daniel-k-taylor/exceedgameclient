# increase_gauge_spent_before_strike

**Category**: Gauge and Force
**Description**: Increases the count of gauge spent before the current strike by 1, which can trigger effects that scale with gauge expenditure.

## Parameters

This effect takes no parameters.

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `now` - Immediately when played
- `immediate` - Immediately when triggered

## Examples

**Basic usage:**
```json
{
  "timing": "before",
  "effect_type": "increase_gauge_spent_before_strike"
}
```

**Per-gauge effect trigger:**
```json
{
  "per_gauge_effect": {
    "effect_type": "increase_gauge_spent_before_strike",
    "linked_effect": {
      "effect_type": "powerup",
      "amount": 1
    }
  }
}
```

**Combined with other effects:**
```json
{
  "timing": "before",
  "and": {
    "effect_type": "increase_gauge_spent_before_strike"
  }
}
```

## Implementation Notes

- Directly increments the `gauge_spent_before_strike` counter by 1
- This counter is used by various scaling effects and conditions
- The counter persists for the duration of the current strike
- Multiple applications of this effect will stack, incrementing the counter each time
- Does not actually spend gauge from the player's gauge pool - only increases the tracked count
- Often used in combination with per-gauge effects to create scaling benefits
- The counter is reset between strikes

## Related Effects

- [`increase_force_spent_before_strike`](increase_force_spent_before_strike.md) - Similar effect for force spending tracking
- [`gauge_for_effect`](gauge_for_effect.md) - Actually generates and spends gauge
- [`spend_all_gauge_and_save_amount`](spend_all_gauge_and_save_amount.md) - Spends actual gauge and tracks the amount
- [`powerup_per_gauge_spent`](../stats/powerup_per_gauge_spent.md) - Scaling effect based on gauge spent

## Real Usage Examples

From card definitions:
- Per-gauge scaling effects: Used with `per_gauge_effect` to trigger multiple instances of linked effects
- Combo enablers: Building up gauge-spent counters for powerful finishing moves
- Resource conversion cards: Converting other resources into effective "gauge spent" for scaling purposes
- Strategic resource management: Creating simulated gauge expenditure without actually consuming gauge cards