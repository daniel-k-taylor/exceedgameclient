# boost_then_strike

**Category**: Boost
**Description**: Allow player to boost a card, then force a strike after boost cleanup.

## Parameters

- `valid_zones` (optional): Source zones for boosting
  - **Type**: Array of strings
  - **Default**: ["hand"]
  - **Values**: ["hand"], ["gauge"], ["deck"], ["discard"], ["extra"]
- `limitation` (optional): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", "continuous", etc.
  - **Default**: No limitation
- `wild_strike` (optional): Enable wild strike after boost
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `now` - Immediately when played (expected as character action)

## Examples

**Basic boost then strike:**
```json
{
  "timing": "now",
  "effect_type": "boost_then_strike"
}
```

**Boost from gauge then strike:**
```json
{
  "timing": "now",
  "effect_type": "boost_then_strike",
  "valid_zones": ["gauge"]
}
```

**Boost normal cards then wild strike:**
```json
{
  "timing": "now",
  "effect_type": "boost_then_strike",
  "limitation": "normal",
  "wild_strike": true
}
```

## Implementation Notes

- Expected to be used as a character action
- Checks if player [`can_boost_something(valid_zones, limitation)`](../../scenes/core/local_game.gd:2198) before allowing boost
- If boost is possible, creates normal boost decision state
- Sets [`strike_on_boost_cleanup`](../../scenes/core/local_game.gd:2206) flag to force strike after boost
- If [`wild_strike`](../../scenes/core/local_game.gd:2207) is true, sets [`wild_strike_on_boost_cleanup`](../../scenes/core/local_game.gd:2208) flag
- If no boost available, immediately forces strike instead
- Creates [`EventType_ForceStartStrike`](../../scenes/core/local_game.gd:2212) if no boost possible
- Ensures player gets value even when boost isn't available
- Enables aggressive boost-into-strike combos

## Related Effects

- [boost_or_reveal_hand](boost_or_reveal_hand.md) - Boost or reveal with strike option
- [boost_then_sustain](boost_then_sustain.md) - Boost with sustain instead of strike
- [wild_strike](../attack/wild_strike.md) - Wild strike mechanics
- [force_strike](../attack/force_strike.md) - Force strike effects

## Real Usage Examples

From card definitions:
- Aggressive character actions that combine boosting with immediate pressure
- Cards that ensure strike value even with poor boost options
- Combo enablers that set up enhanced strikes
- Rush-down effects that maintain offensive momentum