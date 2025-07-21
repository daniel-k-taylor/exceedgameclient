# StrikeEffectAfterSetting

**Category**: Utility (also classified under Special Mechanics)
**Description**: Adds an effect that will be executed after the player sets their strike card.

## Parameters

- `after_set_effect` (required): The effect to execute after setting the strike
  - **Type**: Effect object
  - **Range**: Any valid effect definition
  - **Usage**: Complete effect definition including timing, effect_type, and parameters

## Supported Timings

- `immediate` - Applied immediately when the effect is triggered

## Examples

**Basic effect after setting:**
```json
{
  "timing": "immediate",
  "effect_type": "strike_effect_after_setting",
  "after_set_effect": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

**Complex effect after setting:**
```json
{
  "timing": "immediate",
  "effect_type": "strike_effect_after_setting",
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
- Stores the effect in `performing_player.extra_effect_after_set_strike`
- The stored effect is automatically executed after the player sets their strike card
- Can cause post-action interruptions if the effect requires player decisions
- Effect persists only for the immediate next strike setting action
- Allows for reactive gameplay where setting strikes can trigger additional effects

## Related Effects

- [`strike_effect_after_opponent_sets`](strike_effect_after_opponent_sets.md) - Similar effect for opponent's strike setting
- [`strike_faceup`](strike_faceup.md) - Modifies how strikes are set
- [`strike_from_gauge`](strike_from_gauge.md) - Alternative strike setting method

## Real Usage Examples

From card definitions:
- Boost cards: `"timing": "immediate", "effect_type": "strike_effect_after_setting"`
- Reactive mechanics: Allows cards to trigger effects when committing to strikes
- Strategic timing: Used for effects that should occur after strike commitment but before resolution