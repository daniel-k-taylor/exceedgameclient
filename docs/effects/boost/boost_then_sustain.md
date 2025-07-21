# boost_then_sustain

**Category**: Boost
**Description**: Allow player to boost a card and automatically sustain it.

## Parameters

- `valid_zones` (optional): Source zones for boosting
  - **Type**: Array of strings
  - **Default**: ["hand"]
  - **Values**: ["hand"], ["gauge"], ["deck"], ["discard"], ["extra"]
- `limitation` (optional): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", "continuous", etc.
  - **Default**: No limitation
- `ignore_costs` (optional): Ignore boost costs
  - **Type**: Boolean
  - **Default**: false
- `play_boost_effect` (optional): Additional effect to trigger when boosting
  - **Type**: Effect object
  - **Default**: No additional effect
- `sustain` (optional): Whether to sustain the boost
  - **Type**: Boolean
  - **Default**: true

## Supported Timings

- `during_strike` - During strike resolution (expected timing)

## Examples

**Basic boost then sustain from hand:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain"
}
```

**Boost then sustain from hand and gauge:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain",
  "valid_zones": ["hand", "gauge"]
}
```

**Free boost with sustain:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain",
  "ignore_costs": true
}
```

**Boost without sustaining:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain",
  "sustain": false
}
```

**Boost with additional effect:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_then_sustain",
  "play_boost_effect": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

## Implementation Notes

- Expected to be used mid-strike (asserts [`active_strike`](../../scenes/core/local_game.gd:2118) is true)
- Checks if player [`can_boost_something(valid_zones, limitation)`](../../scenes/core/local_game.gd:2128) before allowing boost
- Creates [`EventType_ForceStartBoost`](../../scenes/core/local_game.gd:2129) with specified parameters
- Sets [`sustain_next_boost`](../../scenes/core/local_game.gd:2141) flag to control sustain behavior
- Sets [`cancel_blocked_this_turn`](../../scenes/core/local_game.gd:2142) to true
- Can trigger [`play_boost_effect`](../../scenes/core/local_game.gd:2137) as bonus effect
- Enables mid-strike boost decisions with automatic sustain
- Found in many card definitions across characters

## Related Effects

- [boost_this_then_sustain](boost_this_then_sustain.md) - Boost current strike card
- [sustain_all_boosts](sustain_all_boosts.md) - Keep all boosts active
- [boost_additional](boost_additional.md) - Boost additional cards
- [boost_multiple](boost_multiple.md) - Boost multiple cards at once

## Real Usage Examples

From card definitions:
- Anji's cards: Boost and sustain from hand
- Byakuya's effects: Multi-zone boost with sustain from hand and gauge
- Various characters: Mid-strike boost decisions that provide lasting value
- Combo enablers that sustain boosts for continued advantage