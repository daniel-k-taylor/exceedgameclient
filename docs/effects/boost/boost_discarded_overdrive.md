# boost_discarded_overdrive

**Category**: Boost
**Description**: Boost the top card of the discard pile when an overdrive ends.

## Parameters

No parameters required.

## Supported Timings

- `during_strike` - During strike resolution
- `after` - After strike resolution

## Examples

**Basic overdrive discard boost:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_discarded_overdrive"
}
```

**Post-strike overdrive boost:**
```json
{
  "timing": "after",
  "effect_type": "boost_discarded_overdrive"
}
```

## Implementation Notes

- Requires an active overdrive to function (asserts `active_overdrive` is true)
- Sets a flag [`active_overdrive_boost_top_discard_on_cleanup`](../../scenes/core/local_game.gd:2028) instead of immediately boosting
- The actual boost happens during overdrive cleanup phase
- Cannot be used without an active overdrive effect
- Provides value from overdrive cards even after they are discarded
- Creates strategic decisions around overdrive timing and usage

## Related Effects

- [boost_as_overdrive](boost_as_overdrive.md) - Turn boost into overdrive
- [boost_as_overdrive_internal](boost_as_overdrive_internal.md) - Internal overdrive boost mechanics
- [boost_then_sustain](boost_then_sustain.md) - Sustain boost effects
- [sustain_all_boosts](sustain_all_boosts.md) - Keep all boosts active

## Real Usage Examples

From card definitions:
- Overdrive cards that provide followup value after being discarded
- Characters with overdrive-based strategies that maintain momentum
- Cards that turn overdrive disposal into resource generation
- Strategic effects that extend overdrive value beyond their immediate use