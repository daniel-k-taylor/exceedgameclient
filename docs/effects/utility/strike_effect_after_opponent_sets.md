# StrikeEffectAfterOpponentSets

**Category**: Utility (also classified under Special Mechanics)
**Description**: Adds an effect that will be executed after the opponent sets their strike card.

## Parameters

- `after_set_effect` (required): The effect to execute after opponent sets their strike
  - **Type**: Effect object
  - **Range**: Any valid effect definition
  - **Usage**: Complete effect definition including timing, effect_type, and parameters

## Supported Timings

- `immediate` - Applied immediately when the effect is triggered

## Examples

**Basic effect after opponent sets:**
```json
{
  "timing": "immediate",
  "effect_type": "strike_effect_after_opponent_sets",
  "after_set_effect": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

**Complex reactive effect:**
```json
{
  "timing": "immediate",
  "effect_type": "strike_effect_after_opponent_sets",
  "after_set_effect": {
    "effect_type": "draw",
    "amount": 1,
    "and": {
      "effect_type": "gauge_for_effect",
      "amount": 1
    }
  }
}
```

## Implementation Notes

- Only functions during active boost phases, not during active strikes
- Stores the effect in `opposing_player.extra_effect_after_set_strike`
- The stored effect is automatically executed after the opponent sets their strike card
- Can cause post-action interruptions if the effect requires player decisions
- Effect persists only for the immediate next strike setting action by the opponent
- Allows for reactive gameplay where opponent's strike setting triggers your effects
- Provides strategic counterplay options and information-based reactions

## Related Effects

- [`strike_effect_after_setting`](strike_effect_after_setting.md) - Similar effect for your own strike setting
- [`strike_opponent_sets_first`](strike_opponent_sets_first.md) - Forces opponent to set first
- [`strike_faceup`](strike_faceup.md) - Modifies how strikes are set

## Real Usage Examples

From card definitions:
- Boost cards: `"timing": "immediate", "effect_type": "strike_effect_after_opponent_sets"`
- Reactive strategies: Allows effects that respond to opponent's strike choices
- Information advantage: Used for effects that benefit from seeing opponent's commitment first