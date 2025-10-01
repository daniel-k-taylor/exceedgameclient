# critical

**Category**: Attack
**Description**: Make the current attack critical, which doubles the damage dealt.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution
- `set_strike` - When setting a strike

## Examples

**Basic critical effect:**
```json
{
  "timing": "during_strike",
  "effect_type": "critical"
}
```

**Conditional critical:**
```json
{
  "timing": "set_strike",
  "condition": "is_not_critical",
  "effect_type": "critical"
}
```

**Critical with additional effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "critical",
  "and": {
	"effect_type": "powerup",
	"amount": 2
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.critical = true`
- Creates a "Critical!" log message and event
- Can be checked by conditions like `is_critical`
- Only one critical effect needed per strike

## Related Effects

- [attack_is_ex](attack_is_ex.md) - Make attack EX
- [powerup](../stats/powerup.md) - Increase power
- [ignore_armor](ignore_armor.md) - Ignore opponent's armor

## Real Usage Examples

From card definitions:
- Dan's "Legendary Taunt": Critical on specific conditions
- C. Viper's "Thunder Knuckle": Set up critical for next attack
- Akuma's "Demon Armageddon": Critical with power bonuses
- Various character exceed effects: Critical when exceeded