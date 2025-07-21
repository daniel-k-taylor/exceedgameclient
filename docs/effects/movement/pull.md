# pull

**Category**: Movement
**Description**: Pull the opponent toward you by a specified amount. Forces the opponent to move closer.

## Parameters

- `amount` (required): Number of spaces to pull the opponent
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic pull:**
```json
{
  "timing": "hit",
  "effect_type": "pull",
  "amount": 1
}
```

**Strong pull:**
```json
{
  "timing": "before",
  "effect_type": "pull",
  "amount": 3
}
```

**Pull on hit:**
```json
{
  "timing": "hit",
  "effect_type": "pull",
  "amount": 2
}
```

## Implementation Notes

- Forces opponent movement, unlike voluntary movement effects
- Movement amount can be modified by opponent's `strike_stat_boosts.increase_move_opponent_effects_by`
- Opponent may not be able to be pulled the full amount due to arena boundaries
- Creates a "pulled" log message and visual effect
- Does not trigger opponent's movement-related character effects
- Can be blocked by certain defensive abilities

## Related Effects

- [push](push.md) - Push opponent away
- [pull_to_range](pull_to_range.md) - Pull to specific range
- [pull_to_buddy](pull_to_buddy.md) - Pull to buddy location
- [close](close.md) - Move toward opponent yourself

## Real Usage Examples

From card definitions:
- Tager's "Gadget Finger": `{ "timing": "hit", "effect_type": "pull", "amount": 2 }`
- Waldstein's "Verfolgung": Pull on hit effects
- Zangief's "Screw Piledriver": Pull for grappling
- Potemkin's "Potemkin Buster": Pull into range for command grabs