# SealInsteadOfDiscarding

**Category**: Seal and Transform
**Description**: Sets a flag so that cards that would normally be discarded are instead sealed to the sealed area.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- `now` - Can be applied at the current moment
- Can be combined with other effects that cause discarding

## Examples

**Basic usage:**
```json
{
  "timing": "immediate",
  "effect_type": "seal_instead_of_discarding"
}
```

**Combined with discard effect (Celinka exceed):**
```json
{
  "effect_type": "seal_discard",
  "and": {
    "effect_type": "seal_instead_of_discarding"
  }
}
```

**Used with other effects:**
```json
{
  "effect_type": "draw",
  "amount": 3,
  "and": {
    "effect_type": "seal_instead_of_discarding"
  }
}
```

## Implementation Notes

- Sets the `seal_instead_of_discarding` flag on the performing player
- This flag is checked whenever cards would be added to the discard pile
- If the flag is set and the card belongs to the player, it goes to sealed instead of discard
- Only affects cards owned by the player who has the flag set
- The flag persists until explicitly cleared or the game state changes
- Works with any discard effect, including natural discarding from hand size limits
- Respects the player's `sealed_area_is_secret` setting for logging
- The sealed area may be face-down depending on character configuration

## Related Effects

- [`seal_discard`](seal_discard.md) - Seals current discard pile
- [`seal_hand`](seal_hand.md) - Seals current hand
- [`discard_hand`](../cards/discard_hand.md) - Effect that would normally discard
- [`discard_random`](../cards/discard_random.md) - Random discard that could be redirected

## Real Usage Examples

From card definitions:
- Celinka's exceed ability: Seals discard pile and then redirects future discards to sealed
- Strategic defensive play: Prevent opponent from gaining advantage from your discarded cards
- Card preservation: Keep important cards in sealed rather than discard where they might be harder to recover
- Strategic context: Transforms discard effects into sealing effects, allowing players to build up sealed cards for later use while avoiding the normal discard pile