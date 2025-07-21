# ReadingNormalInternal

**Category**: Seal and Transform
**Description**: Internal effect that implements the Reading mechanism by setting the opponent's reading card ID for future strike validation.

## Parameters

- `card_id` (required): The ID of the card that was chosen for the Reading effect
  - **Type**: Integer
  - **Range**: Any valid card ID

## Supported Timings

- `immediate` - Applied immediately when triggered by the Reading decision system
- Used internally by the game engine

## Examples

**Internal usage (called by game engine):**
```json
{
  "effect_type": "reading_normal_internal",
  "card_id": 12345
}
```

## Implementation Notes

- This is an internal effect called by the game system when a Reading Normal decision is made
- Sets the `reading_card_id` on the performing player to the specified card ID
- The opponent will then be forced to either:
  - Strike with the named card (if they have it in hand)
  - Reveal their hand (if they don't have the card)
- Not typically used directly in card definitions
- The effect establishes the constraint that will be checked during the opponent's next strike attempt
- Creates log messages describing which card was named for the Reading effect
- The Reading constraint persists until the opponent strikes or the Reading effect is resolved

## Related Effects

- [`reading_normal`](reading_normal.md) - Initiates the Reading effect
- [`strike_response_reading`](../special/strike_response_reading.md) - How opponents respond to Reading
- [`reveal_hand`](../cards/reveal_hand.md) - What happens if opponent can't strike with the named card

## Real Usage Examples

From implementation:
- Called automatically when a player chooses a card for Reading Normal effect
- Used by the game engine to establish Reading constraints
- Sets up the game state for opponent's forced choice between striking with named card or revealing hand
- Strategic context: Part of the internal Reading mechanism that enforces the "strike with this card or reveal your hand" constraint