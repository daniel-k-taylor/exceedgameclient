# rangeup

**Category**: Stats
**Description**: Increase range by specified amount for this strike. Range determines which opponent positions can be hit.

## Parameters

- `amount` (required): Amount of range to add
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic range increase:**
```json
{
  "timing": "during_strike",
  "effect_type": "rangeup",
  "amount": 1
}
```

**Large range boost:**
```json
{
  "timing": "during_strike",
  "effect_type": "rangeup",
  "amount": 3
}
```

**Conditional range:**
```json
{
  "timing": "during_strike",
  "condition": "opponent_in_close_range",
  "effect_type": "rangeup",
  "amount": 2
}
```

## Implementation Notes

- Range bonus is applied to `strike_stat_boosts.range`
- Stacks with other range effects
- Extends the maximum range of the attack
- Can make previously out-of-range attacks hit
- Often used for reach extension and zoning control
- Some attacks have special range calculation modifiers

## Related Effects

- [rangeup_per_boost_in_play](rangeup_per_boost_in_play.md) - Range based on boosts
- [rangeup_per_force_spent_this_turn](rangeup_per_force_spent_this_turn.md) - Range based on force spent
- [rangeup_both_players](rangeup_both_players.md) - Range increase for both players
- [attack_includes_range](../attack/attack_includes_range.md) - Include additional specific range

## Real Usage Examples

From card definitions:
- Axl's "Rensen": `{ "timing": "during_strike", "effect_type": "rangeup", "amount": 2 }`
- Dhalsim-style long-range attacks: Range extension for zoning
- Gordeau's scythe attacks: Weapon reach enhancement
- Various projectile and long-range abilities