# attack_copy_gauge_or_transform_becomes_ex

**Category**: Attack
**Description**: Mark that attacks copied from gauge or transformed attacks should become EX versions.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `on_strike_reveal` - When strike is revealed
- `during_strike` - During strike resolution

## Examples

**Basic EX transformation marker:**
```json
{
  "timing": "on_strike_reveal",
  "effect_type": "attack_copy_gauge_or_transform_becomes_ex",
  "hide_effect": true
}
```

**Visible EX upgrade:**
```json
{
  "timing": "during_strike",
  "effect_type": "attack_copy_gauge_or_transform_becomes_ex"
}
```

**Combined with transform effects:**
```json
{
  "timing": "on_strike_reveal",
  "effect_type": "attack_copy_gauge_or_transform_becomes_ex",
  "and": {
    "effect_type": "transform_attack",
    "card_name": "Enhanced Version"
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.attack_copy_gauge_or_transform_becomes_ex = true`
- Affects attacks that are copied from gauge or transformed
- Automatically upgrades qualifying attacks to EX versions
- Often used with `hide_effect: true` for invisible upgrades
- Interacts with gauge copying and transformation mechanics
- Provides automatic EX enhancement for specific conditions
- Used in character-specific upgrade mechanics

## Related Effects

- [attack_is_ex](attack_is_ex.md) - Make attack EX directly
- [transform_attack](transform_attack.md) - Transform attack properties
- [strike_from_gauge](../special/strike_from_gauge.md) - Strike using gauge cards
- [copy_other_hit_effect](copy_other_hit_effect.md) - Copy hit effects

## Real Usage Examples

From card definitions:
- Kokonoe's "Graviton Rage": `{ "timing": "on_strike_reveal", "effect_type": "attack_copy_gauge_or_transform_becomes_ex", "hide_effect": true }`
- Character-specific enhancement mechanics: Automatic EX upgrades
- Gauge interaction effects: Enhanced versions when copying from gauge
- Transformation synergies: EX benefits for transformed attacks