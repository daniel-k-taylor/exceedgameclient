# dodge_normals

**Category**: Attack
**Description**: Dodge only normal attacks, automatically avoiding them while still being vulnerable to special and ultra attacks.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic normal dodge:**
```json
{
  "timing": "during_strike",
  "effect_type": "dodge_normals"
}
```

**Combined with other defenses:**
```json
{
  "timing": "during_strike",
  "effect_type": "dodge_normals",
  "and": {
    "effect_type": "stun_immunity"
  }
}
```

**Conditional normal dodging:**
```json
{
  "condition": "is_ex",
  "effect_type": "dodge_normals"
}
```

## Implementation Notes

- Sets `strike_stat_boosts.dodge_normals = true`
- Only affects normal attacks, not special or ultra attacks
- Creates selective evasion against basic attacks
- Useful for characters that are vulnerable to powerful attacks but agile against basics
- Does not create log messages (silent evasion)
- Commonly used on fast or evasive characters
- Balances defensive capabilities by maintaining vulnerability to stronger attacks

## Related Effects

- [dodge_attacks](dodge_attacks.md) - Dodge all attacks
- [dodge_at_range](dodge_at_range.md) - Range-based dodging
- [dodge_from_opposite_buddy](dodge_from_opposite_buddy.md) - Positional dodging
- [higher_speed_misses](higher_speed_misses.md) - Speed-based evasion

## Real Usage Examples

From card definitions:
- Enkidu's agility techniques: `{ "timing": "during_strike", "effect_type": "dodge_normals" }`
- Fast characters: Avoiding basic attacks while remaining vulnerable to specials
- Evasion specialists: Selective defensive mechanics
- Anti-pressure tools: Countering normal attack spam