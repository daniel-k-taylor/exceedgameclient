# ignore_push_and_pull

**Category**: Attack
**Description**: Attack ignores push and pull effects, making the character unable to be moved by the opponent during this strike.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution

## Examples

**Basic push and pull immunity:**
```json
{
  "timing": "during_strike",
  "effect_type": "ignore_push_and_pull"
}
```

**Combined with stun immunity:**
```json
{
  "timing": "during_strike",
  "effect_type": "ignore_push_and_pull",
  "and": {
    "effect_type": "stun_immunity"
  }
}
```

**Conditional push/pull ignore:**
```json
{
  "condition": "is_critical",
  "effect_type": "ignore_push_and_pull"
}
```

## Implementation Notes

- Sets `strike_stat_boosts.ignore_push_and_pull = true`
- Only affects this specific strike, not ongoing passive effects
- Prevents opponent from moving the character with push, pull, close, retreat effects
- Does not affect the character's own movement abilities
- Commonly found on heavy, grounded, or rooted attacks
- Can be combined with other defensive strike effects

## Related Effects

- [ignore_push_and_pull_passive_bonus](ignore_push_and_pull_passive_bonus.md) - Passive movement resistance
- [remove_ignore_push_and_pull_passive_bonus](remove_ignore_push_and_pull_passive_bonus.md) - Remove passive resistance
- [stun_immunity](stun_immunity.md) - Ignore stun effects
- [ignore_armor](ignore_armor.md) - Ignore opponent's armor

## Real Usage Examples

From card definitions:
- Guile's "Sonic Hurricane": `{ "timing": "during_strike", "effect_type": "ignore_push_and_pull" }`
- Akuma's "Demon Armageddon": Combined with stun immunity for unstoppable attacks
- Jin's "Ice Car": Heavy ice attacks that can't be interrupted by movement
- Various heavy/grounded characters: Immovable stance attacks