# boost_multiple

**Category**: Boost
**Description**: Allow player to boost multiple cards in a single action.

## Parameters

- `amount` (required): Number of cards to boost
  - **Type**: Integer
  - **Range**: Any positive integer
- `valid_zones` (optional): Source zones for boosting
  - **Type**: Array of strings
  - **Default**: ["hand"]
  - **Values**: ["hand"], ["gauge"], ["deck"], ["discard"], ["extra"]
- `limitation` (optional): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", "continuous", etc.
  - **Default**: No limitation
- `ignore_costs` (optional): Ignore boost costs
  - **Type**: Boolean
  - **Default**: false
- `shuffle_discard_after` (optional): Shuffle discard pile after boosting
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered

## Examples

**Boost 2 cards from hand:**
```json
{
  "timing": "now",
  "effect_type": "boost_multiple",
  "amount": 2
}
```

**Boost 3 normal cards from gauge:**
```json
{
  "timing": "immediate",
  "effect_type": "boost_multiple",
  "amount": 3,
  "valid_zones": ["gauge"],
  "limitation": "normal"
}
```

**Free boost multiple cards:**
```json
{
  "timing": "now",
  "effect_type": "boost_multiple",
  "amount": 2,
  "ignore_costs": true
}
```

**Boost from hand and gauge with shuffle:**
```json
{
  "timing": "immediate",
  "effect_type": "boost_multiple",
  "amount": 2,
  "valid_zones": ["hand", "gauge"],
  "shuffle_discard_after": true
}
```

## Implementation Notes

- Creates a decision state for player to select multiple cards
- Uses [`EventType_ForceStartBoost`](../../scenes/core/local_game.gd:2041) with specified amount
- Checks if player [`can_boost_something(valid_zones, limitation)`](../../scenes/core/local_game.gd:2040) before allowing boost
- Sets [`DecisionType_BoostNow`](../../scenes/core/local_game.gd:2044) with amount and zone restrictions
- Can optionally shuffle discard pile after boosting completes
- Allows free boosting if [`ignore_costs`](../../scenes/core/local_game.gd:2049) is true
- Enables explosive combo turns and multi-boost setups

## Related Effects

- [boost_additional](boost_additional.md) - Boost beyond normal limits
- [boost_from_gauge](boost_from_gauge.md) - Boost specifically from gauge
- [boost_then_sustain](boost_then_sustain.md) - Sustain boost effects
- [sustain_all_boosts](sustain_all_boosts.md) - Keep all boosts active

## Real Usage Examples

From card definitions:
- High-cost cards that enable multi-boost turns
- Combo enablers that set up multiple simultaneous effects
- Ultimate abilities that allow massive boost acceleration
- Strategic cards that create explosive momentum swings