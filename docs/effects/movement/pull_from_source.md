# pull_from_source

**Category**: Movement
**Description**: Pull the opponent toward the attack source location by a specified amount.

## Parameters

- `amount` (required): Number of spaces to pull the opponent toward the attack source
  - **Type**: Integer
  - **Range**: Any positive integer
- `skip_if_on_source` (optional): Skip the effect if opponent is already at the attack source
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `hit` - When attack hits
- `during_strike` - During strike resolution

## Examples

**Basic pull from source:**
```json
{
  "timing": "hit",
  "effect_type": "pull_from_source",
  "amount": 3
}
```

**Pull with skip condition:**
```json
{
  "effect_type": "pull_from_source",
  "amount": 1,
  "skip_if_on_source": true
}
```

**Choice-based pull:**
```json
{
  "choice": [
    { "effect_type": "pull_from_source", "amount": 1, "skip_if_on_source": true },
    { "effect_type": "pull_from_source", "amount": 2, "skip_if_on_source": true },
    { "effect_type": "pull_from_source", "amount": 3, "skip_if_on_source": true },
    { "effect_type": "pass" }
  ]
}
```

## Implementation Notes

- Uses `get_attack_origin()` to determine the source location of the attack
- Pulls opponent toward that source location rather than toward the performing character
- Useful for attacks that originate from projectiles, buddies, or other sources
- If `skip_if_on_source` is true, no movement occurs if opponent is already at source
- Respects arena boundaries and cannot move opponent to occupied spaces

## Related Effects

- [pull](pull.md) - Basic pull toward performing character
- [push_from_source](push_from_source.md) - Push away from attack source
- [pull_to_buddy](pull_to_buddy.md) - Pull toward specific buddy
- [move_to_space](move_to_space.md) - Move to specific arena position

## Real Usage Examples

From card definitions:
- Various character cards: `{ "timing": "hit", "effect_type": "pull_from_source", "amount": 3 }`
- Choice effects: Multiple pull_from_source options with different amounts
- Projectile attacks: Pull opponent toward where projectile originated
- Buddy-based attacks: Pull toward buddy that performed the attack