# ZeroVectorDialogue

**Category**: Utility
**Description**: UI-only effect that provides dialogue feedback during zero vector mechanics.

## Parameters

This effect takes no parameters.

## Supported Timings

- `during_strike` - During strike resolution for UI feedback

## Examples

**Basic usage:**
```json
{
  "timing": "during_strike",
  "effect_type": "zero_vector_dialogue"
}
```

**Combined with zero vector:**
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

- This effect is purely for UI purposes and performs no game logic (no-op in implementation)
- Used to trigger dialogue or visual feedback when zero vector effects are active
- Always paired with other zero vector effects like `zero_vector`
- Timing is typically `during_strike` to show feedback when the card invalidation takes effect
- Has no impact on game state, rules, or mechanics
- Identical implementation to `sidestep_dialogue` but contextually different

## Related Effects

- [`zero_vector`](zero_vector.md) - Main zero vector mechanic this provides dialogue for
- [`zero_vector_internal`](zero_vector_internal.md) - Internal implementation of zero vector choice
- [`sidestep_dialogue`](sidestep_dialogue.md) - Similar UI-only dialogue effect for sidestep

## Real Usage Examples

From card definitions:
- Zero vector boost cards: `"timing": "during_strike", "effect_type": "zero_vector_dialogue"`
- UI feedback: Provides visual indication when zero vector effects are active
- Player communication: Shows when card invalidation effects are in play