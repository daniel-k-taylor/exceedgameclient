# armorup

**Category**: Stats
**Description**: Increase armor by a specified amount for this strike. Armor reduces incoming damage.

## Parameters

- `amount` (required): Amount of armor to add
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `during_strike` - During strike resolution
- `before` - Before strike resolution
- `hit` - When attack hits

## Examples

**Basic armor increase:**
```json
{
  "timing": "during_strike",
  "effect_type": "armorup",
  "amount": 2
}
```

**Light armor boost:**
```json
{
  "timing": "before",
  "effect_type": "armorup",
  "amount": 1
}
```

**Heavy armor on hit:**
```json
{
  "timing": "hit",
  "effect_type": "armorup",
  "amount": 3
}
```

**Conditional armor:**
```json
{
  "timing": "during_strike",
  "condition": "is_normal_attack",
  "effect_type": "armorup",
  "amount": 1
}
```

## Implementation Notes

- Armor bonus is applied to `strike_stat_boosts.armor`
- Stacks with other armor effects
- Armor reduces incoming damage on a 1:1 basis
- Used armor is consumed during damage calculation
- Can be generated in response to attacks for damage mitigation
- Some effects can bypass armor (see `ignore_armor`)

## Related Effects

- [armorup_damage_dealt](armorup_damage_dealt.md) - Gain armor equal to damage dealt
- [armorup_current_power](armorup_current_power.md) - Gain armor equal to power
- [armorup_times_gauge](armorup_times_gauge.md) - Gain armor based on gauge
- [lose_all_armor](lose_all_armor.md) - Remove all armor
- [ignore_armor](../attack/ignore_armor.md) - Bypass armor

## Real Usage Examples

From card definitions:
- Tager's "Sledgehammer": `{ "timing": "during_strike", "effect_type": "armorup", "amount": 1 }`
- Waldstein's "Verwustung": Heavy armor for trading
- Potemkin's defensive moves: Armor for grappler gameplay
- Bang's "Steel Wheel": Armor on defensive techniques