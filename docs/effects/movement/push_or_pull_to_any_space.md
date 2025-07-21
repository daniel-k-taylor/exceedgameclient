# push_or_pull_to_any_space

**Category**: Movement
**Description**: Present the player with choices to push or pull the opponent to any valid arena space.

## Parameters

- No direct parameters - effect generates choices dynamically

## Supported Timings

- `hit` - When attack hits

## Examples

**Basic push or pull to any space:**
```json
{
  "timing": "hit",
  "effect_type": "push_or_pull_to_any_space"
}
```

## Implementation Notes

- Creates a decision choice for the player with options for each valid arena space (1-9)
- Each choice option uses [`push_or_pull_to_space`](push_or_pull_to_space.md) internally
- Automatically excludes spaces occupied by characters
- Player chooses the optimal target space based on strategic positioning needs
- The effect determines whether to push or pull based on which direction moves opponent toward target
- Provides maximum tactical flexibility for positioning

## Related Effects

- [push_or_pull_to_space](push_or_pull_to_space.md) - Push or pull to specific space
- [move_to_any_space](move_to_any_space.md) - Move self to any space
- [pull_any_number_of_spaces_and_gain_power](pull_any_number_of_spaces_and_gain_power.md) - Pull with power gain
- [push](push.md) - Basic push movement
- [pull](pull.md) - Basic pull movement

## Real Usage Examples

From card definitions:
- Various fighter cards: `{ "timing": "hit", "effect_type": "push_or_pull_to_any_space" }`
- Ultimate positioning control allowing optimal arena management
- Strategic repositioning for follow-up attacks or defensive positioning