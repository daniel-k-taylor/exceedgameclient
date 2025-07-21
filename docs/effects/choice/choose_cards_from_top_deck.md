# choose_cards_from_top_deck

**Category**: Choice and Selection
**Description**: Look at the top cards of your deck and choose which ones to take to hand, with remaining cards going to bottom of deck.

## Parameters

- `look_amount` (required): Number of cards to look at from the top of deck
  - **Type**: Integer
  - **Range**: 1 or higher
  - **Note**: Limited by actual deck size
- `choose_amount` (optional): Number of cards to choose from those looked at
  - **Type**: Integer
  - **Default**: 1
- `destination` (optional): Where chosen cards go
  - **Type**: String
  - **Default**: "hand"
  - **Values**: "hand", "gauge", "discard", "overdrive"
- `bottom_deck_destination` (optional): Where unchosen cards go
  - **Type**: String
  - **Default**: "bottom_deck"
  - **Values**: "bottom_deck", "discard", "shuffle_into_deck"
- `condition_details` (optional): Special handling for card selection
  - **Type**: String
  - **Values**: "add_to_hand", "add_to_gauge"

## Supported Timings

- `immediate` - Immediately when triggered
- `now` - Immediately when played
- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution
- `cleanup` - During cleanup phase

## Examples

**Basic card selection:**
```json
{
  "timing": "immediate",
  "effect_type": "choose_cards_from_top_deck",
  "look_amount": 3
}
```

**Multiple card selection:**
```json
{
  "timing": "immediate",
  "effect_type": "choose_cards_from_top_deck",
  "look_amount": 5,
  "choose_amount": 2
}
```

**Cards to gauge:**
```json
{
  "timing": "hit",
  "effect_type": "choose_cards_from_top_deck",
  "look_amount": 2,
  "destination": "gauge"
}
```

**Large deck look:**
```json
{
  "timing": "hit",
  "effect_type": "choose_cards_from_top_deck",
  "look_amount": 30
}
```

**Conditional card handling:**
```json
{
  "timing": "immediate",
  "condition_details": "add_to_hand",
  "effect_type": "choose_cards_from_top_deck",
  "look_amount": 2
}
```

## Implementation Notes

- If look_amount exceeds deck size, looks at all remaining cards in deck
- Player sees all looked-at cards and chooses which ones to take
- Unchosen cards are placed at bottom of deck in the order they were revealed
- Creates a decision state with card selection interface
- If choose_amount is not specified, player chooses exactly 1 card
- If no cards are available to look at, effect has no impact
- Can trigger deck reshuffling if deck becomes empty during selection

## Related Effects

- [draw](../cards/draw.md) - Draw cards without choice
- [reveal_topdeck](../cards/reveal_topdeck.md) - Reveal without selection
- [choice](choice.md) - Basic choice mechanism
- [add_top_deck_to_gauge](../gauge/add_top_deck_to_gauge.md) - Direct deck manipulation

## Real Usage Examples

From card definitions:
- Faust's character action: Choose 1 card from top 2 for hand
- Bang's boost effects: Select cards from top deck for strategic advantage
- Morathi's conditional effects: Choose cards when certain conditions are met
- Various character ultimates: Large deck looks (30 cards) for powerful selection
- Deck manipulation cards: Choose which cards to keep vs send to bottom