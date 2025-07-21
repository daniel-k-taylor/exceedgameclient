# strike

**Category**: Special
**Description**: Force a strike to occur. Initiates strike resolution, often used to chain attacks or force immediate combat.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `after` - After current strike resolution
- Various timing contexts where strikes can be initiated

## Examples

**Basic forced strike:**
```json
{
  "timing": "immediate",
  "effect_type": "strike"
}
```

**Strike after movement:**
```json
{
  "timing": "before",
  "effect_type": "close",
  "amount": 1,
  "and": {
    "effect_type": "strike"
  }
}
```

**Post-action strike:**
```json
{
  "timing": "now",
  "effect_type": "draw",
  "amount": 1,
  "and": {
    "effect_type": "strike"
  }
}
```

## Implementation Notes

- Initiates a new strike sequence
- Both players select attacks and resolve normally
- Can create multi-hit combos and follow-up attacks
- May interrupt normal turn flow
- Used for aggressive rush-down mechanics
- Can be chained with movement and setup effects

## Related Effects

- [pass](pass.md) - Do nothing (opposite effect)
- [strike_faceup](strike_faceup.md) - Strike with revealed attacks
- [strike_from_gauge](strike_from_gauge.md) - Strike using gauge cards
- [bonus_action](bonus_action.md) - Additional actions before striking

## Real Usage Examples

From card definitions:
- Ryu's "Exceed": Close then strike combinations
- Ken's aggressive rush effects: Movement into immediate strike
- Various combo and pressure mechanics across fighting game characters
- Follow-up attack systems and multi-hit sequences