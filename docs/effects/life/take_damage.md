# TakeDamage

**Category**: Life and Damage
**Description**: Deals damage to a character, reducing their life and potentially triggering stun or knockout.

## Parameters

- `amount` (required): Amount of damage to deal
  - **Type**: Integer
  - **Range**: Any positive integer

- `opponent` (optional): If true, deals damage to opponent instead of self
  - **Type**: Boolean
  - **Default**: false

- `nonlethal` (optional): If true, damage cannot reduce life below 1
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `immediate` - Immediately when triggered
- `after` - After strike resolution
- `both_players_after` - After strike resolution for both players
- `condition` - When specific conditions are met
- `hit` - When attack connects (less common for damage effects)

## Examples

**Basic damage to self:**
```json
{
  "effect_type": "take_damage",
  "nonlethal": true,
  "amount": 1
}
```

**Damage to opponent:**
```json
{
  "effect_type": "take_damage",
  "opponent": true,
  "amount": 2
}
```

**Conditional damage:**
```json
{
  "condition": "opponent_stunned",
  "effect_type": "take_damage",
  "opponent": true,
  "amount": 1
}
```

**Nonlethal self-damage:**
```json
{
  "timing": "immediate",
  "effect_type": "take_damage",
  "nonlethal": true,
  "amount": 5
}
```

**Movement-based damage:**
```json
{
  "condition": "moved_less_than",
  "condition_amount": 2,
  "effect_type": "take_damage",
  "nonlethal": true,
  "amount": 5
}
```

## Implementation Notes

- Damage is reduced by armor during active strikes
- Tracks consumed armor for strike statistics
- Nonlethal damage cannot reduce life below 1
- Creates EventType_Strike_TookDamage event for UI updates
- Generates appropriate log messages with damage amounts and armor blocking
- Can trigger stun checks during active strikes
- May trigger game over if life reaches 0
- Some characters have special passives that convert damage to card discarding

## Related Effects

- [gain_life](gain_life.md) - Opposite effect that increases life
- [spend_life](spend_life.md) - Voluntary life reduction for benefits
- [armorup](../stats/armorup.md) - Provides damage reduction
- [stun](../special/stun.md) - Can be triggered by high damage

## Real Usage Examples

From card definitions:
- Ragna's overdrive: `{ "effect_type": "take_damage", "nonlethal": true, "amount": 1 }`
- Hazama's overdrive: Self-damage as cost for powerful effects
- Conditional damage: `{ "condition": "opponent_stunned", "effect_type": "take_damage", "opponent": true, "amount": 1 }`
- Movement penalties: Damage for failing to move minimum distances
- Continuous effects: Both players taking damage over time
- Trap effects: Characters taking damage when specific conditions trigger
- Risk/reward mechanics: Self-damage for powerful abilities