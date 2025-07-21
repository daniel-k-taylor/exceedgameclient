# SealAttackOnCleanup

**Category**: Seal and Transform
**Description**: Seals the attack card to the sealed area during cleanup instead of discarding it.

## Parameters

This effect has no parameters.

## Supported Timings

- `immediate` - Applied immediately when the effect triggers
- `cleanup` - Can be applied during cleanup phase

## Examples

**Basic usage:**
```json
{
  "timing": "immediate",
  "effect_type": "seal_attack_on_cleanup"
}
```

**Character effect (Nine):**
```json
{
  "character_effect": true,
  "effect_type": "seal_attack_on_cleanup",
  "and": {
    "effect_type": "advance",
    "amount": 1
  }
}
```

**Combined with other effects:**
```json
{
  "effect_type": "seal_attack_on_cleanup",
  "and": {
    "effect_type": "powerup",
    "amount": 2
  }
}
```

## Implementation Notes

- Sets the `seal_attack_on_cleanup` flag on the performing player's strike stat boosts
- During strike cleanup, if this flag is set, the attack card is moved to the sealed area instead of being discarded
- The sealed area may be secret (face-down) depending on character settings
- Creates appropriate log messages describing the sealing action
- Only affects the current attack card being cleaned up
- Cannot be prevented once the flag is set

## Related Effects

- [`seal_this`](seal_this.md) - Seals the current card immediately
- [`discard_strike_after_cleanup`](../cards/discard_strike_after_cleanup.md) - Alternative cleanup behavior
- [`seal_hand`](seal_hand.md) - Seals entire hand instead of single card
- [`seal_continuous_boosts`](seal_continuous_boosts.md) - Seals continuous boost cards

## Real Usage Examples

From card definitions:
- Nine's "Azuredge Cannon": Character effect that seals attack after cleanup and advances
- Nine's character ability: Passive effect that seals attacks on cleanup
- Various special attacks: Used to preserve powerful attacks for later use
- Strategic context: Allows players to build up sealed cards for effects that use sealed card count or to reuse powerful attacks later