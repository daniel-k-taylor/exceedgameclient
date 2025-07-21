# SealTopdeck

**Category**: Seal and Transform
**Description**: Seals the top card of the player's deck to the sealed area.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- Can be used in choice effects to provide optional sealing

## Examples

**Basic usage (Arakune choice):**
```json
{
  "choice": [
    { "effect_type": "seal_topdeck" },
    { "effect_type": "pass" }
  ]
}
```

**Another Arakune example:**
```json
{
  "choice": [
    { "effect_type": "seal_topdeck"},
    { "effect_type": "pass" }
  ]
}
```

**Combined with other effects:**
```json
{
  "effect_type": "powerup",
  "amount": 1,
  "and": {
    "effect_type": "seal_topdeck"
  }
}
```

## Implementation Notes

- Only works if the player has at least one card in their deck
- Removes the top card from the deck and moves it to the sealed area
- The sealed area may be secret (face-down) depending on character settings
- Creates appropriate log messages describing what card was sealed (if visible) or that a card was sealed face-down (if secret)
- If the deck is empty, the effect does nothing
- Updates the player's hand state if the top card was being tracked
- Often used in choice effects to give players optional deck manipulation

## Related Effects

- [`seal_discard`](seal_discard.md) - Seals discard pile instead of top deck
- [`seal_hand`](seal_hand.md) - Seals entire hand
- [`add_top_deck_to_gauge`](../gauge/add_top_deck_to_gauge.md) - Alternative use for top deck card
- [`discard_topdeck`](../cards/discard_topdeck.md) - Discards instead of sealing

## Real Usage Examples

From card definitions:
- Arakune's character abilities: Optional sealing of top deck card as a strategic choice
- Deck manipulation strategies: Convert unknown deck cards into sealed resources
- Resource management: Trade deck cards for sealed area buildup
- Strategic context: Allows players to convert deck cards into sealed resources, often used as an optional effect that provides flexibility in resource management and deck thinning