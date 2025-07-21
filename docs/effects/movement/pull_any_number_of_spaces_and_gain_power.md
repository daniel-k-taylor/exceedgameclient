# pull_any_number_of_spaces_and_gain_power

**Category**: Movement
**Description**: Present the player with choices to pull the opponent any number of spaces and gain power equal to the amount pulled.

## Parameters

- No direct parameters - effect generates choices dynamically

## Supported Timings

- `hit` - When attack hits

## Examples

**Basic pull with power gain:**
```json
{
  "timing": "hit",
  "effect_type": "pull_any_number_of_spaces_and_gain_power"
}
```

## Implementation Notes

- Creates a decision choice for the player with options to pull 1-8 spaces
- Each choice option grants power equal to the number of spaces pulled
- Uses [`pull_to_space_and_gain_power`](pull_to_space_and_gain_power.md) internally for each choice
- Automatically calculates valid pull distances based on current arena positions
- Player can choose the optimal pull distance based on strategic needs
- Power gain is immediate when choice is selected

## Related Effects

- [pull_to_space_and_gain_power](pull_to_space_and_gain_power.md) - Pull to specific space with power gain
- [pull](pull.md) - Basic pull movement
- [pull_to_range](pull_to_range.md) - Pull opponent to attack range
- [powerup](../stats/powerup.md) - Basic power increase effect

## Real Usage Examples

From card definitions:
- Various fighter cards: `{ "timing": "hit", "effect_type": "pull_any_number_of_spaces_and_gain_power" }`
- Used for tactical positioning where player gains power based on how far they pull opponent
- Strategic choice between maximum power gain vs optimal positioning