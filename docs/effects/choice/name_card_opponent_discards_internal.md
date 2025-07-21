# name_card_opponent_discards_internal

**Category**: Choice and Selection
**Description**: Internal effect that executes the actual discard of named cards after player selection in name_card_opponent_discards.

## Parameters

- `named_card_name` (required): The card name that was selected by the player
  - **Type**: String
  - **Note**: Generated automatically by the card naming process
- `amount` (required): Number of named cards to discard
  - **Type**: Integer
  - **Note**: Carried over from the original effect
- `discard_effect` (optional): Additional effect to execute when card is discarded
  - **Type**: Effect object
  - **Note**: Carried over from the original effect
- `reveal_hand_after` (optional): Whether to reveal opponent's hand after the effect
  - **Type**: Boolean
  - **Note**: Carried over from the original effect

## Supported Timings

- `immediate` - Immediately when triggered (automatically)

## Examples

**Internal execution (automatically generated):**
```json
{
  "timing": "immediate",
  "effect_type": "name_card_opponent_discards_internal",
  "named_card_name": "Hadoken",
  "amount": 1
}
```

**With bonus effect:**
```json
{
  "timing": "immediate",
  "effect_type": "name_card_opponent_discards_internal",
  "named_card_name": "Shoryuken",
  "amount": 2,
  "discard_effect": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

## Implementation Notes

- This effect is automatically generated and should not be used directly in card definitions
- It serves as the execution phase after card name selection in name_card_opponent_discards
- Searches opponent's hand for cards matching the named card name
- Discards up to the specified amount of matching cards found
- If fewer matching cards exist than amount requested, discards all available copies
- Executes discard_effect only if at least one card was actually discarded
- Reveals opponent's hand if reveal_hand_after is true
- Creates appropriate log messages for successful or failed discard attempts
- Part of the two-phase naming system: selection → execution

## Related Effects

- [name_card_opponent_discards](name_card_opponent_discards.md) - The selection phase effect
- [choose_opponent_card_to_discard_internal](choose_opponent_card_to_discard_internal.md) - Similar internal execution
- [reveal_hand](../cards/reveal_hand.md) - Hand revelation effect

## Real Usage Examples

This effect is generated automatically by the game system and does not appear directly in card definitions. It is created when:
- Player completes card name selection in name_card_opponent_discards
- Game needs to execute the actual search and discard operation
- Internal game state transitions require the named card effect to be processed