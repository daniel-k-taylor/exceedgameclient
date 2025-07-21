# remove_ignore_push_and_pull_passive_bonus

**Category**: Attack
**Description**: Remove one stack of the passive bonus that grants resistance to push and pull effects.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `during_strike` - During strike resolution
- `now` - Immediately when played
- `after` - After strike resolution

## Examples

**Basic passive resistance removal:**
```json
{
  "timing": "now",
  "effect_type": "remove_ignore_push_and_pull_passive_bonus"
}
```

**Remove resistance after opponent strikes:**
```json
{
  "timing": "after",
  "effect_type": "remove_ignore_push_and_pull_passive_bonus"
}
```

**Conditional resistance removal:**
```json
{
  "condition": "opponent_exceeded",
  "effect_type": "remove_ignore_push_and_pull_passive_bonus"
}
```

## Implementation Notes

- Decrements `performing_player.ignore_push_and_pull -= 1`
- Removes one stack of passive push/pull resistance
- Cannot reduce the counter below 0
- Used to balance or counter stacking defensive bonuses
- Prevents indefinite accumulation of movement immunity
- Can be triggered by opponent effects or temporary debuffs
- Useful for balancing characters with strong passive defenses

## Related Effects

- [ignore_push_and_pull_passive_bonus](ignore_push_and_pull_passive_bonus.md) - Grant passive resistance
- [ignore_push_and_pull](ignore_push_and_pull.md) - Temporary strike immunity
- [remove_block_opponent_move](../movement/remove_block_opponent_move.md) - Remove movement blocks

## Real Usage Examples

From card definitions:
- Temporary debuff effects: Reducing opponent's defensive stacks
- Balance mechanics: Preventing infinite stacking of resistances
- Counter-play cards: Removing defensive bonuses
- End-of-turn cleanup: Reducing accumulated bonuses over time