# ZeroVectorInternal

**Category**: Utility
**Description**: Internal implementation of zero vector choice resolution that makes named cards invalid during strikes.

## Parameters

- `card_id` (required): The ID of the card to make invalid
  - **Type**: Integer
  - **Range**: Valid card ID from the game database
  - **Usage**: References the chosen card to apply invalidation to

## Supported Timings

- Decision resolution - Automatically triggered when player makes zero vector choice

## Examples

**Internal usage (not directly used in card definitions):**
```json
{
  "effect_type": "zero_vector_internal",
  "card_id": 12345
}
```

## Implementation Notes

- This is an internal effect not directly used in card definitions
- Automatically invoked when resolving `zero_vector` decisions
- Retrieves the named card from the database using `card_id`
- Adds the card's display name to the opponent's `cards_invalid_during_strike` list
- Cards in the invalid list cannot be used during strike resolution
- Effect persists for the duration of the current strike sequence
- More restrictive than sidestep transparency - completely prevents card usage
- Only affects cards with the exact display name that was chosen

## Related Effects

- [`zero_vector`](zero_vector.md) - Main effect that triggers this internal resolution
- [`zero_vector_dialogue`](zero_vector_dialogue.md) - UI dialogue component for zero vector
- [`sidestep_internal`](sidestep_internal.md) - Similar internal card-naming mechanic with transparency

## Real Usage Examples

From card definitions:
- Not directly used in card definitions
- Automatically triggered by game system when player makes zero vector choice
- Internal resolution: Makes chosen cards completely unusable during active strikes