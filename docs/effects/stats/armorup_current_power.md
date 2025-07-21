# armorup_current_power

**Category**: Stats
**Description**: Gain armor equal to current total power. Defensive scaling based on offensive capability.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Power-based armor:**
```json
{
  "timing": "during_strike",
  "effect_type": "armorup_current_power"
}
```

## Implementation Notes

- Armor gained equals current total power (base + all bonuses)
- Calculated after all power effects are applied
- Can create powerful defensive scaling
- Used for builds that stack power and defense together
- Creates armor gain log message with power amount

## Related Effects

- [armorup](armorup.md) - Basic armor increase
- [armorup_damage_dealt](armorup_damage_dealt.md) - Armor based on damage dealt
- [powerup](powerup.md) - Increase power

## Real Usage Examples

From card definitions:
- High-power defensive abilities
- Scaling effects for power-focused builds
- Risk/reward mechanics that convert offense to defense