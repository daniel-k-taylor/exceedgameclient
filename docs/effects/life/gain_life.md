# GainLife

**Category**: Life and Damage
**Description**: Increases the character's life by a specified amount up to the maximum life limit.

## Parameters

- `amount` (required): Amount of life to gain
  - **Type**: Integer or String
  - **Range**: Any positive integer
  - **Special Values**: "LAST_SPENT_LIFE" - Gain life equal to the last amount of life spent by the character

## Supported Timings

- `hit` - When attack hits opponent
- `after` - After strike resolution
- `timing` - Any other timing context where life gain is needed
- `immediate` - Immediately when triggered

## Examples

**Basic life gain:**
```json
{
  "timing": "hit",
  "effect_type": "gain_life",
  "amount": 2
}
```

**Life gain using last spent life:**
```json
{
  "timing": "on_spend_life",
  "effect_type": "gain_life",
  "amount": "LAST_SPENT_LIFE"
}
```

**Conditional life gain:**
```json
{
  "condition": "life_less_than_opponent",
  "effect_type": "gain_life",
  "amount": 2
}
```

**Life gain with chain effect:**
```json
{
  "timing": "hit",
  "effect_type": "gain_life",
  "amount": 4,
  "and": {
    "effect_type": "powerup",
    "amount": 1
  }
}
```

## Implementation Notes

- Life cannot exceed the maximum life limit (Enums.MaxLife)
- Creates appropriate log message indicating life gained and new total
- Triggers EventType_Strike_GainLife event for UI updates
- Can be combined with other effects using "and" chains
- The "LAST_SPENT_LIFE" special value tracks the most recent spend_life effect amount

## Related Effects

- [spend_life](spend_life.md) - Opposite effect that reduces life
- [take_damage](take_damage.md) - Reduces life through damage mechanics
- [set_life_per_gauge](set_life_per_gauge.md) - Sets life based on gauge count

## Real Usage Examples

From card definitions:
- Ragna's passive: `{ "character_effect": true, "effect_type": "gain_life", "amount": 1 }`
- Sydney's conditional effect: `{ "condition_amount": 10, "effect_type": "gain_life", "amount": 5 }`
- Hazama's overdrive: `{ "effect_type": "gain_life", "amount": 1 }` after taking damage
- Various healing cards: Life restoration as hit effects or conditional triggers
- Self-sustain mechanics: Characters that gain life when performing certain actions