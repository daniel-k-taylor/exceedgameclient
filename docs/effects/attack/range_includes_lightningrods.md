# range_includes_lightningrods

**Category**: Attack
**Description**: Attack range includes all spaces containing lightningrods, regardless of distance.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic lightningrod targeting:**
```json
{
  "timing": "during_strike",
  "effect_type": "range_includes_lightningrods"
}
```

**Combined with other attack effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "range_includes_lightningrods",
  "and": {
    "effect_type": "critical"
  }
}
```

**Conditional lightningrod strike:**
```json
{
  "condition": "is_ex",
  "effect_type": "range_includes_lightningrods"
}
```

## Implementation Notes

- Sets `strike_stat_boosts.range_includes_lightningrods = true`
- Expands attack range to include any space with a lightningrod
- Works regardless of normal range limitations
- Useful for electrical attacks, chain lightning, or remote strikes
- Lightningrods must be placed by other effects first
- Can hit multiple lightningrod locations simultaneously
- Range extension ignores distance and positioning constraints

## Related Effects

- [place_lightningrod](../buddy/place_lightningrod.md) - Place lightningrods on the board
- [attack_includes_range](attack_includes_range.md) - Fixed range extension
- [range_includes_if_moved_past](range_includes_if_moved_past.md) - Movement-based range
- [invert_range](invert_range.md) - Reverse range targeting

## Real Usage Examples

From card definitions:
- Nine's "Lightning Magic": `{ "timing": "during_strike", "effect_type": "range_includes_lightningrods" }`
- Electric-themed characters: Chain lightning and electrical discharge attacks
- Tesla coil effects: Remote electrical strikes
- Area denial strategies: Hitting placed lightningrods for board control