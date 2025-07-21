# powerup

**Category**: Stats
**Description**: Increase power by a specified amount for this strike.

## Parameters

- `amount` (required): Amount of power to add
  - **Type**: Integer
  - **Range**: Any integer (positive increases power, negative decreases)
  - **Special Values**: None

## Supported Timings

- `during_strike` - During strike resolution
- `before` - Before strike resolution
- `hit` - When attack hits

## Examples

**Basic power increase:**
```json
{
  "timing": "during_strike",
  "effect_type": "powerup",
  "amount": 2
}
```

**Power decrease (debuff):**
```json
{
  "timing": "during_strike",
  "effect_type": "powerup",
  "amount": -1
}
```

**Conditional power boost:**
```json
{
  "timing": "during_strike",
  "condition": "is_critical",
  "effect_type": "powerup",
  "amount": 3
}
```

## Implementation Notes

- Power bonus is applied to `strike_stat_boosts.power`
- Stacks with other power effects
- Can be modified by multiplier effects like `multiply_positive_power_bonuses`
- Negative amounts reduce power (minimum 0 total power)

## Related Effects

- [powerup_both_players](powerup_both_players.md) - Increase power for both players
- [powerup_per_boost_in_play](powerup_per_boost_in_play.md) - Power based on boosts
- [powerup_per_card_in_hand](powerup_per_card_in_hand.md) - Power based on hand size
- [multiply_positive_power_bonuses](multiply_positive_power_bonuses.md) - Multiply power bonuses

## Real Usage Examples

From card definitions:
- Akuma's "Gohadoken": `{ "timing": "during_strike", "effect_type": "powerup", "amount": -2 }`
- Ragna's "Hell's Fang": `{ "timing": "hit", "effect_type": "powerup", "amount": 2 }`
- Sol Badguy's "Tyrant Rave": `{ "timing": "during_strike", "effect_type": "powerup", "amount": 3 }`