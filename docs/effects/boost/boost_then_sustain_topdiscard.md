# boost_then_sustain_topdiscard

**Category**: Boost
**Description**: Boost the top continuous boost card from discard pile and optionally sustain it.

## Parameters

- `amount` (required): Number of cards to boost from discard pile
  - **Type**: Integer or String
  - **Range**: Any positive integer or "DISCARDED_COUNT"
  - **Special Values**: "DISCARDED_COUNT" - Use count of discarded cards from effect
- `sustain` (optional): Whether to sustain the boost
  - **Type**: Boolean
  - **Default**: true
- `discarded_card_ids` (optional): Array of card IDs that were discarded (used with "DISCARDED_COUNT")
  - **Type**: Array of integers
  - **Default**: Empty array

## Supported Timings

- `during_strike` - During strike resolution (expected timing)

## Examples

**Basic boost top discard with sustain:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain_topdiscard",
  "amount": 1
}
```

**Boost multiple cards from discard:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain_topdiscard",
  "amount": 2
}
```

**Boost topdiscard without sustaining:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain_topdiscard",
  "amount": 1,
  "sustain": false
}
```

**Boost based on discarded count:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain_topdiscard",
  "amount": "DISCARDED_COUNT",
  "discarded_card_ids": [123, 456]
}
```

## Implementation Notes

- Expected to be used mid-strike (asserts [`active_strike`](../../scenes/core/local_game.gd:2173) is true)
- Gets top continuous boost with [`get_top_continuous_boost_in_discard()`](../../scenes/core/local_game.gd:2174)
- Only works with continuous boost cards in discard pile
- Sets [`cancel_blocked_this_turn`](../../scenes/core/local_game.gd:2179) to true
- Uses [`DecisionType_ForceBoostSustainTopDiscard`](../../scenes/core/local_game.gd:2182) decision type
- Can use [`"DISCARDED_COUNT"`](../../scenes/core/local_game.gd:2186) to boost based on number of discarded cards
- Sets forced boost parameters on [`active_strike`](../../scenes/core/local_game.gd:2184) object
- Logs message if no continuous boosts available in discard
- Enables graveyard-based boost strategies

## Related Effects

- [boost_then_sustain_topdeck](boost_then_sustain_topdeck.md) - Boost from top of deck
- [boost_then_sustain](boost_then_sustain.md) - Boost from hand with sustain
- [return_to_hand](../cards/return_to_hand.md) - Return cards from discard to hand
- [sustain_all_boosts](sustain_all_boosts.md) - Keep all boosts active

## Real Usage Examples

From card definitions:
- Cards that recycle previously used continuous boosts
- Effects that provide value from discard pile resources
- Graveyard recursion mechanics for boost effects
- Strategic abilities that reuse discarded continuous effects