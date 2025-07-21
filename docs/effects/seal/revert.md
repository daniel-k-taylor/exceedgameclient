# Revert

**Category**: Seal and Transform
**Description**: Reverts the player from their exceeded state back to normal form.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- `cleanup` - Applied during cleanup phase
- Often used conditionally or as part of exceed mechanics

## Examples

**Basic revert:**
```json
{
  "timing": "immediate",
  "effect_type": "revert"
}
```

**Conditional revert (Leo):**
```json
{
  "condition": "no_strike_this_turn",
  "effect_type": "revert"
}
```

**Revert on cleanup:**
```json
{
  "timing": "cleanup",
  "effect_type": "revert"
}
```

**Combined with other effects:**
```json
{
  "effect_type": "powerup",
  "amount": 3,
  "and": {
    "effect_type": "revert"
  }
}
```

## Implementation Notes

- Sets the player's `exceeded` status to false
- Creates log messages describing the reversion
- Creates game events for UI updates
- Triggers any "on_revert" character effects defined in the deck
- Can only be used if the player is currently exceeded
- May trigger additional character-specific abilities when reverting
- Often used as a balancing mechanism for powerful exceed abilities
- Some characters have automatic revert conditions (e.g., empty overdrive)

## Related Effects

- [`exceed_now`](../special/exceed_now.md) - Opposite effect - enter exceed state
- [`exceed_end_of_turn`](../special/exceed_end_of_turn.md) - Delayed exceed
- Character-specific "on_revert" abilities - Triggered when this effect occurs

## Real Usage Examples

From card definitions:
- Leo's conditional revert: Reverts if no strike was made this turn
- Happy Chaos cleanup revert: Automatic revert during cleanup phase
- Various character exceed chains: Revert as part of powerful temporary effects
- Beheaded's transform mechanics: Revert as part of complex transformation chains
- Strategic context: Used to balance powerful exceed abilities by forcing players back to normal state, often with conditional triggers or as part of resource management mechanics