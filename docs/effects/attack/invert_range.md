# invert_range

**Category**: Attack
**Description**: Reverse the attack's range, making it hit spaces on the opposite side of the character.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic range inversion:**
```json
{
  "timing": "during_strike",
  "effect_type": "invert_range"
}
```

**Conditional inversion:**
```json
{
  "condition": "is_critical",
  "effect_type": "invert_range"
}
```

**Combined with range extension:**
```json
{
  "timing": "during_strike",
  "effect_type": "invert_range",
  "and": {
	"effect_type": "attack_includes_range",
	"amount": 1
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.invert_range = true`
- Creates a log message indicating range inversion
- Flips the attack to target the opposite direction
- If normally attacking forward, will attack backward instead
- Range calculations are preserved but direction is reversed
- Useful for surprise attacks, defensive counters, or repositioning strikes
- Works with any attack type and range configuration

## Related Effects

- [attack_includes_range](attack_includes_range.md) - Extend attack range
- [range_includes_if_moved_past](range_includes_if_moved_past.md) - Movement-based range
- [range_includes_lightningrods](range_includes_lightningrods.md) - Lightningrod targeting
- [become_wide](become_wide.md) - Change character form

## Real Usage Examples

From card definitions:
- Various ninja/stealth characters: Backstab and surprise attack mechanics
- Defensive counter-attacks: Strike behind when being pressured
- Teleport attacks: Appearing behind the opponent
- Reversal techniques: Turning defensive positions into offensive opportunities