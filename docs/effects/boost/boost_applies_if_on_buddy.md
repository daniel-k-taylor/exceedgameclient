# boost_applies_if_on_buddy

**Category**: Boost
**Description**: Makes a boost effect only apply when the boosting character is on a buddy space.

## Parameters

No parameters required.

## Supported Timings

- `now` - Immediately when played

## Examples

**Basic conditional boost:**
```json
{
  "timing": "now",
  "effect_type": "boost_applies_if_on_buddy"
}
```

## Implementation Notes

- Sets a flag on the boost that makes its effects conditional on buddy positioning
- The boost card's effects will only trigger if the character is on a buddy space
- Used to create positioning-dependent boost strategies
- Calls [`performing_player.set_boost_applies_if_on_buddy(card_id)`](../../scenes/core/local_game.gd:1999) in implementation
- Creates tactical decisions around movement and positioning

## Related Effects

- [move_to_buddy](../movement/move_to_buddy.md) - Move to buddy space to enable boost
- [place_next_buddy](../placement/place_next_buddy.md) - Position buddy strategically
- [boost_then_sustain](boost_then_sustain.md) - Sustain boost effects
- [sustain_all_boosts](sustain_all_boosts.md) - Keep all boosts active

## Real Usage Examples

From card definitions:
- Found in character cards that reward positioning on buddy spaces
- Strategic positioning mechanics that combine movement with boosting
- Cards that encourage buddy-based gameplay patterns
- Tactical boost effects that require setup and positioning