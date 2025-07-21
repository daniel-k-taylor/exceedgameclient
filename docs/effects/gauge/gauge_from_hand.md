# gauge_from_hand

**Category**: Gauge
**Description**: Choose cards from hand to add to gauge. Player selects which cards and how many to move.

## Parameters

- `min_amount` (required): Minimum number of cards that must be selected
  - **Type**: Integer
  - **Range**: 0 or positive integer
- `max_amount` (required): Maximum number of cards that can be selected
  - **Type**: Integer
  - **Range**: Positive integer
- `opponent` (optional): If true, affects opponent instead of self
  - **Type**: Boolean
  - **Default**: false
- `card_type_limitation` (optional): Restrict which card types can be selected
  - **Type**: Array of strings
  - **Default**: ["normal", "special", "ultra"]
  - **Values**: Any combination of "normal", "special", "ultra"
- `destination` (optional): Where selected cards go
  - **Type**: String
  - **Default**: "gauge"
  - **Values**: "gauge", "discard", etc.
- `amount_is_gauge_spent` (optional): Use gauge spent before strike as amount
  - **Type**: Boolean
  - **Default**: false
- `from_last_cards` (optional): Limit selection to last N cards in hand
  - **Type**: Integer
  - **Note**: Restricts selection to most recently drawn cards

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `after` - After strike resolution
- `set_strike` - When setting a strike

## Examples

**Basic gauge selection:**
```json
{
  "timing": "now",
  "effect_type": "gauge_from_hand",
  "min_amount": 1,
  "max_amount": 3
}
```

**Forced selection:**
```json
{
  "timing": "immediate",
  "effect_type": "gauge_from_hand",
  "min_amount": 2,
  "max_amount": 2
}
```

**Limited card types:**
```json
{
  "timing": "now",
  "effect_type": "gauge_from_hand",
  "min_amount": 0,
  "max_amount": 2,
  "card_type_limitation": ["normal", "special"]
}
```

**Opponent effect:**
```json
{
  "timing": "hit",
  "effect_type": "gauge_from_hand",
  "min_amount": 1,
  "max_amount": 2,
  "opponent": true
}
```

## Implementation Notes

- Creates a player decision state for card selection
- Player can select between min_amount and max_amount cards
- Only cards matching card_type_limitation can be selected
- If opponent is true, affects opponent's hand instead
- If amount_is_gauge_spent is true, uses gauge spent before strike as both min and max
- from_last_cards restricts selection to most recently drawn cards
- Does nothing if no valid cards are available
- Flexible destination allows sending to different zones

## Related Effects

- [add_hand_to_gauge](add_hand_to_gauge.md) - Move entire hand to gauge
- [gauge_for_effect](gauge_for_effect.md) - Spend gauge for effects
- [choose_discard](../cards/choose_discard.md) - Similar selection mechanism for discard

## Real Usage Examples

From card definitions:
- Character abilities allowing selective gauge building
- Strategic resource management with player choice
- Effects that punish opponent by forcing gauge conversion
- Flexible resource conversion with type restrictions