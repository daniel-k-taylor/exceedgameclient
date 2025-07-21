# remove_force_costs_reduced_passive

**Category**: Force
**Description**: Remove force cost reduction passive effects.

## Parameters

None - this effect removes all force cost reductions.

## Supported Timings

- `immediate` - Immediately when triggered
- `now` - Immediately when played
- `after` - After strike resolution

## Examples

**Basic removal:**
```json
{
  "timing": "immediate",
  "effect_type": "remove_force_costs_reduced_passive"
}
```

## Implementation Notes

- Removes all force cost reduction effects from the player
- Restores normal force costs for all actions
- Used to end cost reduction buffs
- Creates log message about effect removal

## Related Effects

- [force_costs_reduced_passive](force_costs_reduced_passive.md) - Add force cost reduction
- [remove_gauge_costs_reduced_passive](remove_gauge_costs_reduced_passive.md) - Remove gauge cost reduction
- [force_for_effect](force_for_effect.md) - Spend force for effects

## Real Usage Examples

From card definitions:
- End-of-turn cleanup effects
- Counters to cost reduction buffs
- Effect expiration management