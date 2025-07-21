# force_for_effect

**Category**: Force
**Description**: Spend force for additional effects. Player chooses how much force to spend (up to limits) and gains the effect per force spent.

## Parameters

- `effect` (required): Effect gained per force spent
  - **Type**: Effect object
  - **Note**: This effect is repeated for each force spent
- `force_max` (optional): Maximum force that can be spent
  - **Type**: Integer
  - **Default**: No limit (can spend all force)

## Supported Timings

- `set_strike` - When setting a strike (most common)

## Examples

**Spend force for power:**
```json
{
  "timing": "set_strike",
  "effect_type": "force_for_effect",
  "effect": {
    "effect_type": "powerup",
    "amount": 1
  },
  "force_max": 2
}
```

**Spend force for range:**
```json
{
  "timing": "set_strike",
  "effect_type": "force_for_effect",
  "effect": {
    "effect_type": "rangeup",
    "amount": 1
  }
}
```

**Spend force for complex effect:**
```json
{
  "timing": "set_strike",
  "effect_type": "force_for_effect",
  "effect": {
    "effect_type": "speedup",
    "amount": 1,
    "and": {
      "effect_type": "armorup",
      "amount": 1
    }
  },
  "force_max": 3
}
```

## Implementation Notes

- Creates a decision state where player chooses amount to spend
- Force is spent from current turn's available force
- Effect is applied once per force spent
- Player can choose to spend 0 (no effect)
- Often used for EX attack upgrades and enhancement mechanics
- Force spending is tracked for other effects that reference it

## Related Effects

- [gauge_for_effect](gauge_for_effect.md) - Spend gauge for effects
- [generate_free_force](generate_free_force.md) - Generate force
- [spend_all_force_and_save_amount](spend_all_force_and_save_amount.md) - Spend all force
- [powerup_per_force_spent_this_turn](../stats/powerup_per_force_spent_this_turn.md) - Power based on force spent

## Real Usage Examples

From card definitions:
- Ryu's character action: Spend force for movement and draw
- Chun-Li's character action: Spend force for range and draw
- Ken's character action: Spend force for close and draw
- Universal EX attack mechanics across Street Fighter characters