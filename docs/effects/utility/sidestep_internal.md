# SidestepInternal

**Category**: Utility
**Description**: Internal implementation of sidestep choice resolution that makes named cards transparent during strikes.

## Parameters

- `card_id` (required): The ID of the card to make transparent
  - **Type**: Integer
  - **Range**: Valid card ID from the game database
  - **Usage**: References the chosen card to apply transparency to

## Supported Timings

- Decision resolution - Automatically triggered when player makes sidestep choice

## Examples

**Internal usage (not directly used in card definitions):**
```json
{
  "effect_type": "sidestep_internal",
  "card_id": 12345
}
```

## Implementation Notes

- This is an internal effect not directly used in card definitions
- Automatically invoked when resolving `sidestep_transparent_foe` decisions
- Retrieves the named card from the database using `card_id`
- Adds the card's display name to the opponent's `cards_invalid_during_strike` list
- Cards in the invalid list are treated as transparent during strike resolution
- Effect persists for the duration of the current strike sequence
- Only affects cards with the exact display name that was chosen

## Related Effects

- [`sidestep_transparent_foe`](sidestep_transparent_foe.md) - Main effect that triggers this internal resolution
- [`sidestep_dialogue`](sidestep_dialogue.md) - UI dialogue component for sidestep
- [`zero_vector_internal`](zero_vector_internal.md) - Similar internal card-naming mechanic

## Real Usage Examples

From card definitions:
- Not directly used in card definitions
- Automatically triggered by game system when player makes sidestep choice
- Internal resolution: Makes chosen cards transparent during active strikes