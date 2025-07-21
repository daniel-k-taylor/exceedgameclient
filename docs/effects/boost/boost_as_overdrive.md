# boost_as_overdrive

**Category**: Boost
**Description**: Creates a choice at start of turn to boost a card as an overdrive effect or gain a bonus action.

## Parameters

- `limitation` (required): Restrictions on what can be boosted
  - **Type**: String
  - **Values**: "normal", "special", "continuous", etc.
- `valid_zones` (required): Source zones for boosting
  - **Type**: Array of strings
  - **Values**: ["hand"], ["gauge"], ["deck"], ["discard"], ["extra"]

## Supported Timings

- `now` - When effect is set up (triggers at start of next turn)

## Examples

**Boost continuous from hand as overdrive:**
```json
{
  "timing": "now",
  "effect_type": "boost_as_overdrive",
  "limitation": "continuous",
  "valid_zones": ["hand"]
}
```

**Boost any card from gauge as overdrive:**
```json
{
  "timing": "now",
  "effect_type": "boost_as_overdrive",
  "limitation": "",
  "valid_zones": ["gauge"]
}
```

## Implementation Notes

- Sets up [`effect_on_turn_start`](../../scenes/core/local_game.gd:2221) for automatic execution
- Creates a choice between boosting as overdrive or gaining bonus action
- Choice includes [`BoostAsOverdriveInternal`](../../scenes/core/local_game.gd:2225) option
- Alternative choice gives [`TakeBonusActions`](../../scenes/core/local_game.gd:2233) effect (1 bonus action)
- Executes after all start of turn effects are processed
- Provides strategic flexibility between resource investment and action economy
- Used for powerful delayed boost effects with overdrive timing

## Related Effects

- [boost_as_overdrive_internal](boost_as_overdrive_internal.md) - Internal implementation for actual boost
- [choice](../choice/choice.md) - Choice mechanics
- [take_bonus_actions](../actions/take_bonus_actions.md) - Bonus action effects
- [boost_discarded_overdrive](boost_discarded_overdrive.md) - Boost from discarded overdrive

## Real Usage Examples

From card definitions:
- Character abilities that set up powerful turn-start choices
- Strategic effects that provide overdrive-timing boost access
- Cards that offer flexibility between immediate actions and delayed power
- Setup effects that create meaningful turn-start decisions