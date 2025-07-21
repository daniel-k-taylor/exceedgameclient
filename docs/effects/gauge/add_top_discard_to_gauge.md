# add_top_discard_to_gauge

**Category**: Gauge
**Description**: Move cards from top of discard pile to gauge. Transfers discarded cards to gauge for later use.

## Parameters

- `amount` (optional): Number of cards to move
  - **Type**: Integer
  - **Default**: 1
- `opponent` (optional): Affects opponent's discard/gauge instead
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `cleanup` - During cleanup phase

## Examples

**Basic discard to gauge:**
```json
{
  "timing": "now",
  "effect_type": "add_top_discard_to_gauge",
  "amount": 1
}
```

**Multiple cards:**
```json
{
  "timing": "immediate",
  "effect_type": "add_top_discard_to_gauge",
  "amount": 2
}
```

**Opponent's discard:**
```json
{
  "timing": "cleanup",
  "effect_type": "add_top_discard_to_gauge",
  "opponent": true
}
```

## Implementation Notes

- Moves most recently discarded cards to gauge
- If discard has fewer cards than amount, moves all available
- Used for resource recovery and gauge building
- Creates appropriate log message

## Related Effects

- [add_top_deck_to_gauge](add_top_deck_to_gauge.md) - Move deck to gauge
- [add_bottom_discard_to_gauge](add_bottom_discard_to_gauge.md) - Move bottom discard to gauge
- [gauge_from_hand](gauge_from_hand.md) - Move hand to gauge

## Real Usage Examples

From card definitions:
- Resource recovery effects
- Gauge building mechanics
- Cleanup and recycling effects