# immediate_force_for_armor

**Category**: Gauge and Force
**Description**: Immediately triggers a force-for-armor decision allowing a player to spend force to reduce incoming damage.

## Parameters

- `amount` (required): Maximum amount of force that can be spent for armor
  - **Type**: Integer
  - **Range**: Any positive integer
- `opponent` (optional): If true, triggers the decision for the opponent instead of the performing player
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `before` - Before strike resolution
- `during_strike` - During strike resolution
- `immediate` - Immediately when triggered

## Examples

**Basic self-defense:**
```json
{
  "timing": "during_strike",
  "effect_type": "immediate_force_for_armor",
  "amount": 3
}
```

**Opponent force spending:**
```json
{
  "timing": "before",
  "effect_type": "immediate_force_for_armor",
  "opponent": true,
  "amount": 2
}
```

**Combined with other effects:**
```json
{
  "timing": "during_strike",
  "and": {
    "effect_type": "immediate_force_for_armor",
    "opponent": true,
    "amount": 2
  }
}
```

## Implementation Notes

- Calculates incoming damage for the defending player before triggering the decision
- Changes game state to PlayerDecision and sets up a ForceForArmor decision type
- The defending player can choose to spend up to the specified amount of force
- Each point of force typically reduces incoming damage by 1 point
- The decision is mandatory - the player must choose how much force to spend (including 0)
- Creates appropriate game events and UI prompts for the force-spending decision
- Takes into account any armor-ignoring effects that may be active
- The limitation is set to "force" to indicate only force can be spent, not gauge

## Related Effects

- [`when_hit_force_for_armor`](when_hit_force_for_armor.md) - Sets up conditional force-for-armor that triggers when hit
- [`force_for_effect`](force_for_effect.md) - Generates force for other purposes
- [`armorup`](../stats/armorup.md) - Alternative armor-gaining effect
- [`ignore_armor`](../attack/ignore_armor.md) - Negates armor effects

## Real Usage Examples

From card definitions:
- Defensive cards: `{ "effect_type": "immediate_force_for_armor", "opponent": true, "amount": 2 }` - Forcing opponent to spend resources
- Emergency defense systems: Allowing immediate damage mitigation during critical strikes
- Resource management cards: Strategic force spending for survival in high-damage situations