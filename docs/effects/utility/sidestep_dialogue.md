# SidestepDialogue

**Category**: Utility
**Description**: UI-only effect that provides dialogue feedback during sidestep mechanics.

## Parameters

This effect takes no parameters.

## Supported Timings

- `during_strike` - During strike resolution for UI feedback

## Examples

**Basic usage:**
```json
{
  "timing": "during_strike",
  "effect_type": "sidestep_dialogue"
}
```

**Combined with sidestep:**
```json
{
  "timing": "now",
  "effect_type": "sidestep_transparent_foe"
},
{
  "timing": "during_strike",
  "effect_type": "sidestep_dialogue"
}
```

## Implementation Notes

- This effect is purely for UI purposes and performs no game logic (no-op in implementation)
- Used to trigger dialogue or visual feedback when sidestep effects are active
- Always paired with other sidestep effects like `sidestep_transparent_foe`
- Timing is typically `during_strike` to show feedback when the sidestep takes effect
- Has no impact on game state, rules, or mechanics

## Related Effects

- [`sidestep_transparent_foe`](sidestep_transparent_foe.md) - Main sidestep mechanic this provides dialogue for
- [`sidestep_internal`](sidestep_internal.md) - Internal implementation of sidestep choice
- [`zero_vector_dialogue`](zero_vector_dialogue.md) - Similar UI-only dialogue effect

## Real Usage Examples

From card definitions:
- Sidestep boost cards: `"timing": "during_strike", "effect_type": "sidestep_dialogue"`
- UI feedback: Provides visual indication when sidestep effects are active
- Player communication: Shows when transparent card effects are in play