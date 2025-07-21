# gauge_for_effect

**Category**: Gauge
**Description**: Spend gauge cards for additional effects. Player chooses how much gauge to spend (up to limits) and gains the effect per gauge spent.

## Parameters

- `effect` (required): Effect gained per gauge card spent
  - **Type**: Effect object
  - **Note**: This effect is repeated for each gauge spent
- `gauge_max` (optional): Maximum gauge cards that can be spent
  - **Type**: Integer
  - **Default**: No limit (can spend all gauge)
- `force_max` (optional): Maximum force that can be spent instead of gauge
  - **Type**: Integer
  - **Note**: Alternative resource option

## Supported Timings

- `set_strike` - When setting a strike (most common)

## Examples

**Spend gauge for power:**
```json
{
  "timing": "set_strike",
  "effect_type": "gauge_for_effect",
  "effect": {
    "effect_type": "powerup",
    "amount": 1
  },
  "gauge_max": 3
}
```

**Spend gauge for range:**
```json
{
  "timing": "set_strike",
  "effect_type": "gauge_for_effect",
  "effect": {
    "effect_type": "rangeup",
    "amount": 1
  }
}
```

**Spend gauge for complex effect:**
```json
{
  "timing": "set_strike",
  "effect_type": "gauge_for_effect",
  "effect": {
    "effect_type": "powerup",
    "amount": 1,
    "and": {
      "effect_type": "speedup",
      "amount": 1
    }
  },
  "gauge_max": 2
}
```

**Gauge or force option:**
```json
{
  "timing": "set_strike",
  "effect_type": "gauge_for_effect",
  "effect": {
    "effect_type": "armorup",
    "amount": 1
  },
  "gauge_max": 3,
  "force_max": 2
}
```

## Implementation Notes

- Creates a decision state where player chooses amount to spend
- Gauge cards are moved to discard pile when spent
- Effect is applied once per gauge/force spent
- Player can choose to spend 0 (no effect)
- If both gauge_max and force_max are specified, player chooses which resource to spend

## Related Effects

- [force_for_effect](force_for_effect.md) - Spend force for effects
- [add_top_deck_to_gauge](add_top_deck_to_gauge.md) - Add cards to gauge
- [spend_all_gauge_and_save_amount](spend_all_gauge_and_save_amount.md) - Spend all gauge

## Real Usage Examples

From card definitions:
- Akuma's character action: Spend gauge for powerup
- Ryu's character action: Spend gauge for movement + draw
- Chun-Li's character action: Spend gauge for range + draw
- Ken's character action: Spend gauge for close + draw
- Zangief's attacks: Spend gauge for powerup on critical hits