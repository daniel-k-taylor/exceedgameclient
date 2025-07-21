# choice_altered_values

**Category**: Choice and Selection
**Description**: Present multiple options with dynamically modified values based on game state or conditions.

## Parameters

- `choice` (required): Array of effect options to choose from
  - **Type**: Array of effect objects
  - **Note**: Each option is a complete effect definition that will have values altered
- `special_choice_name` (optional): Custom name displayed for this choice
  - **Type**: String
- `opponent` (optional): If true, opponent makes the choice instead
  - **Type**: Boolean
  - **Default**: false
- `add_topdeck_card_name_to_choices` (optional): Add top deck card name to specified choice indices
  - **Type**: Array of integers
- `add_topdiscard_card_name_to_choices` (optional): Add top discard card name to specified choice indices
  - **Type**: Array of integers
- `add_bottomdiscard_card_name_to_choices` (optional): Add bottom discard card name to specified choice indices
  - **Type**: Array of integers

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `hit` - When attack hits
- `after` - After strike resolution
- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `cleanup` - During cleanup phase

## Examples

**Basic power choice with dynamic values:**
```json
{
  "timing": "during_strike",
  "effect_type": "choice_altered_values",
  "choice": [
    { "effect_type": "powerup", "amount": "strike_x" },
    { "effect_type": "speedup", "amount": "strike_x" }
  ]
}
```

**Movement choice with altered amounts:**
```json
{
  "timing": "before",
  "effect_type": "choice_altered_values",
  "choice": [
    { "effect_type": "advance", "amount": "gauge_count" },
    { "effect_type": "retreat", "amount": "gauge_count" },
    { "effect_type": "pass" }
  ]
}
```

**Complex effect with multiple alterations:**
```json
{
  "timing": "hit",
  "effect_type": "choice_altered_values",
  "choice": [
    { "effect_type": "powerup", "amount": "cards_in_hand" },
    { "effect_type": "draw", "amount": "boosts_in_play" },
    { "effect_type": "armorup", "amount": "current_speed" }
  ]
}
```

**Choice with card name additions:**
```json
{
  "timing": "immediate",
  "effect_type": "choice_altered_values",
  "add_topdeck_card_name_to_choices": [0, 1],
  "choice": [
    { "effect_type": "add_top_deck_to_gauge" },
    { "effect_type": "add_top_deck_to_hand" },
    { "effect_type": "pass" }
  ]
}
```

## Implementation Notes

- Creates a deep copy of the choice array and replaces dynamic values before presentation
- Common dynamic values include "strike_x", "gauge_count", "cards_in_hand", "boosts_in_play"
- Card name additions help players make informed decisions by showing what cards are available
- The altered values are calculated at the time the choice is presented, not when the effect is defined
- Each choice option is executed as if it were a standalone effect after value substitution

## Related Effects

- [choice](choice.md) - Basic choice without value alterations
- [choose_cards_from_top_deck](choose_cards_from_top_deck.md) - Choose from specific revealed cards
- [pass](../special/pass.md) - Do nothing option commonly used in choices

## Real Usage Examples

From card definitions:
- Merkava's attacks: Choice between power/speed with amounts based on current strike values
- King's boosts: Choice between different effects with gauge-based scaling
- Various character cards: Dynamic movement amounts based on current game state
- Enchantress effects: Choices with values modified by spell cards in play