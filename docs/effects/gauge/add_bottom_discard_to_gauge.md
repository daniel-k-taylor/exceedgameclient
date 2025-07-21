# add_bottom_discard_to_gauge

**Category**: Gauge
**Description**: Add cards from the bottom of the discard pile to gauge.

## Parameters

- `amount` (optional): Number of cards to move from bottom of discard pile to gauge
  - **Type**: Integer
  - **Default**: 1
  - **Range**: Any positive integer
  - **Note**: Limited by actual number of cards in discard pile

## Supported Timings

- `hit` - When attack hits
- `now` - Immediately when played
- `after` - After strike resolution

## Examples

**Basic usage (1 card):**
```json
{
  "timing": "hit",
  "effect_type": "add_bottom_discard_to_gauge"
}
```

**Multiple cards:**
```json
{
  "timing": "now",
  "effect_type": "add_bottom_discard_to_gauge",
  "amount": 3
}
```

**In choice effect:**
```json
{
  "timing": "now",
  "effect_type": "choice",
  "choice": [
    { "effect_type": "add_bottom_discard_to_gauge" },
    { "effect_type": "add_bottom_discard_to_hand" }
  ]
}
```

## Implementation Notes

- Takes cards from the bottom (oldest) of the discard pile
- Cards are moved to gauge in the order they were in discard pile
- If discard pile has fewer cards than requested amount, moves all available cards
- Creates appropriate log message showing which cards were moved
- Does nothing if discard pile is empty (logs message about no cards available)
- Uses the same underlying function as [`add_top_discard_to_gauge`](add_top_discard_to_gauge.md) with `from_bottom=true`

## Related Effects

- [add_bottom_discard_to_hand](add_bottom_discard_to_hand.md) - Same source, different destination
- [add_top_discard_to_gauge](add_top_discard_to_gauge.md) - Same destination, takes from top instead
- [gauge_for_effect](gauge_for_effect.md) - Spend gauge for effects
- [add_to_gauge_immediately](add_to_gauge_immediately.md) - Add specific cards to gauge

## Real Usage Examples

From card definitions:
- Choice effects offering resource management options
- Hit effects that reward successful attacks with gauge building
- Character abilities that recycle older discarded cards into gauge