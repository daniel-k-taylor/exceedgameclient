# ReadingNormal

**Category**: Seal and Transform
**Description**: Initiates a Reading effect that forces the opponent to strike with a specific normal card or reveal their hand.

## Parameters

This effect has no parameters when used directly. The specific card to "read" is determined by the context or additional effects.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- Cannot be used during a strike (Reading is a pre-strike effect)

## Examples

**Basic usage:**
```json
{
  "timing": "immediate",
  "effect_type": "reading_normal"
}
```

**Character ability:**
```json
{
  "effect_type": "powerup",
  "amount": 1,
  "and": {
    "effect_type": "reading_normal"
  }
}
```

**Special attack effect:**
```json
{
  "timing": "immediate",
  "effect_type": "reading_normal"
}
```

## Implementation Notes

- Cannot be activated during an active strike
- Creates a Reading Normal decision for the player
- Sets up the game state to wait for opponent's response during their next strike opportunity
- The effect is processed through [`ReadingNormalInternal`](reading_normal_internal.md) for the actual implementation
- Forces the opponent to either strike with the named card (if they have it) or reveal their hand
- The specific card being "read" is typically determined by game context or card selection
- Creates appropriate game events for UI updates

## Related Effects

- [`reading_normal_internal`](reading_normal_internal.md) - Internal implementation of the reading effect
- [`strike_response_reading`](../special/strike_response_reading.md) - How opponents respond to reading
- [`reveal_hand`](../cards/reveal_hand.md) - Alternative outcome when opponent doesn't have the card

## Real Usage Examples

From card definitions:
- Various character abilities: Force opponent to use specific cards or reveal information
- Strategic pressure tools: Limit opponent's strike options by targeting specific cards
- Information warfare: Either force a specific response or gain information about opponent's hand
- Strategic context: Creates a powerful mind game where players can force opponents into specific plays or gain valuable information about their hand, often used as a counter-strategy tool or to set up favorable matchups