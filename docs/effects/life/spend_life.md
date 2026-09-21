# SpendLife

**Category**: Life and Damage
**Description**: Reduces the character's life by a specified amount for strategic purposes or card costs.

## Parameters

- `amount` (required): Amount of life to spend
  - **Type**: Integer
  - **Range**: Any positive integer
  - **Special Notes**: Effect calls the player's spend_life() method which handles validation and tracking

## Supported Timings

- `immediate` - Immediately when played or triggered
- `choice` - As part of a choice option for the player
- `now` - When effect is processed immediately
- `before` - Before other effects or strikes

## Examples

**Basic life spending:**
```json
{
  "effect_type": "spend_life",
  "amount": 1
}
```

**Life spending with benefit:**
```json
{
  "effect_type": "spend_life",
  "amount": 1,
  "and": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

**Multiple choice life spending:**
```json
{
  "choice": [
    { "effect_type": "spend_life", "amount": 1, "and": { "effect_type": "draw", "amount": 1 } },
    { "effect_type": "spend_life", "amount": 2, "and": { "effect_type": "draw", "amount": 2 } },
    { "effect_type": "spend_life", "amount": 3, "and": { "effect_type": "draw", "amount": 3 } },
    { "effect_type": "pass" }
  ]
}
```

**Life spending for power:**
```json
{
  "choice": [
    { "effect_type": "spend_life", "amount": 1, "and": { "effect_type": "powerup", "amount": 1 } },
    { "effect_type": "spend_life", "amount": 2, "and": { "effect_type": "powerup", "amount": 2 } },
    { "effect_type": "pass" }
  ]
}
```

## Implementation Notes

- Uses the player's spend_life() method which handles life validation and tracking
- Tracks the amount spent in last_spent_life for potential recovery effects
- A life payment must leave at least 1 life. Paying exactly the current life, overpaying, or paying a negative amount is rejected without changing life or triggering on-death effects.
- Unaffordable `spend_life` choices are disabled in the UI and excluded from AI choices; submitting one directly is also rejected.
- If a mandatory life payment cannot be made, its chained `and` benefit does not resolve. No partial payment is taken.
- Life-for-force, life-for-gauge, infusion, and alternative life costs use the same nonlethal payment rule.
- Often used as a cost for powerful effects or abilities
- Commonly paired with choice effects to let players decide how much to spend
- Creates appropriate log messages for life spending

## Related Effects

- [gain_life](gain_life.md) - Opposite effect that increases life
- [take_damage](take_damage.md) - Reduces life through damage rather than spending
- [can_spend_life_for_force](../special/can_spend_life_for_force.md) - Enables life spending for force bonuses

## Real Usage Examples

From card definitions:
- Sydney's effect: `{ "effect_type": "spend_life", "amount": 1 }` for card activation
- Emogine's choices: Multiple spend_life options with varying amounts and benefits
- Custom cards: `{ "effect_type": "spend_life", "amount": 1, "and": { "effect_type": "draw", "amount": 1 } }`
- Risk/reward mechanics: Spend life for immediate power or card advantage
- Strategic resource management: Players choose between preserving life or gaining benefits
- Character-specific abilities: Some characters have synergies with life spending mechanics