# SetEnchantressDrawChoice

**Category**: Utility
**Description**: Enables the Enchantress character to make draw choices for subsequent card draws.

## Parameters

This effect takes no parameters.

## Supported Timings

- `now` - Immediately when the effect is triggered

## Examples

**Basic usage:**
```json
{
  "timing": "now",
  "effect_type": "set_enchantress_draw_choice"
}
```

**Combined with other effects:**
```json
{
  "effect_type": "draw",
  "amount": 2,
  "and": {
    "effect_type": "set_enchantress_draw_choice"
  }
}
```

## Implementation Notes

- Sets the `enchantress_draw_choice` flag to true for the performing player
- This flag affects subsequent draw operations, allowing the Enchantress to choose which cards to draw
- Character-specific effect that only functions meaningfully for the Enchantress character
- The flag persists until the end of the current turn or until reset by game state changes
- Has no visible effect if triggered by non-Enchantress characters

## Related Effects

- [`draw`](../cards/draw.md) - Basic draw effect that this modifies
- [`draw_choice`](../cards/draw_choice.md) - Alternative choice-based drawing
- [`choice`](../choice/choice.md) - General choice-making mechanics

## Real Usage Examples

From card definitions:
- Enchantress character cards: Used in conjunction with draw effects to provide strategic card selection
- Enchantress deck: `"and": { "effect_type": "set_enchantress_draw_choice" }` combined with draw effects
- Character-specific mechanics: Enables Enchantress's unique playstyle of selective card drawing