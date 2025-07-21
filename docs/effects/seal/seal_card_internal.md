# SealCardInternal

**Category**: Seal and Transform
**Description**: Internal effect that initiates the sealing process for a specific card and triggers "on_seal" character effects.

## Parameters

- `seal_card_id` (required): The ID of the card to be sealed
  - **Type**: Integer
  - **Range**: Any valid card ID
- `source` (optional): The source location of the card being sealed
  - **Type**: String
  - **Default**: "" (no specific source)
  - **Values**: "hand", "deck", "discard", "gauge", etc.
- `silent` (optional): Whether to seal the card silently without log messages
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `immediate` - Applied immediately when triggered
- Can be used at any timing where sealing is valid

## Examples

**Basic sealing from hand:**
```json
{
  "effect_type": "seal_card_internal",
  "seal_card_id": 12345,
  "source": "hand"
}
```

**Silent sealing:**
```json
{
  "effect_type": "seal_card_internal",
  "seal_card_id": 67890,
  "source": "deck",
  "silent": true
}
```

**Sealing without specific source:**
```json
{
  "effect_type": "seal_card_internal",
  "seal_card_id": 54321
}
```

## Implementation Notes

- This is an internal effect primarily used by the game engine
- Triggers any "on_seal" character effects before the actual sealing
- Sets up the decision_info.amount with the card ID for processing
- Automatically chains to [`SealCardCompleteInternal`](seal_card_complete_internal.md) to complete the sealing
- The `silent` parameter is passed through to the completion effect
- Character effects that trigger "on_seal" may create additional decisions or effects
- Not typically used directly in card definitions - use higher-level seal effects instead

## Related Effects

- [`seal_card_complete_internal`](seal_card_complete_internal.md) - Completes the sealing process
- [`seal_this`](seal_this.md) - High-level effect to seal current card
- [`seal_hand`](seal_hand.md) - Seals entire hand
- [`seal_topdeck`](seal_topdeck.md) - Seals top card of deck

## Real Usage Examples

From implementation:
- Called internally by other seal effects to handle the sealing process
- Used by the game engine when processing seal effects from various sources
- Triggers character-specific "on_seal" abilities automatically
- Strategic context: Part of the internal sealing mechanism that ensures proper handling of character abilities that respond to sealing events