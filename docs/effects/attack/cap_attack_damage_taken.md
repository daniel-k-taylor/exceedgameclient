# cap_attack_damage_taken

**Category**: Attack
**Description**: Limit the maximum damage that can be taken from attacks to a specified amount.

## Parameters

- `amount` (required): Maximum damage that can be taken
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Special Values**: None

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic damage cap:**
```json
{
  "timing": "during_strike",
  "effect_type": "cap_attack_damage_taken",
  "amount": 5
}
```

**Low damage cap:**
```json
{
  "timing": "during_strike",
  "effect_type": "cap_attack_damage_taken",
  "amount": 2
}
```

**Combined with other defenses:**
```json
{
  "timing": "during_strike",
  "effect_type": "cap_attack_damage_taken",
  "amount": 3,
  "and": {
    "effect_type": "stun_immunity"
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.cap_attack_damage_taken = amount`
- Limits damage from any single attack to the specified maximum
- Does not affect damage calculation, only final damage dealt
- Useful for defensive abilities, damage reduction mechanics, or boss fights
- Can significantly reduce the impact of high-power attacks
- Does not stack - only the most recent cap value applies
- Combines well with other defensive effects for comprehensive protection

## Related Effects

- [nonlethal_attack](nonlethal_attack.md) - Prevent lethal damage
- [stun_immunity](stun_immunity.md) - Prevent stun effects
- [armorup](../stats/armorup.md) - Increase armor for damage reduction
- [ignore_armor](ignore_armor.md) - Bypass armor protection

## Real Usage Examples

From card definitions:
- Kokonoe's "Graviton Rage": `{ "timing": "during_strike", "effect_type": "cap_attack_damage_taken", "amount": 5 }`
- Defensive characters: Damage mitigation abilities
- Boss mechanics: Preventing excessive damage from powerful attacks
- Survival tools: Emergency damage reduction for critical situations