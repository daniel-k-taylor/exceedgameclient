# stun_immunity

**Category**: Attack
**Description**: Grant immunity to stun effects, preventing the character from being stunned during this strike.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution
- `now` - Immediately when played

## Examples

**Basic stun immunity:**
```json
{
  "timing": "during_strike",
  "effect_type": "stun_immunity"
}
```

**Combined with other immunities:**
```json
{
  "timing": "during_strike",
  "effect_type": "stun_immunity",
  "and": {
    "effect_type": "ignore_push_and_pull"
  }
}
```

**Conditional immunity:**
```json
{
  "condition": "is_critical",
  "effect_type": "stun_immunity"
}
```

**Exceeded state immunity:**
```json
{
  "condition": "exceeded",
  "effect_type": "stun_immunity"
}
```

## Implementation Notes

- Sets `strike_stat_boosts.stun_immunity = true`
- Prevents character from being stunned during this strike
- Does not create log messages (silent immunity)
- Often combined with other defensive effects
- Commonly used on powerful attacks to prevent interruption
- Useful for maintaining offensive pressure
- Frequently appears on exceed effects and critical conditions
- Stacks with other defensive immunities

## Related Effects

- [ignore_push_and_pull](ignore_push_and_pull.md) - Immunity to movement effects
- [dodge_attacks](dodge_attacks.md) - Complete attack evasion
- [ignore_armor](ignore_armor.md) - Ignore opponent's armor
- [cannot_stun](../protection/cannot_stun.md) - Permanent stun protection

## Real Usage Examples

From card definitions:
- Many powerful attacks: `{ "timing": "during_strike", "effect_type": "stun_immunity" }`
- Exceed effects: Enhanced immunity when exceeded
- Critical conditions: Immunity during critical strikes
- Heavy attacks: Preventing interruption of slow, powerful moves
- Boss attacks: Unstoppable finishing moves