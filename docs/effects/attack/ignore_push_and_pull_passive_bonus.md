# ignore_push_and_pull_passive_bonus

**Category**: Attack
**Description**: Grant a permanent passive bonus that makes the character more resistant to push and pull effects.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution
- `now` - Immediately when played
- `after` - After strike resolution

## Examples

**Basic passive resistance:**
```json
{
  "timing": "now",
  "effect_type": "ignore_push_and_pull_passive_bonus"
}
```

**Gain resistance after striking:**
```json
{
  "timing": "after",
  "effect_type": "ignore_push_and_pull_passive_bonus"
}
```

**Combined with other passive effects:**
```json
{
  "timing": "during_strike",
  "effect_type": "ignore_push_and_pull_passive_bonus",
  "and": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

## Implementation Notes

- Increments `performing_player.ignore_push_and_pull += 1`
- Creates a permanent passive bonus that stacks
- Different from temporary strike-only immunity
- Can be stacked multiple times for greater resistance
- Persists across multiple strikes and turns
- Can be removed by `remove_ignore_push_and_pull_passive_bonus` effect
- Affects character's overall movement resistance, not just during strikes

## Related Effects

- [ignore_push_and_pull](ignore_push_and_pull.md) - Temporary strike immunity
- [remove_ignore_push_and_pull_passive_bonus](remove_ignore_push_and_pull_passive_bonus.md) - Remove this passive bonus
- [block_opponent_move](../movement/block_opponent_move.md) - Block opponent movement entirely

## Real Usage Examples

From card definitions:
- Various defensive characters: Builds up movement resistance over time
- Heavy/tank characters: Passive stability bonuses
- Defensive stance cards: Long-term positioning control
- Exceed effects: Permanent character improvements