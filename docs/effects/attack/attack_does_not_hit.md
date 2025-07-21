# attack_does_not_hit

**Category**: Attack
**Description**: Make an attack not hit (miss). The attack deals no damage and does not trigger hit effects.

## Parameters

- `opponent` (optional): If true, opponent's attack doesn't hit instead of your own
  - **Type**: Boolean
  - **Default**: false
- `hide_notice` (optional): If true, don't show miss notification
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `during_strike` - During strike resolution
- `before` - Before strike resolution

## Examples

**Make your attack miss:**
```json
{
  "timing": "during_strike",
  "effect_type": "attack_does_not_hit"
}
```

**Make opponent's attack miss:**
```json
{
  "timing": "during_strike",
  "effect_type": "attack_does_not_hit",
  "opponent": true
}
```

**Silent miss:**
```json
{
  "timing": "before",
  "effect_type": "attack_does_not_hit",
  "hide_notice": true
}
```

## Implementation Notes

- Sets `strike_stat_boosts.attack_does_not_hit = true`
- Attack deals 0 damage regardless of power
- Hit effects do not trigger
- Used for dodge mechanics, illusions, and defensive abilities
- Can be conditional based on range, speed, or other factors
- Creates appropriate miss log message unless hidden

## Related Effects

- [dodge_attacks](dodge_attacks.md) - Dodge all attacks
- [dodge_at_range](dodge_at_range.md) - Dodge attacks at specific range
- [higher_speed_misses](higher_speed_misses.md) - Higher speed attacks miss
- [dodge_normals](dodge_normals.md) - Dodge normal attacks only

## Real Usage Examples

From card definitions:
- Chipp's "Invisibility": `{ "timing": "during_strike", "effect_type": "attack_does_not_hit", "opponent": true }`
- Millia's "Bad Moon": Dodge mechanics with miss effects
- Various illusion and evasion abilities
- Defensive stance effects that avoid damage