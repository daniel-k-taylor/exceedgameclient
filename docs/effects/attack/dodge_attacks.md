# dodge_attacks

**Category**: Attack
**Description**: Completely avoid all incoming attacks during this strike, making them automatically miss.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution
- `now` - Immediately when played

## Examples

**Basic attack dodging:**
```json
{
  "timing": "during_strike",
  "effect_type": "dodge_attacks"
}
```

**Conditional dodging:**
```json
{
  "condition": "advanced_through",
  "effect_type": "dodge_attacks"
}
```

**Combined with movement:**
```json
{
  "timing": "before",
  "effect_type": "advance",
  "amount": 2,
  "and": {
    "timing": "during_strike",
    "effect_type": "dodge_attacks",
    "condition": "advanced_through"
  }
}
```

## Implementation Notes

- Sets `strike_stat_boosts.dodge_attacks = true`
- Creates "DodgeAttacks" event and log message
- Makes character completely immune to incoming attacks for this strike
- Often combined with movement effects for tactical positioning
- Commonly used with "advanced_through" condition for movement-based dodges
- Creates complete attack immunity regardless of attack type or power
- Useful for escape moves, counter-attacks, or defensive maneuvers

## Related Effects

- [dodge_at_range](dodge_at_range.md) - Dodge attacks at specific ranges
- [dodge_normals](dodge_normals.md) - Dodge only normal attacks
- [dodge_from_opposite_buddy](dodge_from_opposite_buddy.md) - Positional dodging
- [higher_speed_misses](higher_speed_misses.md) - Speed-based evasion

## Real Usage Examples

From card definitions:
- Various mobility characters: `{ "effect_type": "dodge_attacks", "condition": "advanced_through" }`
- Escape techniques: Complete evasion during tactical retreats
- Counter-attack setups: Avoiding damage while setting up responses
- Movement-based dodges: Combining advancement with evasion