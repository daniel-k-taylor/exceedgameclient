# add_hand_to_gauge

**Category**: Gauge
**Description**: Add all cards from hand to gauge.

## Parameters

None - this effect takes no parameters and moves all cards currently in hand to gauge.

## Supported Timings

- `immediate` - Immediately when triggered
- `before` - Before strike resolution
- `after` - After strike resolution

## Examples

**Basic usage:**
```json
{
  "timing": "immediate",
  "effect_type": "add_hand_to_gauge"
}
```

**Before strike:**
```json
{
  "timing": "before",
  "effect_type": "add_hand_to_gauge"
}
```

**Chained with other effects:**
```json
{
  "timing": "before",
  "effect_type": "add_hand_to_gauge",
  "and": {
    "effect_type": "draw",
    "amount": 3
  }
}
```

## Implementation Notes

- Moves ALL cards from hand to gauge - no selection or limit
- Cards are added to gauge in hand order
- Does nothing if hand is empty
- Creates log message showing cards moved to gauge
- Often used for "all-in" style effects or character transformations
- Can dramatically change game state by converting hand resources to gauge resources

## Related Effects

- [gauge_from_hand](gauge_from_hand.md) - Choose specific cards from hand to add to gauge
- [add_bottom_discard_to_gauge](add_bottom_discard_to_gauge.md) - Add from discard instead
- [add_to_gauge_immediately](add_to_gauge_immediately.md) - Add specific cards to gauge
- [draw](../cards/draw.md) - Refill hand after using this effect

## Real Usage Examples

From card definitions:
- Character ultimate abilities that convert entire hand to gauge for massive effects
- Transformation effects that shift from hand-based to gauge-based play
- "Desperation" moves that sacrifice hand for immediate gauge power