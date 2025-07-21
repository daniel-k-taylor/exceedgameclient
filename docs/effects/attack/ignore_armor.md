# ignore_armor

**Category**: Attack
**Description**: Attack ignores opponent's armor. Damage is not reduced by opponent's armor points.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic armor ignore:**
```json
{
  "timing": "during_strike",
  "effect_type": "ignore_armor"
}
```

**Combined with other attack effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "ignore_armor",
  "and": {
    "effect_type": "critical"
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.ignore_armor = true`
- Only affects damage calculation for this strike
- Does not remove or reduce opponent's armor
- Armor still exists but provides no damage reduction
- Often found on piercing attacks, magic damage, or armor-breaking moves
- Can be combined with other attack modifiers

## Related Effects

- [ignore_guard](ignore_guard.md) - Ignore opponent's guard
- [ignore_push_and_pull](ignore_push_and_pull.md) - Ignore push/pull effects
- [critical](critical.md) - Double damage
- [armorup](../stats/armorup.md) - Increase armor

## Real Usage Examples

From card definitions:
- Gordeau's "Grim Reaper": `{ "timing": "during_strike", "effect_type": "ignore_armor" }`
- Nine's "Rhododendron Burst": Magic attacks that pierce armor
- Various piercing projectiles and energy attacks
- Anti-armor techniques across multiple fighting game characters