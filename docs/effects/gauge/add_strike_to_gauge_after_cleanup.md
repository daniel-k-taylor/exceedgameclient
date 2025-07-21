# add_strike_to_gauge_after_cleanup

**Category**: Gauge
**Description**: After the strike resolves, your strike card will be added to gauge instead of the discard pile.

## Parameters

None - this effect sets a flag that affects strike cleanup behavior.

## Supported Timings

- `during_strike` - During strike resolution
- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic usage:**
```json
{
  "timing": "during_strike",
  "effect_type": "add_strike_to_gauge_after_cleanup"
}
```

**On hit effect:**
```json
{
  "timing": "hit",
  "effect_type": "add_strike_to_gauge_after_cleanup"
}
```

**Combined with other effects:**
```json
{
  "timing": "before",
  "effect_type": "add_strike_to_gauge_after_cleanup",
  "and": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

## Implementation Notes

- Sets a flag (`always_add_to_gauge = true`) on the performing player
- Only affects the current strike - the flag is reset after strike cleanup
- YOUR strike card goes to your gauge instead of discard
- This happens during strike cleanup, after all other strike effects resolve
- For extra attacks, sets `extra_attack_always_go_to_gauge = true` instead
- Creates log message when the card is moved
- Useful for building gauge while attacking
- Does not affect opponent's strike card placement

## Related Effects

- [add_opponent_strike_to_gauge](add_opponent_strike_to_gauge.md) - Move opponent's strike to your gauge
- [add_strike_to_overdrive_after_cleanup](add_strike_to_overdrive_after_cleanup.md) - Similar mechanic for overdrive
- [gauge_for_effect](gauge_for_effect.md) - Spend gauge for effects

## Real Usage Examples

From card definitions:
- Attack cards that build gauge while dealing damage
- Combo finishers that prepare resources for follow-up turns
- Strategic attacks that convert offense into long-term advantage