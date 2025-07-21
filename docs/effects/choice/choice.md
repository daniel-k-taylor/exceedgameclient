# choice

**Category**: Choice
**Description**: Present multiple options to choose from. The player selects one option to execute.

## Parameters

- `choice` (required): Array of effect options to choose from
  - **Type**: Array of effect objects
  - **Note**: Each option is a complete effect definition
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

All timings are supported, as the choice itself can execute at any time.

## Examples

**Basic movement choice:**
```json
{
  "timing": "before",
  "effect_type": "choice",
  "choice": [
    { "effect_type": "advance", "amount": 1 },
    { "effect_type": "retreat", "amount": 1 },
    { "effect_type": "pass" }
  ]
}
```

**Power vs Speed choice:**
```json
{
  "timing": "during_strike",
  "effect_type": "choice",
  "choice": [
    { "effect_type": "powerup", "amount": 2 },
    { "effect_type": "speedup", "amount": 2 }
  ]
}
```

**Opponent makes choice:**
```json
{
  "timing": "hit",
  "effect_type": "choice",
  "opponent": true,
  "choice": [
    { "effect_type": "opponent_discard_choose", "amount": 1 },
    { "effect_type": "take_damage", "amount": 1 }
  ]
}
```

**Complex chained choices:**
```json
{
  "timing": "immediate",
  "effect_type": "choice",
  "choice": [
    {
      "effect_type": "close",
      "amount": 1,
      "and": { "effect_type": "strike" }
    },
    {
      "effect_type": "retreat",
      "amount": 1,
      "and": { "effect_type": "strike" }
    }
  ]
}
```

**Multiple selections:**
```json
{
  "timing": "now",
  "effect_type": "choice",
  "multiple_amount": 2,
  "choice": [
    { "effect_type": "draw", "amount": 1 },
    { "effect_type": "powerup", "amount": 1 },
    { "effect_type": "speedup", "amount": 1 },
    { "effect_type": "armorup", "amount": 1 }
  ]
}
```

## Implementation Notes

- Creates a decision state where the player must choose
- Each choice option is executed as if it were a standalone effect
- `pass` is commonly included as a "do nothing" option
- Card name additions show dynamic information to help decision making

## Related Effects

- [choice_altered_values](choice_altered_values.md) - Choices with dynamic values
- [pass](../special/pass.md) - Do nothing option
- [choose_cards_from_top_deck](choose_cards_from_top_deck.md) - Choose from specific cards

## Real Usage Examples

From card definitions:
- Zangief's "Exceed": Choice between different pull amounts
- Propeller Knight's "Exceed": Choice between different advance amounts
- Wagner's character action: Choice between close or retreat
- Ryu's boost effects: Choice between advance/retreat + draw
- Millia's overdrive: Choice between draw, advance, or retreat