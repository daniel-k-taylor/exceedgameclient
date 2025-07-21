# armorup_damage_dealt

**Category**: Stats
**Description**: Gain armor equal to damage dealt by this attack. Defensive bonus based on offensive success.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic damage-based armor:**
```json
{
  "timing": "hit",
  "effect_type": "armorup_damage_dealt"
}
```

**Post-strike armor gain:**
```json
{
  "timing": "after",
  "effect_type": "armorup_damage_dealt"
}
```

## Implementation Notes

- Armor gained equals actual damage dealt to opponent
- Calculated after all damage reductions (armor, guard)
- Used for vampire-like sustain mechanics
- Creates armor gain log message
- Stacks with other armor effects

## Related Effects

- [armorup](armorup.md) - Basic armor increase
- [armorup_current_power](armorup_current_power.md) - Armor based on power
- [powerup_damagetaken](../stats/powerup_damagetaken.md) - Power based on damage taken

## Real Usage Examples

From card definitions:
- Vampire/lifesteal-style effects that provide defense
- Trading and sustain mechanics
- Risk/reward offensive abilities