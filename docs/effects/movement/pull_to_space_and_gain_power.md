# pull_to_space_and_gain_power

**Category**: Movement
**Description**: Pull the opponent to a specific arena space and gain power equal to the distance pulled.

## Parameters

- `amount` (required): Target arena space to pull opponent to
  - **Type**: Integer
  - **Range**: 1-9 (valid arena spaces)

## Supported Timings

- `hit` - When attack hits
- `during_strike` - During strike resolution

## Examples

**Pull to space 3 with power gain:**
```json
{
  "timing": "hit",
  "effect_type": "pull_to_space_and_gain_power",
  "amount": 3
}
```

**Pull to space 6:**
```json
{
  "timing": "during_strike",
  "effect_type": "pull_to_space_and_gain_power",
  "amount": 6
}
```

## Implementation Notes

- Calculates the distance between opponent's current position and target space
- Pulls opponent to the specified arena space
- Grants power equal to the number of spaces the opponent was pulled
- If opponent is already at target space, no movement or power gain occurs
- Power gain is applied immediately after the pull movement
- Cannot pull opponent to a space occupied by the performing player

## Related Effects

- [pull_any_number_of_spaces_and_gain_power](pull_any_number_of_spaces_and_gain_power.md) - Choose pull distance with power gain
- [pull](pull.md) - Basic pull movement without power gain
- [move_to_space](move_to_space.md) - Move self to specific space
- [powerup](../stats/powerup.md) - Basic power increase effect

## Real Usage Examples

From card definitions:
- Used internally by pull_any_number_of_spaces_and_gain_power effect
- Strategic positioning with immediate power reward
- Combines movement control with offensive enhancement