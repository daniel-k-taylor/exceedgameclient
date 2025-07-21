# copy_other_hit_effect

**Category**: Attack
**Description**: Copy one of the hit effects from other effects in the same attack, allowing the player to choose which effect to duplicate.

## Parameters

None - this effect has no parameters. The choice is made during resolution.

## Supported Timings

- `hit` - When attack hits

## Examples

**Basic effect copying:**
```json
{
  "timing": "hit",
  "effect_type": "copy_other_hit_effect"
}
```

**Combined with multiple hit effects:**
```json
{
  "timing": "hit",
  "effect_type": "powerup",
  "amount": 2,
  "and": {
    "effect_type": "advance",
    "amount": 1,
    "and": {
      "effect_type": "copy_other_hit_effect"
    }
  }
}
```

**Conditional copying:**
```json
{
  "condition": "is_critical",
  "effect_type": "copy_other_hit_effect"
}
```

## Implementation Notes

- Scans all other hit effects in the same attack for copying options
- Excludes other `copy_other_hit_effect` instances to prevent infinite loops
- Creates a choice decision for the player to select which effect to copy
- Copied effect is executed immediately after selection
- Useful for versatile attacks that can adapt to different situations
- Player choice allows tactical decision-making during combat
- Effect must have other hit effects present to function

## Related Effects

- [choice](../choice/choice.md) - General choice mechanics
- [transform_attack](transform_attack.md) - Transform entire attack
- [attack_copy_gauge_or_transform_becomes_ex](attack_copy_gauge_or_transform_becomes_ex.md) - Copy/transform EX effects
- Any hit timing effects - Potential targets for copying

## Real Usage Examples

From card definitions:
- Linne's "Kuuga": `{ "timing": "hit", "effect_type": "copy_other_hit_effect" }`
- Versatile combo attacks: Multiple options with additional copying
- Adaptive strikes: Choose the most beneficial effect to repeat
- Strategic flexibility: Doubling down on successful hit effects