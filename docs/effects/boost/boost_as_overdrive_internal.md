# boost_as_overdrive_internal

**Category**: Boost
**Description**: Internal effect that executes the boost portion of boost_as_overdrive choice.

## Parameters

- `limitation` (required): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", "continuous", etc.
- `valid_zones` (required): Source zones for boosting
  - **Type**: Array of strings
  - **Values**: ["hand"], ["gauge"], ["deck"], ["discard"], ["extra"]

## Supported Timings

- `now` - When executed as part of choice resolution

## Examples

**Internal boost continuous from hand:**
```json
{
  "timing": "now",
  "effect_type": "boost_as_overdrive_internal",
  "limitation": "continuous",
  "valid_zones": ["hand"]
}
```

**Internal boost from gauge:**
```json
{
  "timing": "now",
  "effect_type": "boost_as_overdrive_internal",
  "limitation": "",
  "valid_zones": ["gauge"]
}
```

## Implementation Notes

- This is an internal effect typically not used directly in card definitions
- Automatically grants [`bonus_actions = 1`](../../scenes/core/local_game.gd:2245) to compensate for forced action timing
- Checks if player [`can_boost_something(valid_zones, limitation)`](../../scenes/core/local_game.gd:2246) before allowing boost
- Creates [`EventType_ForceStartBoost`](../../scenes/core/local_game.gd:2247) if boost is possible
- Logs message if no cards available for overdrive boost effect
- Used internally by [`boost_as_overdrive`](boost_as_overdrive.md) choice mechanism
- Handles the actual boost execution after player chooses boost option

## Related Effects

- [boost_as_overdrive](boost_as_overdrive.md) - The main effect that creates the choice
- [take_bonus_actions](../actions/take_bonus_actions.md) - Bonus action mechanics
- [choice](../choice/choice.md) - Choice resolution system
- [boost_additional](boost_additional.md) - Additional boost effects

## Real Usage Examples

From card definitions:
- Not typically used directly in card definitions
- Generated automatically by boost_as_overdrive choice system
- Internal implementation detail for overdrive boost mechanics
- Part of the choice resolution framework for start-of-turn effects