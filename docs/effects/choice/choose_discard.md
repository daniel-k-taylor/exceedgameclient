# choose_discard

**Category**: Choice and Selection
**Description**: Allow player to choose which cards to discard from a specified source zone.

## Parameters

- `amount` (optional): Number of cards to discard
  - **Type**: Integer
  - **Default**: 1
- `source` (optional): Source zone to discard from
  - **Type**: String
  - **Default**: "hand"
  - **Values**: "hand", "gauge", "overdrive", "sealed", "discard"
- `limitation` (optional): Restrict card types that can be discarded
  - **Type**: String
  - **Values**: "special", "continuous", "special/ultra", ""
- `opponent` (optional): If true, opponent chooses cards to discard from their zones
  - **Type**: Boolean
  - **Default**: false
- `UI_skip_summary` (optional): Skip showing summary UI for this discard
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `immediate` - Immediately when triggered
- `now` - Immediately when played
- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution
- `cleanup` - During cleanup phase
- `on_strike_reveal` - When strike is revealed

## Examples

**Basic hand discard:**
```json
{
  "timing": "hit",
  "effect_type": "choose_discard",
  "limitation": ""
}
```

**Discard from gauge:**
```json
{
  "timing": "immediate",
  "effect_type": "choose_discard",
  "source": "gauge",
  "amount": 2
}
```

**Discard special cards only:**
```json
{
  "timing": "now",
  "effect_type": "choose_discard",
  "limitation": "special"
}
```

**Discard from sealed:**
```json
{
  "timing": "hit",
  "effect_type": "choose_discard",
  "source": "sealed",
  "limitation": ""
}
```

**Opponent discard choice:**
```json
{
  "timing": "immediate",
  "effect_type": "choose_discard",
  "opponent": true,
  "limitation": ""
}
```

**Multiple card discard:**
```json
{
  "timing": "after",
  "effect_type": "choose_discard",
  "amount": 2,
  "limitation": ""
}
```

**Conditional discard:**
```json
{
  "condition": "initiated_strike",
  "effect_type": "choose_discard",
  "limitation": ""
}
```

## Implementation Notes

- Creates a decision state where player selects cards from the specified source
- If limitation is specified, only cards matching that type can be selected
- Empty limitation ("") means any cards can be discarded
- If source zone has fewer cards than amount requested, player discards all available
- Cards are moved from source zone to discard pile
- No effect if source zone is empty
- When opponent is true, the opposing player makes the choice for their own cards
- UI_skip_summary reduces interface overhead for rapid discard effects

## Related Effects

- [discard_hand](../cards/discard_hand.md) - Automatic hand discard
- [discard_random](../cards/discard_random.md) - Random discard without choice
- [choose_opponent_card_to_discard](choose_opponent_card_to_discard.md) - Choose opponent's cards
- [opponent_discard_choose](../cards/opponent_discard_choose.md) - Opponent chooses their discard

## Real Usage Examples

From card definitions:
- Nine's overdrive effect: Choose cards to discard for resource management
- Multiple hit effects: Choose discard as consequence of successful attacks
- Gauge management cards: Choose which gauge cards to discard for effects
- Sealed card interactions: Choose sealed cards to discard for benefits
- Special/ultra limitations: Strategic discard of high-value cards only
- Cleanup effects: End-of-turn discard choices for hand size management