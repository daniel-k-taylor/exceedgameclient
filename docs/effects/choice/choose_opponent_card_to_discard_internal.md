# choose_opponent_card_to_discard_internal

**Category**: Choice and Selection
**Description**: Internal effect that executes the actual discard of opponent cards selected by choose_opponent_card_to_discard.

## Parameters

- `card_ids` (required): Array of card IDs that were selected for discard
  - **Type**: Array of integers
  - **Note**: Generated automatically by the choice selection process

## Supported Timings

- `immediate` - Immediately when triggered (automatically)

## Examples

**Internal execution (automatically generated):**
```json
{
  "timing": "immediate",
  "effect_type": "choose_opponent_card_to_discard_internal",
  "card_ids": [123, 456]
}
```

## Implementation Notes

- This effect is automatically generated and should not be used directly in card definitions
- It serves as the execution phase after player selection in choose_opponent_card_to_discard
- Takes the card_ids selected by the player and performs the actual discard operation
- The opposing player's selected cards are moved to their discard pile
- Creates appropriate log messages for the discard action
- Part of the two-phase choice system: selection → execution

## Related Effects

- [choose_opponent_card_to_discard](choose_opponent_card_to_discard.md) - The selection phase effect
- [discard_random](../cards/discard_random.md) - Alternative discard without choice
- [opponent_discard_choose](../cards/opponent_discard_choose.md) - Opponent makes own choice

## Real Usage Examples

This effect is generated automatically by the game system and does not appear directly in card definitions. It is created when:
- Player completes selection in choose_opponent_card_to_discard
- Game needs to execute the actual discard operation
- Internal game state transitions require the discard to be processed