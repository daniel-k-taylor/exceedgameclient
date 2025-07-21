# StrikeFaceup

**Category**: Utility (also classified under Special Mechanics)
**Description**: Forces the next strike to be set face-up, revealing it to the opponent.

## Parameters

- `disable_wild_swing` (optional): Prevents wild swing from being used with this strike
  - **Type**: Boolean
  - **Default**: false
  - **Usage**: Set to true to disable wild swing option for this face-up strike

## Supported Timings

- `now` - Immediately when the effect is triggered

## Examples

**Basic face-up strike:**
```json
{
  "timing": "now",
  "effect_type": "strike_faceup"
}
```

**Face-up strike without wild swing:**
```json
{
  "effect_type": "strike_faceup",
  "disable_wild_swing": true
}
```

**Combined with other effects:**
```json
{
  "timing": "now",
  "effect_type": "strike_faceup"
},
{
  "timing": "during_strike",
  "effect_type": "powerup",
  "amount": 3
}
```

## Implementation Notes

- Sets the `next_strike_faceup` flag to true for the performing player
- Face-up strikes are revealed to the opponent when set, providing information advantage to the opponent
- Wild swing can optionally be disabled with the `disable_wild_swing` parameter
- Effect persists only for the immediate next strike action
- Provides strategic trade-offs between information revelation and other benefits
- Often combined with powerful effects to balance the information disadvantage

## Related Effects

- [`strike_from_gauge`](strike_from_gauge.md) - Alternative strike setting method
- [`strike_opponent_sets_first`](strike_opponent_sets_first.md) - Information advantage mechanic
- [`strike_effect_after_setting`](strike_effect_after_setting.md) - Effects triggered by strike setting

## Real Usage Examples

From card definitions:
- Hyde character cards: `"effect_type": "strike_faceup", "disable_wild_swing": true`
- Strategic cards: `"timing": "now", "effect_type": "strike_faceup"`
- High-power abilities: Often paired with significant benefits to offset information disadvantage