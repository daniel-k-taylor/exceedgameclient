# SealDiscard

**Category**: Seal and Transform
**Description**: Seals all cards from the player's discard pile to the sealed area.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- `now` - Can be applied at the current moment
- Often used as part of exceed abilities

## Examples

**Basic usage (Celinka exceed):**
```json
{
  "effect_type": "seal_discard",
  "and": {
    "effect_type": "seal_instead_of_discarding"
  }
}
```

**Combined with other effects:**
```json
{
  "effect_type": "draw",
  "amount": 2,
  "and": {
    "effect_type": "seal_discard"
  }
}
```

**Standalone sealing:**
```json
{
  "timing": "immediate",
  "effect_type": "seal_discard"
}
```

## Implementation Notes

- Moves all cards from the player's discard pile to the sealed area
- The sealed area may be secret (face-down) depending on character settings
- Creates appropriate log messages describing what cards were sealed (if visible) or that cards were sealed face-down (if secret)
- If the discard pile is empty, appropriate log message indicates no cards to seal
- Each card is individually processed through the sealing mechanism
- Commonly used as part of exceed abilities to convert accumulated discards into sealed resources
- The discard pile is completely emptied after this effect

## Related Effects

- [`seal_hand`](seal_hand.md) - Seals hand instead of discard
- [`seal_topdeck`](seal_topdeck.md) - Seals top deck card
- [`seal_instead_of_discarding`](seal_instead_of_discarding.md) - Redirects future discards to sealed
- [`discard_hand`](../cards/discard_hand.md) - Opposite effect - moves hand to discard

## Real Usage Examples

From card definitions:
- Celinka's exceed ability: Seals entire discard pile and then redirects future discards to sealed area
- Character transformation effects: Convert accumulated discard resources into sealed area
- Resource management: Turn previously discarded cards into sealed resources for effects that count sealed cards
- Strategic context: Allows players to reclaim cards that have been discarded, often as part of powerful exceed abilities that fundamentally change how the player's card economy works