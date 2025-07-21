# negate_boost

**Category**: Boost
**Description**: Negate the active boost effect and mark it for discard.

## Parameters

No parameters required.

## Supported Timings

- `during_strike` - During strike resolution
- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic boost negation:**
```json
{
  "timing": "during_strike",
  "effect_type": "negate_boost"
}
```

**Negate on hit:**
```json
{
  "timing": "hit",
  "effect_type": "negate_boost"
}
```

## Implementation Notes

- Requires an active boost to function (asserts [`active_boost`](../../scenes/core/local_game.gd:3435) is true)
- Creates log message indicating boost effect is negated
- Sets [`active_boost.boost_negated = true`](../../scenes/core/local_game.gd:3437)
- Sets [`active_boost.discard_on_cleanup = true`](../../scenes/core/local_game.gd:3438)
- Completely cancels the boost's effects for the current action
- Forces boost to be discarded rather than sustained
- Used for defensive or disruptive effects
- Can counter opponent boost strategies

## Related Effects

- [sustain_all_boosts](sustain_all_boosts.md) - Opposite effect that preserves boosts
- [sustain_this](sustain_this.md) - Sustain specific boosts
- [discard_continuous_boost](../cards/discard_continuous_boost.md) - Discard boost effects
- [boost_then_sustain](boost_then_sustain.md) - Boost with sustain protection

## Real Usage Examples

From card definitions:
- Defensive cards that counter opponent boosts
- Disruptive effects that neutralize enemy advantages
- Counter-play mechanics that respond to boost strategies
- Cards that punish aggressive boost usage