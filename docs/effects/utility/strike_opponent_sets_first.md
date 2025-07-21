# StrikeOpponentSetsFirst

**Category**: Utility (also classified under Special Mechanics)
**Description**: Forces the opponent to set their strike card first, providing information advantage.

## Parameters

This effect takes no parameters.

## Supported Timings

- `now` - Immediately when the effect is triggered

## Examples

**Basic opponent sets first:**
```json
{
  "timing": "now",
  "effect_type": "strike_opponent_sets_first"
}
```

**In choice effects:**
```json
{
  "choice": [
    { "effect_type": "strike_opponent_sets_first" },
    { "effect_type": "pass" }
  ]
}
```

**Combined usage:**
```json
{
  "timing": "now",
  "effect_type": "strike_opponent_sets_first"
},
{
  "timing": "after",
  "effect_type": "powerup",
  "amount": 1
}
```

## Implementation Notes

- Creates an `EventType_Strike_OpponentSetsFirst` event
- Changes the strike setting order for the current strike sequence
- Opponent must reveal their strike choice before you set yours
- Provides significant strategic advantage by allowing reactive strike selection
- Effect applies only to the immediate next strike sequence
- Can be combined with other effects for powerful information-based strategies

## Related Effects

- [`strike_effect_after_opponent_sets`](strike_effect_after_opponent_sets.md) - Effects that trigger after opponent sets
- [`strike_faceup`](strike_faceup.md) - Another information-revealing mechanic
- [`strike_from_gauge`](strike_from_gauge.md) - Alternative strike source

## Real Usage Examples

From card definitions:
- Choice cards: `{ "effect_type": "strike_opponent_sets_first" }` as an option
- Strategic boosts: `"timing": "now", "effect_type": "strike_opponent_sets_first"`
- Information warfare: Used to gain advantage in strike timing mind games
- Defensive cards: Allows reactive strike selection based on opponent's choice