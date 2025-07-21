# boost_additional

**Category**: Boost
**Description**: Allow boosting an additional card. Player can boost another card beyond normal limits.

## Parameters

- `limitation` (optional): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", etc.
- `valid_zones` (optional): Source zones for boosting
  - **Type**: Array of strings
  - **Default**: ["hand"]
  - **Values**: ["hand"], ["gauge"], ["deck"], etc.
- `ignore_costs` (optional): Ignore boost costs
  - **Type**: Boolean
  - **Default**: false
- `discard_this_first` (optional): Discard current boost before new one
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered

## Examples

**Basic additional boost:**
```json
{
  "timing": "now",
  "effect_type": "boost_additional"
}
```

**Boost normal from hand:**
```json
{
  "timing": "immediate",
  "effect_type": "boost_additional",
  "limitation": "normal"
}
```

**Boost from gauge:**
```json
{
  "timing": "now",
  "effect_type": "boost_additional",
  "valid_zones": ["gauge"]
}
```

**Free boost:**
```json
{
  "timing": "immediate",
  "effect_type": "boost_additional",
  "ignore_costs": true
}
```

## Implementation Notes

- Creates decision state for player to select card to boost
- Respects limitation restrictions if specified
- Can boost from different zones beyond just hand
- May ignore force costs if specified
- Allows combo building and chain boosting
- Used for explosive turn setups

## Related Effects

- [boost_from_gauge](boost_from_gauge.md) - Specifically boost from gauge
- [boost_multiple](boost_multiple.md) - Boost multiple cards
- [boost_then_strike](boost_then_strike.md) - Boost then force strike
- [sustain_all_boosts](sustain_all_boosts.md) - Keep all boosts active

## Real Usage Examples

From card definitions:
- Ramlethal's "Exceed": Additional boost opportunities
- Various combo-enabling effects across characters
- Setup cards that enable multi-boost turns
- Resource acceleration mechanics