# boost_then_sustain_topdeck

**Category**: Boost
**Description**: Boost the top card of the deck and optionally sustain it.

## Parameters

- `amount` (required): Number of cards to boost from top of deck
  - **Type**: Integer
  - **Range**: Any positive integer
- `sustain` (optional): Whether to sustain the boost
  - **Type**: Boolean
  - **Default**: true
- `discard_if_not_continuous` (optional): Discard top deck card if it's not continuous
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `during_strike` - During strike resolution (expected timing)

## Examples

**Basic boost topdeck with sustain:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain_topdeck",
  "amount": 1
}
```

**Boost multiple cards from topdeck:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain_topdeck",
  "amount": 2
}
```

**Boost topdeck without sustaining:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain_topdeck",
  "amount": 1,
  "sustain": false
}
```

**Discard non-continuous cards:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain_topdeck",
  "amount": 1,
  "discard_if_not_continuous": true
}
```

## Implementation Notes

- Expected to be used mid-strike (asserts [`active_strike`](../../scenes/core/local_game.gd:2147) is true)
- Gets top deck card with [`performing_player.get_top_deck_card()`](../../scenes/core/local_game.gd:2148)
- If [`discard_if_not_continuous`](../../scenes/core/local_game.gd:2151) is true, discards non-continuous cards
- Sets [`cancel_blocked_this_turn`](../../scenes/core/local_game.gd:2160) to true
- Uses [`DecisionType_ForceBoostSustainTopdeck`](../../scenes/core/local_game.gd:2163) decision type
- Sets forced boost parameters on [`active_strike`](../../scenes/core/local_game.gd:2165) object
- Logs message if no cards available in deck
- Enables deck-based boost strategies without hand dependency

## Related Effects

- [boost_then_sustain_topdiscard](boost_then_sustain_topdiscard.md) - Boost from discard pile
- [boost_then_sustain](boost_then_sustain.md) - Boost from hand with sustain
- [topdeck](../cards/topdeck.md) - Move cards to top of deck
- [sustain_all_boosts](sustain_all_boosts.md) - Keep all boosts active

## Real Usage Examples

From card definitions:
- Cards that provide boost value from deck manipulation
- Effects that turn deck resources into immediate boost power
- Strategic abilities that bypass hand limitations
- Combo effects that utilize deck positioning for boost access