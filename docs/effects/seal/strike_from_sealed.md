# StrikeFromSealed

**Category**: Seal and Transform
**Description**: Allows the player to strike with a card from their sealed area instead of from their hand.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- `now` - Can be applied at the current moment
- Often combined with other effects that manipulate the sealed area

## Examples

**Basic usage:**
```json
{
  "timing": "now",
  "effect_type": "strike_from_sealed"
}
```

**Combined with seal hand:**
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

**Immediate strike:**
```json
{
  "timing": "immediate",
  "effect_type": "strike_from_sealed"
}
```

## Implementation Notes

- Changes the game state to wait for a strike selection
- Sets the `next_strike_from_sealed` flag on the performing player
- Player can only strike with cards currently in their sealed area
- The sealed area visibility (secret/visible) affects whether cards are shown face-up during strike
- If the sealed area is empty, creates a "pass" option and appropriate log message
- Cannot be used for EX strikes (no ex strikes from sealed area)
- Cards are removed from sealed area when used for striking
- If used in a boost context, the boost handles strike sending automatically

## Related Effects

- [`seal_hand`](seal_hand.md) - Often used before striking from sealed
- [`strike_from_gauge`](../special/strike_from_gauge.md) - Similar effect but from gauge
- [`seal_topdeck`](seal_topdeck.md) - Builds up sealed area for striking
- [`swap_deck_and_sealed`](swap_deck_and_sealed.md) - Can create sealed resources for striking

## Real Usage Examples

From card definitions:
- Character abilities that seal hand then strike from sealed: Provides access to previously sealed cards
- Powerful combo effects: Seal current resources, then strike with sealed cards for different strategic options
- Resource cycling: Use sealed cards that were accumulated over time
- Strategic context: Allows players to access cards that were previously sealed, often as part of powerful abilities that transform available resources and provide access to different strategic options than what's currently in hand