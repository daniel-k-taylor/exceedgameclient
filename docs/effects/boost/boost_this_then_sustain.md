# boost_this_then_sustain

**Category**: Boost
**Description**: Boost the current strike card and optionally sustain it.

## Parameters

- `dont_sustain` (optional): Prevents sustaining the boost
  - **Type**: Boolean
  - **Default**: false (boost will be sustained)
- `boost_effect` (optional): Additional effect to trigger when boosting
  - **Type**: Effect object
  - **Default**: No additional effect

## Supported Timings

- `during_strike` - During strike resolution (expected timing)

## Examples

**Basic boost this with sustain:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_this_then_sustain"
}
```

**Boost this without sustaining:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_this_then_sustain",
  "dont_sustain": true
}
```

**Boost this with additional effect:**
```json
{
  "timing": "during_strike",
  "effect_type": "boost_this_then_sustain",
  "boost_effect": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

## Implementation Notes

- Expected to be used mid-strike (asserts [`active_strike`](../../scenes/core/local_game.gd:2102) is true)
- Sets [`move_strike_to_boosts`](../../scenes/core/local_game.gd:2104) flag to true
- Controls sustain behavior with [`move_strike_to_boosts_sustain`](../../scenes/core/local_game.gd:2106) flag
- Calls [`handle_strike_attack_immediate_removal()`](../../scenes/core/local_game.gd:2112) to remove strike from play
- Can trigger additional [`boost_effect`](../../scenes/core/local_game.gd:2114) if specified
- Allows strike cards to become persistent boost effects
- Creates strategic value from temporary strikes

## Related Effects

- [boost_then_sustain](boost_then_sustain.md) - Boost other cards with sustain
- [sustain_all_boosts](sustain_all_boosts.md) - Keep all boosts active
- [sustain_this](sustain_this.md) - Sustain current card
- [boost_as_overdrive](boost_as_overdrive.md) - Turn boost into overdrive

## Real Usage Examples

From card definitions:
- Strike cards that convert themselves into ongoing boosts
- Self-boosting attacks that provide persistent value
- Strategic strikes that become continuous effects
- Cards that transition from temporary to sustained benefits