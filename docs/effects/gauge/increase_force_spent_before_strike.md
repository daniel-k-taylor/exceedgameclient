# increase_force_spent_before_strike

**Category**: Gauge and Force
**Description**: Increases the count of force spent before the current strike by 1, which can trigger effects that scale with force expenditure.

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
  "effect_type": "increase_force_spent_before_strike"
}
```

**Per-force effect trigger:**
```json
{
  "per_force_effect": {
    "effect_type": "increase_force_spent_before_strike",
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
  "effect_type": "increase_force_spent_before_strike",
  "and": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

## Implementation Notes

- Directly increments the `force_spent_before_strike` counter by 1
- This counter is used by various scaling effects and conditions
- The counter persists for the duration of the current strike
- Multiple applications of this effect will stack, incrementing the counter each time
- Does not actually spend force from the player's force pool - only increases the tracked count
- Often used in combination with per-force effects to create scaling benefits
- The counter is reset between strikes

## Related Effects

- [`increase_gauge_spent_before_strike`](increase_gauge_spent_before_strike.md) - Similar effect for gauge spending tracking
- [`force_for_effect`](force_for_effect.md) - Actually generates and spends force
- [`spend_all_force_and_save_amount`](spend_all_force_and_save_amount.md) - Spends actual force and tracks the amount
- [`powerup_per_force_spent`](../stats/powerup_per_force_spent.md) - Scaling effect based on force spent

## Real Usage Examples

From card definitions:
- Per-force scaling effects: Used with `per_force_effect` to trigger multiple instances of linked effects
- Combo enablers: Building up force-spent counters for powerful finishing moves
- Resource conversion cards: Converting other resources into effective "force spent" for scaling purposes
- Mathematical function cards: Creating precise scaling relationships based on simulated force expenditure