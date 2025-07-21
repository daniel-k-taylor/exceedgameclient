# EffectPerCardInZone

**Category**: Life and Damage
**Description**: Executes an effect multiple times based on the number of cards in a specified zone.

## Parameters

- `zone` (required): The zone to count cards from
  - **Type**: String
  - **Values**: "transform", "gauge", "hand", "discard", "sealed", "stored_cards", "overdrive"

- `per_card_effect` (required): The effect to execute for each card
  - **Type**: Effect object
  - **Special Property**: `combine_multiple_into_one` - If true, multiplies effect amount by card count and executes once

- `limitation` (optional): Additional filtering criteria for cards
  - **Type**: String
  - **Values**: "range_to_opponent" - Only count cards that can hit opponent at current range
  - **Default**: Count all cards in zone

## Supported Timings

- `during_strike` - During strike resolution
- `timing` - Any other timing context where card counting is needed
- `hit` - When attack hits opponent

## Examples

**Basic power per gauge card:**
```json
{
  "timing": "during_strike",
  "effect_type": "effect_per_card_in_zone",
  "zone": "gauge",
  "per_card_effect": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

**Combined life gain per hand card:**
```json
{
  "effect_type": "effect_per_card_in_zone",
  "zone": "hand",
  "per_card_effect": {
    "combine_multiple_into_one": true,
    "effect_type": "gain_life",
    "amount": 1
  }
}
```

**Range-limited effect:**
```json
{
  "timing": "hit",
  "effect_type": "effect_per_card_in_zone",
  "limitation": "range_to_opponent",
  "zone": "hand",
  "per_card_effect": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

**Damage per stored card:**
```json
{
  "effect_type": "effect_per_card_in_zone",
  "zone": "stored_cards",
  "per_card_effect": {
    "effect_type": "take_damage",
    "opponent": true,
    "amount": 1
  }
}
```

## Implementation Notes

- Counts cards in the specified zone at time of execution
- If `combine_multiple_into_one` is true, multiplies the effect amount by card count and executes once
- Otherwise, executes the effect once for each card in the zone
- Range limitation checks if cards can hit opponent at current distance
- Assumes no decisions are required for the per-card effect
- Efficiently handles large numbers of cards through combination option
- Zone names must match exact strings from implementation

## Related Effects

- [gauge_for_effect](../gauge/gauge_for_effect.md) - Spends gauge for effects
- [powerup](../stats/powerup.md) - Common per-card effect
- [draw](../cards/draw.md) - Can be scaled by card count

## Real Usage Examples

From card definitions:
- Djanette's range effect: `{ "timing": "hit", "effect_type": "effect_per_card_in_zone", "limitation": "range_to_opponent", "zone": "hand", "per_card_effect": { "effect_type": "powerup", "amount": 1 } }`
- Life scaling: `{ "per_card_effect": { "combine_multiple_into_one": true, "effect_type": "gain_life", "amount": 1 }, "zone": "hand" }`
- Resource conversion: Effects that scale with deck construction choices
- Power scaling: Attack strength based on cards in specific zones
- Strategic zone management: Players managing zones to maximize effect values