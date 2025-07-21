# higher_speed_misses

**Category**: Attack
**Description**: Attack misses if the opponent's speed is higher than or equal to a specified threshold.

## Parameters

- `dodge_at_speed_greater_or_equal` (optional): Speed threshold for dodging
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Default**: Uses effect-specific logic if not specified

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic speed dodge:**
```json
{
  "timing": "during_strike",
  "effect_type": "higher_speed_misses"
}
```

**Speed threshold dodge:**
```json
{
  "timing": "during_strike",
  "effect_type": "higher_speed_misses",
  "dodge_at_speed_greater_or_equal": 5
}
```

**High-speed dodge:**
```json
{
  "timing": "during_strike",
  "effect_type": "higher_speed_misses",
  "dodge_at_speed_greater_or_equal": 6
}
```

## Implementation Notes

- Sets `strike_stat_boosts.higher_speed_misses = true`
- Compares opponent's final speed against the threshold
- Attack automatically misses if opponent meets or exceeds speed requirement
- Useful for slow but powerful attacks that can be dodged by fast opponents
- Speed comparison includes all bonuses and modifications
- Creates appropriate miss events and log messages
- Represents agility-based evasion mechanics

## Related Effects

- [dodge_attacks](dodge_attacks.md) - Complete attack evasion
- [dodge_at_range](dodge_at_range.md) - Range-based dodging
- [dodge_normals](dodge_normals.md) - Dodge only normal attacks
- [speedup](../stats/speedup.md) - Increase speed to avoid this effect

## Real Usage Examples

From card definitions:
- Akuma's "Demon Armageddon": `{ "timing": "during_strike", "effect_type": "higher_speed_misses", "dodge_at_speed_greater_or_equal": 5 }`
- Various heavy/slow attacks: Can be dodged by fast characters
- Boss attacks: Powerful but avoidable with sufficient speed
- Grappling moves: Can be escaped with high agility