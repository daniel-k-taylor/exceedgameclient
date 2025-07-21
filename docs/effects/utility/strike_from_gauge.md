# StrikeFromGauge

**Category**: Utility (also classified under Special Mechanics)
**Description**: Allows the player to choose a card from their gauge to use as a strike instead of from hand.

## Parameters

This effect takes no parameters.

## Supported Timings

- `now` - Immediately when the effect is triggered

## Examples

**Basic gauge strike:**
```json
{
  "timing": "now",
  "effect_type": "strike_from_gauge"
}
```

**Combined with other effects:**
```json
{
  "effect": {
    "effect_type": "strike_from_gauge"
  }
}
```

**With conditions:**
```json
{
  "character_effect": true,
  "condition": "was_strike_from_gauge",
  "effect_type": "powerup",
  "amount": 2
}
```

## Implementation Notes

- Changes game state to PlayerDecision and creates a strike choice from gauge cards
- Uses `DecisionType_StrikeNow` with strike options limited to gauge cards
- Each valid gauge card becomes a strike option with its normal stats and effects
- Creates `EventType_Strike_EffectDoStrike` event when choice is made
- Gauge cards used this way are removed from gauge and go to appropriate discard zones
- Provides access to potentially powerful cards that were previously gauged
- Can enable unique strategic combinations not available from hand

## Related Effects

- [`strike_random_from_gauge`](strike_random_from_gauge.md) - Random version of gauge striking
- [`strike_faceup`](strike_faceup.md) - Modifies how strikes are revealed
- [`gauge_for_effect`](../gauge/gauge_for_effect.md) - Moves cards to gauge for later use

## Real Usage Examples

From card definitions:
- Hyde character cards: `"effect": { "effect_type": "strike_from_gauge" }`
- Character abilities: Allows access to previously gauged strikes
- Conditional effects: `"condition": "was_strike_from_gauge"` triggers special bonuses
- Yuzu character: Uses gauge strikes as part of core mechanics