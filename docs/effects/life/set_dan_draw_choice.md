# SetDanDrawChoice

**Category**: Life and Damage
**Description**: Enables Dan's special draw choice mechanic, allowing the player to choose between drawing from top or bottom of deck.

## Parameters

This effect takes no parameters.

## Supported Timings

- `on_exceed` - When character enters exceed state
- `immediate` - Immediately when triggered

## Examples

**Basic Dan draw choice activation:**
```json
{
  "on_exceed": {
    "effect_type": "set_dan_draw_choice"
  }
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

- Sets the player's dan_draw_choice flag to true
- This is typically used to enable Dan's exceed ability
- Works in conjunction with SetDanDrawChoiceInternal for the actual choice mechanism
- Does not directly affect drawing mechanics, but enables the choice system
- Character-specific effect primarily designed for Dan character
- Simple flag-setting effect with no complex logic

## Related Effects

- [set_dan_draw_choice_internal](set_dan_draw_choice_internal.md) - Handles the actual choice implementation
- [choice](../choice/choice.md) - Used to present draw direction options
- [draw](../cards/draw.md) - The actual drawing mechanic that gets modified

## Real Usage Examples

From card definitions:
- Dan's exceed: `{ "on_exceed": { "effect_type": "set_dan_draw_choice" } }`
- Character transformation: Enabling special drawing abilities when exceeding
- Strategic deck manipulation: Allowing players to choose optimal draw direction
- Character-specific mechanics: Dan's unique exceed ability for deck control
- Advanced play options: Giving experienced players more tactical choices