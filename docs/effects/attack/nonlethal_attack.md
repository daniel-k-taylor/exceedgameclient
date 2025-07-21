# nonlethal_attack

**Category**: Attack
**Description**: Make the attack deal nonlethal damage, preventing it from reducing opponent's life below 1.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic nonlethal attack:**
```json
{
  "timing": "during_strike",
  "effect_type": "nonlethal_attack"
}
```

**Nonlethal attack with power boost:**
```json
{
  "timing": "during_strike",
  "effect_type": "nonlethal_attack",
  "and": {
    "effect_type": "powerup",
    "amount": 3
  }
}
```

**Conditional nonlethal effect:**
```json
{
  "condition": "is_critical",
  "effect_type": "nonlethal_attack"
}
```

## Implementation Notes

- Sets `strike_stat_boosts.deal_nonlethal_damage = true`
- Prevents damage from reducing opponent's life to 0 or below
- Opponent's life will be reduced to minimum of 1 if damage would be lethal
- Does not affect actual damage calculation, only final life reduction
- Useful for training attacks, mercy strikes, or capture mechanics
- Can be combined with other attack effects

## Related Effects

- [critical](critical.md) - Double damage
- [powerup](../stats/powerup.md) - Increase power
- [cap_attack_damage_taken](cap_attack_damage_taken.md) - Limit damage taken

## Real Usage Examples

From card definitions:
- Seth's "Tanden Medium": `{ "timing": "during_strike", "effect_type": "nonlethal_attack" }`
- Seth's "Tanden High": Combined with power bonuses for training sequences
- Various martial arts characters: Training moves that don't cause serious harm
- Capture-based gameplay: Subdue without killing mechanics