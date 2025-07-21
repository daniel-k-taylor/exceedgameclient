# speedup

**Category**: Stats
**Description**: Increase speed by a specified amount for this strike. Speed determines strike priority and affects damage calculations.

## Parameters

- `amount` (required): Amount of speed to add
  - **Type**: Integer
  - **Range**: Any integer (positive increases speed, negative decreases)

## Supported Timings

- `during_strike` - During strike resolution
- `before` - Before strike resolution
- `hit` - When attack hits

## Examples

**Basic speed increase:**
```json
{
  "timing": "during_strike",
  "effect_type": "speedup",
  "amount": 1
}
```

**Large speed boost:**
```json
{
  "timing": "during_strike",
  "effect_type": "speedup",
  "amount": 3
}
```

**Speed decrease (debuff):**
```json
{
  "timing": "during_strike",
  "effect_type": "speedup",
  "amount": -2
}
```

**Conditional speed boost:**
```json
{
  "timing": "during_strike",
  "condition": "is_special_attack",
  "effect_type": "speedup",
  "amount": 2
}
```

## Implementation Notes

- Speed bonus is applied to `strike_stat_boosts.speed`
- Stacks with other speed effects
- Can be modified by multiplier effects like `multiply_speed_bonuses`
- Negative amounts reduce speed (minimum 0 total speed)
- Speed determines strike order and affects damage calculations
- Higher speed strikes resolve first in simultaneous situations

## Related Effects

- [speedup_per_boost_in_play](speedup_per_boost_in_play.md) - Speed based on boosts
- [speedup_per_force_spent_this_turn](speedup_per_force_spent_this_turn.md) - Speed based on force spent
- [speedup_amount_in_gauge](speedup_amount_in_gauge.md) - Speed equal to gauge size
- [multiply_speed_bonuses](multiply_speed_bonuses.md) - Multiply speed bonuses
- [swap_power_speed](../utility/swap_power_speed.md) - Swap power and speed values

## Real Usage Examples

From card definitions:
- Chipp's "Alpha Blade": `{ "timing": "during_strike", "effect_type": "speedup", "amount": 2 }`
- Jin's "Frost Bite": Speed boost on ice attacks
- Millia's "Silent Force": Speed for stealth attacks
- Various rushdown and combo-oriented characters use speed boosts