# ignore_guard

**Category**: Attack
**Description**: Attack ignores opponent's guard. Damage is not reduced by opponent's guard points.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic guard ignore:**
```json
{
  "timing": "during_strike",
  "effect_type": "ignore_guard"
}
```

**Combined with other attack effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "ignore_guard",
  "and": {
    "effect_type": "ignore_armor"
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.ignore_guard = true`
- Only affects damage calculation for this strike
- Does not remove or reduce opponent's guard
- Guard still exists but provides no damage reduction
- Often found on piercing attacks, unblockable moves, or guard-breaking techniques
- Can be combined with other defensive penetration effects

## Related Effects

- [ignore_armor](ignore_armor.md) - Ignore opponent's armor
- [ignore_push_and_pull](ignore_push_and_pull.md) - Ignore push/pull effects
- [critical](critical.md) - Double damage
- [guardup](../stats/guardup.md) - Increase guard

## Real Usage Examples

From card definitions:
- Potemkin's "Heavenly Potemkin Buster": Unblockable command grab
- Various overhead and low attacks: Guard-breaking properties
- Nine's magic attacks: Spells that bypass conventional defense
- Command grabs and unblockable techniques across multiple characters