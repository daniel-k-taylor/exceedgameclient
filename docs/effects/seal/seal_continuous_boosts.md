# SealContinuousBoosts

**Category**: Seal and Transform
**Description**: Seals all of the player's continuous boost cards to the sealed area.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- `now` - Can be applied at the current moment
- `cleanup` - Can be applied during cleanup phase

## Examples

**Basic usage:**
```json
{
  "timing": "immediate",
  "effect_type": "seal_continuous_boosts"
}
```

**Combined with other effects:**
```json
{
  "effect_type": "powerup",
  "amount": 2,
  "and": {
    "effect_type": "seal_continuous_boosts"
  }
}
```

**Used in character exceed:**
```json
{
  "effect_type": "draw",
  "amount": 2,
  "and": {
    "effect_type": "seal_continuous_boosts"
  }
}
```

## Implementation Notes

- Seals all cards currently in the player's continuous_boosts array
- Each boost card is removed from continuous boosts and moved to the sealed area with destination "sealed"
- Creates log messages for each card that is sealed
- Cards are processed in order, so earlier boosts are sealed first
- Boost effects are immediately removed when cards are sealed
- The sealed area may be secret (face-down) depending on character settings
- Does not affect transform cards or other types of boosts

## Related Effects

- [`seal_this_boost`](seal_this_boost.md) - Seals a specific boost card
- [`discard_continuous_boost`](../cards/discard_continuous_boost.md) - Discards instead of sealing
- [`sustain_all_boosts`](../boost/sustain_all_boosts.md) - Opposite effect - preserves boosts
- [`boost_additional`](../boost/boost_additional.md) - Creates continuous boosts

## Real Usage Examples

From card definitions:
- Various character exceed abilities: Used to clear all continuous boosts when exceeding
- Powerful attack effects: Trade away accumulated boosts for immediate power
- Reset mechanics: Clear the board state of continuous effects
- Strategic context: Allows players to convert temporary continuous effects into sealed cards that may have different strategic value, or to clear the board when transitioning to a new game phase