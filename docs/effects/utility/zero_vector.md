# ZeroVector

**Category**: Utility
**Description**: Allows the player to choose a card name to make invalid during strikes, preventing those cards from being used.

## Parameters

This effect takes no parameters.

## Supported Timings

- `now` - Immediately when the effect is triggered

## Examples

**Basic usage:**
```json
{
  "timing": "now",
  "effect_type": "zero_vector"
}
```

**With choice text:**
```json
{
  "text": "Name Card & Strike",
  "effect_type": "zero_vector",
  "and": {
    "effect_type": "strike_faceup"
  }
}
```

**Combined with dialogue:**
```json
{
  "timing": "now",
  "effect_type": "zero_vector"
},
{
  "timing": "during_strike",
  "effect_type": "zero_vector_dialogue"
}
```

## Implementation Notes

- Changes game state to PlayerDecision and creates a zero vector decision for the player
- Uses `DecisionType_ZeroVector` with effect type `ZeroVectorInternal` for resolution
- Creates a `EventType_Boost_ZeroVector` event for UI feedback
- The actual card naming and invalidation is handled by `ZeroVectorInternal`
- Player must choose a specific card name to make invalid during strikes
- Invalid cards cannot be used in strike sequences by the opponent
- More restrictive than sidestep (which makes cards transparent but still usable)

## Related Effects

- [`zero_vector_internal`](zero_vector_internal.md) - Internal implementation of the zero vector choice
- [`zero_vector_dialogue`](zero_vector_dialogue.md) - UI dialogue component for zero vector
- [`sidestep_transparent_foe`](sidestep_transparent_foe.md) - Similar card-naming mechanic with transparency

## Real Usage Examples

From card definitions:
- Character boost cards: `"timing": "now", "effect_type": "zero_vector"`
- Strategic disruption: Prevents opponent from using specific named cards
- Combo cards: Often combined with strikes like `"text": "Name Card & Strike", "effect_type": "zero_vector"`