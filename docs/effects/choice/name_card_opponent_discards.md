# name_card_opponent_discards

**Category**: Choice and Selection
**Description**: Player names a card, and if opponent has it in hand, they must discard the specified amount.

## Parameters

- `amount` (optional): Number of named cards opponent must discard
  - **Type**: Integer
  - **Default**: 1
- `discard_effect` (optional): Additional effect to execute when card is discarded
  - **Type**: Effect object
  - **Note**: Triggers only if opponent actually discards the named card
- `reveal_hand_after` (optional): Whether to reveal opponent's hand after the effect
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `immediate` - Immediately when triggered
- `hit` - When attack hits
- `before` - Before strike resolution
- `after` - After strike resolution

## Examples

**Basic card naming:**
```json
{
  "timing": "immediate",
  "effect_type": "name_card_opponent_discards"
}
```

**Multiple copies:**
```json
{
  "timing": "hit",
  "effect_type": "name_card_opponent_discards",
  "amount": 2
}
```

**With bonus effect:**
```json
{
  "timing": "immediate",
  "effect_type": "name_card_opponent_discards",
  "discard_effect": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

**Reveal hand after:**
```json
{
  "timing": "hit",
  "effect_type": "name_card_opponent_discards",
  "reveal_hand_after": true
}
```

**Chain with other effects:**
```json
{
  "timing": "immediate",
  "effect_type": "name_card_opponent_discards",
  "amount": 1,
  "discard_effect": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

## Implementation Notes

- Creates a decision state where player selects a card name from all possible cards
- Automatically transitions to NameCardOpponentDiscardsInternal for execution
- If opponent has the named card in hand, they must discard the specified amount
- If opponent has fewer copies than amount requested, they discard all copies they have
- No effect if opponent doesn't have the named card in hand
- discard_effect only triggers if at least one card was actually discarded
- reveal_hand_after shows opponent's remaining hand regardless of whether discard occurred
- Player must choose from valid card names in the game

## Related Effects

- [name_card_opponent_discards_internal](name_card_opponent_discards_internal.md) - Internal execution effect
- [choose_opponent_card_to_discard](choose_opponent_card_to_discard.md) - Choose visible cards to discard
- [opponent_discard_choose](../cards/opponent_discard_choose.md) - Opponent chooses own discard
- [reveal_hand](../cards/reveal_hand.md) - Reveal hand without discard

## Real Usage Examples

From card definitions:
- Enchantress spell effects: Name cards for strategic disruption
- Information warfare cards: Force discard specific threats
- Meta-game effects: Target known cards in opponent's strategy
- Combo disruption: Name key combo pieces to break opponent's plans
- Hand reveal combinations: Name card then reveal to confirm success