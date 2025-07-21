# pull_not_past

**Category**: Movement
**Description**: Pull the opponent by a specified amount without allowing them to move past the performing character.

## Parameters

- `amount` (required): Number of spaces to pull the opponent
  - **Type**: Integer
  - **Range**: Any positive integer

## Supported Timings

- `before` - Before strike resolution
- `hit` - When attack hits
- `after` - After strike resolution

## Examples

**Basic pull not past:**
```json
{
  "timing": "before",
  "effect_type": "pull_not_past",
  "amount": 8
}
```

**Pull on hit:**
```json
{
  "timing": "hit",
  "effect_type": "pull_not_past",
  "amount": 3
}
```

**Conditional pull:**
```json
{
  "condition": "was_hit",
  "effect_type": "pull_not_past",
  "amount": 2
}
```

## Implementation Notes

- Pulls opponent toward the performing character but stops before they would move past
- If opponent would be pulled past the performing character's position, they stop adjacent instead
- Useful for controlling opponent positioning without allowing them to get behind you
- Respects arena boundaries (spaces 1-9)
- Creates appropriate log messages showing the movement restriction

## Related Effects

- [pull](pull.md) - Basic pull movement without position restriction
- [pull_to_range](pull_to_range.md) - Pull opponent to attack range
- [push](push.md) - Push opponent away
- [close](close.md) - Move toward opponent

## Real Usage Examples

From card definitions:
- Baiken's cards: `{ "effect_type": "pull_not_past", "amount": 2 }`
- Various character abilities: `{ "timing": "before", "effect_type": "pull_not_past", "amount": 8 }`
- Defensive positioning: `{ "timing": "hit", "effect_type": "pull_not_past", "amount": 3 }`
- Used for tactical control without allowing opponent to cross over