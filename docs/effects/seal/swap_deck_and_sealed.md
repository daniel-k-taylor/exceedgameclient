# SwapDeckAndSealed

**Category**: Seal and Transform
**Description**: Swaps the contents of the player's deck and sealed area, then shuffles the new deck.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- Often used in choice effects to provide strategic options

## Examples

**Basic choice usage (Specter):**
```json
{
  "choice": [
    { "effect_type": "swap_deck_and_sealed" },
    { "effect_type": "pass" }
  ]
}
```

**Standalone usage:**
```json
{
  "timing": "immediate",
  "effect_type": "swap_deck_and_sealed"
}
```

**Combined with other effects:**
```json
{
  "effect_type": "draw",
  "amount": 2,
  "and": {
    "effect_type": "swap_deck_and_sealed"
  }
}
```

## Implementation Notes

- All cards currently in the deck are moved to the sealed area
- All cards currently in the sealed area are moved to the deck
- The new deck is shuffled after the swap
- Creates appropriate log messages describing the swap action
- Creates game events for UI updates
- If either the deck or sealed area is empty, the swap still occurs (one-way transfer)
- The sealed area properties (secret/visible) are maintained
- This is a complete exchange of the two card zones

## Related Effects

- [`shuffle_sealed_to_deck`](../cards/shuffle_sealed_to_deck.md) - One-way transfer from sealed to deck
- [`seal_topdeck`](seal_topdeck.md) - Moves single card from deck to sealed
- [`shuffle_deck`](../cards/shuffle_deck.md) - Shuffles deck without swapping

## Real Usage Examples

From card definitions:
- Specter's character ability: Optional effect to completely reorganize card resources
- Strategic deck manipulation: Access sealed cards by making them the new deck
- Resource transformation: Convert sealed resources into draw-able cards
- Strategic context: Powerful effect that allows players to completely restructure their card resources, often used when the sealed area contains more valuable cards than the current deck, or to access specific sealed cards for drawing