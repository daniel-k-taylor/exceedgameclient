# SetDanDrawChoiceInternal

**Category**: Life and Damage
**Description**: Sets the specific draw direction for Dan's draw choice mechanic, determining whether cards are drawn from top or bottom of deck.

## Parameters

- `from_bottom` (required): Whether to draw from bottom of deck
  - **Type**: Boolean
  - **Values**: true (draw from bottom), false (draw from top)

## Supported Timings

- `choice` - As part of a choice selection
- `immediate` - When the choice is made

## Examples

**Draw from top choice:**
```json
{
  "effect_type": "set_dan_draw_choice_INTERNAL",
  "from_bottom": false
}
```

**Draw from bottom choice:**
```json
{
  "effect_type": "set_dan_draw_choice_INTERNAL",
  "from_bottom": true
}
```

**Used in choice system:**
```json
{
  "effect_type": "choice",
  "choice": [
    { "effect_type": "set_dan_draw_choice_INTERNAL", "from_bottom": false },
    { "effect_type": "set_dan_draw_choice_INTERNAL", "from_bottom": true }
  ]
}
```

## Implementation Notes

- Sets the player's dan_draw_choice_from_bottom flag to the specified value
- This is the internal implementation effect that handles the actual choice
- Works in conjunction with SetDanDrawChoice which enables the choice system
- Affects subsequent draw operations when Dan's exceed ability is active
- Character-specific effect primarily designed for Dan character
- The "INTERNAL" suffix indicates this is an implementation detail

## Related Effects

- [set_dan_draw_choice](set_dan_draw_choice.md) - Enables the choice system
- [choice](../choice/choice.md) - Presents the choice options to the player
- [draw](../cards/draw.md) - The drawing mechanic that gets modified by this choice

## Real Usage Examples

From card definitions:
- Dan's choice system: Used internally when player selects draw direction
- Exceed mechanics: Part of Dan's special exceed ability implementation
- Strategic deck control: Allows players to optimize which cards they draw
- Advanced gameplay: Provides tactical decisions for experienced players
- Character-specific features: Dan's unique deck manipulation ability