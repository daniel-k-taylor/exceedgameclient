# SidestepTransparentFoe

**Category**: Utility
**Description**: Allows the player to choose a card name to make transparent during strikes, causing those cards to be ignored.

## Parameters

This effect takes no parameters.

## Supported Timings

- `now` - Immediately when the effect is triggered

## Examples

**Basic usage:**
```json
{
  "timing": "now",
  "effect_type": "sidestep_transparent_foe"
}
```

**Combined with dialogue:**
```json
{
  "timing": "now",
  "effect_type": "sidestep_transparent_foe"
},
{
  "timing": "during_strike",
  "effect_type": "sidestep_dialogue"
}
```

## Implementation Notes

- Changes game state to PlayerDecision and creates a sidestep decision for the player
- Uses `DecisionType_Sidestep` with effect type `SidestepInternal` for resolution
- Creates a `EventType_Boost_Sidestep` event for UI feedback
- The actual card naming and transparency application is handled by `SidestepInternal`
- Player must choose a specific card name to make transparent during strikes
- Transparent cards are effectively ignored during strike resolution

## Related Effects

- [`sidestep_internal`](sidestep_internal.md) - Internal implementation of the sidestep choice
- [`sidestep_dialogue`](sidestep_dialogue.md) - UI dialogue component for sidestep
- [`zero_vector`](zero_vector.md) - Similar card-naming mechanic with different effects

## Real Usage Examples

From card definitions:
- Character boost cards: Used to neutralize specific opponent threats
- Defensive abilities: `"timing": "now", "effect_type": "sidestep_transparent_foe"`
- Strategic disruption: Allows players to counter known opponent card strategies