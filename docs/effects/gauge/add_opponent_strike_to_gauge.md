# add_opponent_strike_to_gauge

**Category**: Gauge
**Description**: After the strike resolves, the opponent's strike card will be added to your gauge instead of their discard pile.

## Parameters

None - this effect sets a flag that affects strike cleanup behavior.

## Supported Timings

- `during_strike` - During strike resolution
- `before` - Before strike resolution
- `hit` - When attack hits

## Examples

**Basic usage:**
```json
{
  "timing": "during_strike",
  "effect_type": "add_opponent_strike_to_gauge"
}
```

**On hit effect:**
```json
{
  "timing": "hit",
  "effect_type": "add_opponent_strike_to_gauge"
}
```

**Combined with other effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "add_opponent_strike_to_gauge",
  "and": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

## Implementation Notes

- Sets a flag (`move_strike_to_opponent_gauge = true`) on the opposing player
- Only affects the current strike - the flag is reset after strike cleanup
- The opponent's strike card goes to YOUR gauge, not theirs
- This happens during strike cleanup, after all other strike effects resolve
- Creates log message when the card is moved
- Powerful effect as it both denies the opponent their strike in discard and gives you gauge
- Does not affect your own strike card placement

## Related Effects

- [add_strike_to_gauge_after_cleanup](add_strike_to_gauge_after_cleanup.md) - Add your own strike to gauge
- [add_strike_to_overdrive_after_cleanup](add_strike_to_overdrive_after_cleanup.md) - Similar mechanic for overdrive
- [gauge_for_effect](gauge_for_effect.md) - Spend gauge for effects

## Real Usage Examples

From card definitions:
- Steal effects that punish opponent's powerful strikes by taking them
- Absorption abilities that convert opponent's attacks into your resources
- Counter-attacks that turn opponent's aggression against them