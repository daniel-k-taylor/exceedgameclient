# GainAdvantage

**Category**: Life and Damage
**Description**: Grants the character advantage, making them go first in the next turn's priority order.

## Parameters

This effect takes no parameters.

## Supported Timings

- `hit` - When attack hits opponent
- `after` - After strike resolution
- `condition` - When specific conditions are met
- `character_effect` - As a passive character ability
- `choice` - As part of a choice option

## Examples

**Basic advantage on hit:**
```json
{
  "timing": "hit",
  "effect_type": "gain_advantage"
}
```

**Conditional advantage:**
```json
{
  "condition": "is_critical",
  "effect_type": "gain_advantage"
}
```

**Advantage with chained effect:**
```json
{
  "timing": "hit",
  "effect_type": "gain_advantage",
  "and": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

**Choice-based advantage:**
```json
{
  "choice": [
    { "effect_type": "gain_advantage" },
    { "effect_type": "powerup", "amount": 2 }
  ]
}
```

**Character passive advantage:**
```json
{
  "character_effect": true,
  "effect_type": "gain_advantage"
}
```

## Implementation Notes

- Sets next_turn_player to the performing player's ID
- Creates EventType_Strike_GainAdvantage event for UI updates
- Generates log message indicating advantage gained
- Cannot stack - only determines who goes first next turn
- Does not affect current turn order, only the next turn
- Commonly used as reward for successful attacks or meeting conditions
- Strategic importance varies based on game state and character matchups

## Related Effects

- [first_strike](../special/first_strike.md) - Affects strike order within a turn
- [choice](../choice/choice.md) - Often used to offer advantage as an option
- [critical](../attack/critical.md) - Often grants advantage when triggered

## Real Usage Examples

From card definitions:
- Zato's character effect: `{ "character_effect": true, "effect_type": "gain_advantage" }`
- Noel's hit effect: `{ "timing": "hit", "effect_type": "gain_advantage" }`
- Critical strike rewards: `{ "condition": "is_critical", "effect_type": "gain_advantage" }`
- Millia's retreat combo: `{ "effect_type": "retreat", "amount": 2, "and": { "effect_type": "gain_advantage" } }`
- Conditional advantages: Based on positioning, opponent state, or successful actions
- Choice effects: Players choosing between immediate benefits or turn order control
- Combo finishers: Advantage as reward for successful attack sequences