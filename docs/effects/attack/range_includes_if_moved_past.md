# range_includes_if_moved_past

**Category**: Attack
**Description**: Attack range includes spaces if the character moved past them during this turn's movement.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution
- `before` - Before strike resolution

## Examples

**Basic moved-past targeting:**
```json
{
  "timing": "during_strike",
  "effect_type": "range_includes_if_moved_past"
}
```

**Pre-strike range setup:**
```json
{
  "timing": "before",
  "effect_type": "range_includes_if_moved_past"
}
```

**Combined with other range effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "range_includes_if_moved_past",
  "and": {
    "effect_type": "attack_includes_range",
    "amount": 1
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.range_includes_if_moved_past = true`
- Tracks spaces the character moved through during the current turn
- Expands attack range to include those traversed spaces
- Useful for sweep attacks, trail effects, or motion-based strikes
- Works with any type of movement (advance, retreat, teleport, etc.)
- Range extension is calculated based on actual movement path
- Does not include starting or ending position unless explicitly moved past

## Related Effects

- [attack_includes_range](attack_includes_range.md) - Fixed range extension
- [range_includes_lightningrods](range_includes_lightningrods.md) - Include lightningrod spaces
- [invert_range](invert_range.md) - Reverse range targeting
- [advance](../movement/advance.md) - Forward movement that can trigger this

## Real Usage Examples

From card definitions:
- Cammy's "Cannon Spike": `{ "timing": "during_strike", "effect_type": "range_includes_if_moved_past" }`
- Various rushing attacks: Hit targets passed during charge
- Sweep and cleave attacks: Strike along movement path
- Dash attacks: Hit everything along the dash route