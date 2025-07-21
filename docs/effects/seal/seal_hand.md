# SealHand

**Category**: Seal and Transform
**Description**: Seals all cards from the player's hand to the sealed area.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- `now` - Can be applied at the current moment
- Often used in powerful effects or as part of character abilities

## Examples

**Basic usage:**
```json
{
  "timing": "immediate",
  "effect_type": "seal_hand"
}
```

**Combined with strike from sealed:**
```json
{
  "timing": "now",
  "effect_type": "seal_hand",
  "and": {
    "effect_type": "draw",
    "amount": 3,
    "and": {
      "effect_type": "strike_from_sealed"
    }
  }
}
```

**Character special ability:**
```json
{
  "effect_type": "powerup",
  "amount": 2,
  "and": {
    "effect_type": "seal_hand"
  }
}
```

## Implementation Notes

- Moves all cards from the player's hand to the sealed area
- The sealed area may be secret (face-down) depending on character settings
- Creates appropriate log messages describing what cards were sealed (if visible) or that cards were sealed face-down (if secret)
- If the hand is empty, appropriate log message indicates no cards to seal
- Each card is individually processed through the sealing mechanism
- Commonly used as part of powerful effects that transform the player's game state
- The hand is completely emptied after this effect
- Often combined with draw effects to provide new cards after sealing

## Related Effects

- [`seal_discard`](seal_discard.md) - Seals discard pile instead of hand
- [`seal_topdeck`](seal_topdeck.md) - Seals single card from deck
- [`discard_hand`](../cards/discard_hand.md) - Opposite effect - moves hand to discard
- [`draw`](../cards/draw.md) - Often combined to refill hand after sealing

## Real Usage Examples

From card definitions:
- Various character special abilities: Empty hand and seal cards for powerful effects
- Combined with draw and strike effects: Seal current hand, draw new cards, then strike from sealed
- Resource transformation: Convert hand cards into sealed resources for effects that count sealed cards
- Strategic context: Powerful effect that completely transforms the player's available resources, often used in high-cost abilities that provide significant advantages in exchange for clearing the hand