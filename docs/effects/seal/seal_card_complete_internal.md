# SealCardCompleteInternal

**Category**: Seal and Transform
**Description**: Internal effect that completes the sealing process by actually moving a specific card to the sealed area.

## Parameters

- `seal_card_id` (required): The ID of the card to be sealed
  - **Type**: Integer
  - **Range**: Any valid card ID
- `source` (optional): The source location from which to move the card
  - **Type**: String
  - **Default**: "" (add directly to sealed without moving from source)
  - **Values**: "hand", "deck", "discard", "gauge", etc.
- `silent` (optional): Whether to perform the sealing silently without log messages
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `immediate` - Applied immediately when triggered
- Can be used at any timing where sealing is valid

## Examples

**Complete sealing from hand:**
```json
{
  "effect_type": "seal_card_complete_internal",
  "seal_card_id": 12345,
  "source": "hand",
  "silent": false
}
```

**Silent sealing from deck:**
```json
{
  "effect_type": "seal_card_complete_internal",
  "seal_card_id": 67890,
  "source": "deck",
  "silent": true
}
```

**Direct addition to sealed (no source):**
```json
{
  "effect_type": "seal_card_complete_internal",
  "seal_card_id": 54321,
  "silent": false
}
```

## Implementation Notes

- This is the final step in the sealing process, typically called after [`SealCardInternal`](seal_card_internal.md)
- If a `source` is specified, the card is moved from that location to the sealed area
- If no `source` is specified, the card is added directly to the sealed area
- Respects the player's `sealed_area_is_secret` setting for logging
- Creates appropriate game events for UI updates
- The `silent` parameter controls whether log messages are generated
- Used internally by the game engine - not typically used directly in card definitions
- Handles the actual card movement and state updates

## Related Effects

- [`seal_card_internal`](seal_card_internal.md) - Initiates the sealing process
- [`seal_this`](seal_this.md) - High-level effect to seal current card
- [`seal_topdeck`](seal_topdeck.md) - Seals top card of deck
- [`seal_hand`](seal_hand.md) - Seals entire hand

## Real Usage Examples

From implementation:
- Called automatically by [`SealCardInternal`](seal_card_internal.md) after processing "on_seal" effects
- Used by the game engine to complete sealing operations from various sources
- Handles both visible and secret sealed areas appropriately
- Strategic context: The final mechanism that ensures cards are properly moved to the sealed area and all game state is updated correctly