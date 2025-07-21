# add_top_deck_to_gauge

**Category**: Gauge
**Description**: Move cards from top of deck to gauge. Cards are transferred from deck to gauge pile.

## Parameters

- `amount` (optional): Number of cards to move
  - **Type**: Integer or String
  - **Default**: 1
  - **Special Values**:
    - `"num_discarded_card_ids"` - Number based on discarded card IDs
    - `"force_spent_this_turn"` - Cards equal to force spent
- `opponent` (optional): Affects opponent's deck/gauge instead
  - **Type**: Boolean
  - **Default**: false
- `discarded_card_ids` (optional): Used with "num_discarded_card_ids"
  - **Type**: Array of card IDs

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `cleanup` - During cleanup phase

## Examples

**Basic gauge addition:**
```json
{
  "timing": "now",
  "effect_type": "add_top_deck_to_gauge",
  "amount": 1
}
```

**Multiple cards to gauge:**
```json
{
  "timing": "immediate",
  "effect_type": "add_top_deck_to_gauge",
  "amount": 2
}
```

**Force-based gauge:**
```json
{
  "timing": "cleanup",
  "effect_type": "add_top_deck_to_gauge",
  "amount": "force_spent_this_turn"
}
```

**Opponent's deck to gauge:**
```json
{
  "timing": "now",
  "effect_type": "add_top_deck_to_gauge",
  "amount": 1,
  "opponent": true
}
```

## Implementation Notes

- Cards are moved from top of deck to gauge
- If deck has fewer cards than amount, moves all available cards
- May trigger reshuffle if deck becomes empty and more cards needed
- Creates appropriate log message for gauge addition
- Often used for resource generation and deck manipulation

## Related Effects

- [add_top_discard_to_gauge](add_top_discard_to_gauge.md) - Move discard to gauge
- [gauge_from_hand](gauge_from_hand.md) - Move hand cards to gauge
- [add_hand_to_gauge](add_hand_to_gauge.md) - Move entire hand to gauge
- [gauge_for_effect](gauge_for_effect.md) - Spend gauge for effects

## Real Usage Examples

From card definitions:
- Seijun's "Exceed": `{ "timing": "start_of_next_turn", "effect_type": "add_top_deck_to_gauge", "amount": 1 }`
- Various resource generation effects across characters
- End-of-turn gauge building mechanics
- Force-spending rewards and cleanup effects