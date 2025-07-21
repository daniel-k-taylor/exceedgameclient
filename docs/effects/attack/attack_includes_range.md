# attack_includes_range

**Category**: Attack
**Description**: Expand the attack's range to include additional spaces beyond its normal range.

## Parameters

- `amount` (required): The additional range to include
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Special Values**: None

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic range extension:**
```json
{
  "timing": "during_strike",
  "effect_type": "attack_includes_range",
  "amount": 1
}
```

**Large range extension:**
```json
{
  "timing": "during_strike",
  "effect_type": "attack_includes_range",
  "amount": 3
}
```

**Conditional range boost:**
```json
{
  "condition": "is_critical",
  "effect_type": "attack_includes_range",
  "amount": 2
}
```

## Implementation Notes

- Appends to `strike_stat_boosts.attack_includes_ranges` array
- Extends attack's effective range by the specified amount
- Can be applied multiple times to stack range extensions
- Works with any attack type (normal, special, ultra)
- Range extension applies to hit detection and targeting
- Does not affect movement or positioning, only attack reach
- Useful for long-reach weapons, extending projectiles, or area effects

## Related Effects

- [rangeup](../stats/rangeup.md) - Increase printed range
- [range_includes_if_moved_past](range_includes_if_moved_past.md) - Conditional range extension
- [range_includes_lightningrods](range_includes_lightningrods.md) - Include lightningrod spaces
- [invert_range](invert_range.md) - Reverse range targeting

## Real Usage Examples

From card definitions:
- Nine's "Rhododendron Burst": `{ "timing": "during_strike", "effect_type": "attack_includes_range", "amount": 1 }`
- Various projectile attacks: Extended reach for ranged weapons
- Area effect attacks: Expanding blast radius or sweep range
- Critical hit extensions: Extra reach when landing critical strikes