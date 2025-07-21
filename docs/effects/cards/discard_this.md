# discard_this

**Category**: Card Management
**Description**: Discard the current card. The card executing this effect is moved to discard pile.

## Parameters

- `ignore_active_boost` (optional): Don't discard if this is an active boost
  - **Type**: Boolean
  - **Default**: false

## Supported Timings

- `cleanup` - During cleanup phase

## Examples

**Basic self-discard:**
```json
{
  "timing": "cleanup",
  "effect_type": "discard_this"
}
```

**Ignore if active boost:**
```json
{
  "timing": "cleanup",
  "effect_type": "discard_this",
  "ignore_active_boost": true
}
```

## Implementation Notes

- Card executing this effect is moved to discard pile
- For active boost cards, sets `discard_on_cleanup = true`
- For other cards, immediately discards from continuous boosts
- If `ignore_active_boost` is true, effect does nothing for active boosts
- Used for one-time effects and self-destructing abilities
- Creates appropriate discard log message

## Related Effects

- [discard_hand](discard_hand.md) - Discard all cards from hand
- [discard_strike_after_cleanup](discard_strike_after_cleanup.md) - Discard current strike
- [seal_this](../seal/seal_this.md) - Seal the current card instead
- [return_this_to_hand_immediate_boost](../cards/return_this_to_hand_immediate_boost.md) - Return to hand instead

## Real Usage Examples

From card definitions:
- One-time boost effects: Self-destruct after use
- Temporary enhancement cards: Discard after providing benefit
- Sacrifice mechanics: Cards that consume themselves for effect
- Limited-use abilities across various characters