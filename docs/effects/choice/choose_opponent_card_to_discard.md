# choose_opponent_card_to_discard

**Category**: Choice and Selection
**Description**: Allow player to choose which cards the opponent must discard from their hand.

## Parameters

- `amount` (optional): Number of cards opponent must discard
  - **Type**: Integer
  - **Default**: 1
- `limitation` (optional): Restrict card types that can be discarded
  - **Type**: String
  - **Values**: "special", "continuous", "normal", ""
- `opponent` (optional): Used for control transfer mechanics
  - **Type**: Boolean
  - **Note**: Special parameter for certain character mechanics

## Supported Timings

- `immediate` - Immediately when triggered
- `hit` - When attack hits
- `after` - After strike resolution
- `before` - Before strike resolution
- `cleanup` - During cleanup phase

## Examples

**Basic opponent discard:**
```json
{
  "timing": "hit",
  "effect_type": "choose_opponent_card_to_discard"
}
```

**Multiple card selection:**
```json
{
  "timing": "hit",
  "effect_type": "choose_opponent_card_to_discard",
  "amount": 2
}
```

**Discard with limitation:**
```json
{
  "timing": "immediate",
  "effect_type": "choose_opponent_card_to_discard",
  "limitation": "special"
}
```

**As part of choice effect:**
```json
{
  "timing": "hit",
  "effect_type": "choice",
  "choice": [
    { "effect_type": "choose_opponent_card_to_discard" },
    { "effect_type": "take_damage", "amount": 1 }
  ]
}
```

**Control transfer variant:**
```json
{
  "discard_effect": {
    "effect_type": "choose_opponent_card_to_discard",
    "opponent": true
  }
}
```

## Implementation Notes

- Creates a decision state where the active player chooses cards from opponent's hand
- Opponent's hand is revealed to the choosing player for selection
- If limitation is specified, only matching card types are selectable
- Empty limitation ("") allows selection from any cards in hand
- If opponent has fewer cards than amount requested, all available cards are discarded
- No effect if opponent's hand is empty
- Automatically transitions to ChooseOpponentCardToDiscardInternal for execution
- The opponent parameter can transfer control for special character mechanics

## Related Effects

- [choose_opponent_card_to_discard_internal](choose_opponent_card_to_discard_internal.md) - Internal execution effect
- [choose_discard](choose_discard.md) - Choose your own cards to discard
- [opponent_discard_choose](../cards/opponent_discard_choose.md) - Opponent chooses their own discard
- [reveal_hand](../cards/reveal_hand.md) - Reveal hand without discard

## Real Usage Examples

From card definitions:
- Hit effects on powerful attacks: Force opponent to discard valuable cards
- Enchantress spell effects: Choose specific cards to discard with control transfer
- Punishment mechanics: Make opponent discard after certain conditions
- Control/disruption strategies: Target opponent's key cards for removal
- Choice-based effects: Offer opponent discard as alternative to other penalties