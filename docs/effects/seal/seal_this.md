# SealThis

**Category**: Seal and Transform
**Description**: Seals the current card (either a boost or attack) during cleanup instead of its normal cleanup behavior.

## Parameters

- `card_name` (optional): Specific name of the card to seal, for logging purposes
  - **Type**: String
  - **Default**: Uses the current card's name

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- `cleanup` - Applied during cleanup phase
- `after` - Applied after strike resolution
- `hit` - Applied when attack hits

## Examples

**Basic sealing:**
```json
{
  "timing": "immediate",
  "effect_type": "seal_this"
}
```

**Seal on hit:**
```json
{
  "timing": "hit",
  "condition": "hit_opponent",
  "effect_type": "seal_this"
}
```

**Seal with specific card name:**
```json
{
  "timing": "after",
  "effect_type": "seal_this",
  "card_name": "Gun Down"
}
```

**Seal during cleanup:**
```json
{
  "timing": "cleanup",
  "effect_type": "seal_this",
  "and": {
    "effect_type": "draw",
    "amount": 1
  }
}
```

## Implementation Notes

- Behavior depends on the context where it's used:
  - If used within a boost: Sets the `seal_on_cleanup` flag for that boost
  - If used within an attack: Sets the `seal_attack_on_cleanup` flag for the performing player
- During cleanup, the flagged card is moved to sealed area instead of normal cleanup destination
- The sealed area may be secret (face-down) depending on character settings
- Creates appropriate log messages describing the sealing action
- Can be combined with other effects using `and` clauses
- Only affects the current card being processed

## Related Effects

- [`seal_attack_on_cleanup`](seal_attack_on_cleanup.md) - Specifically seals attack cards
- [`seal_this_boost`](seal_this_boost.md) - Seals a specific boost card
- [`discard_this`](../cards/discard_this.md) - Alternative cleanup behavior
- [`seal_continuous_boosts`](seal_continuous_boosts.md) - Seals all continuous boosts

## Real Usage Examples

From card definitions:
- Various character special attacks: Seal themselves after use to prevent reuse
- Powerful boost cards: Seal themselves after providing their effect
- Conditional sealing: Cards that seal themselves only when certain conditions are met (e.g., on hit)
- Hyde's attacks: Multiple cards that seal themselves after cleanup
- Strategic context: Allows cards to provide powerful one-time effects while ensuring they can't be easily reused, or to build up sealed card resources for other effects