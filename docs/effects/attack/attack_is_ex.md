# attack_is_ex

**Category**: Attack
**Description**: Make the current attack an EX attack. EX attacks have enhanced properties and typically cost force to use.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution
- `set_strike` - When setting a strike

## Examples

**Basic EX conversion:**
```json
{
  "timing": "during_strike",
  "effect_type": "attack_is_ex"
}
```

**Set as EX when striking:**
```json
{
  "timing": "set_strike",
  "effect_type": "attack_is_ex"
}
```

**Combined with other effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "attack_is_ex",
  "and": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.ex = true`
- EX attacks often have enhanced damage, range, or special properties
- Can trigger conditional effects that check for EX status
- May interact with force generation and spending mechanics
- Some effects specifically enhance EX attacks further
- Can be combined with other attack modifiers

## Related Effects

- [critical](critical.md) - Make attack critical
- [attack_copy_gauge_or_transform_becomes_ex](attack_copy_gauge_or_transform_becomes_ex.md) - Copied attacks become EX
- [rangeup_if_ex_modifier](../stats/rangeup_if_ex_modifier.md) - Range bonus if EX
- [force_for_effect](../gauge/force_for_effect.md) - Spend force for EX properties

## Real Usage Examples

From card definitions:
- Various character force-spending effects: EX versions of normal attacks
- Ryu's "Hadoken" EX version: Enhanced projectile properties
- Ken's "Shoryuken" EX: Increased damage and invincibility
- Universal EX attack mechanics across fighting game characters