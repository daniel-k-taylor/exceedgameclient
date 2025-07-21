# discard_hand

**Category**: Card Management
**Description**: Discard all cards from hand. All cards in hand are moved to the discard pile.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `cleanup` - During cleanup phase

## Examples

**Basic discard hand:**
```json
{
  "timing": "now",
  "effect_type": "discard_hand"
}
```

**Discard hand immediately:**
```json
{
  "timing": "immediate",
  "effect_type": "discard_hand"
}
```

**Cleanup discard:**
```json
{
  "timing": "cleanup",
  "effect_type": "discard_hand"
}
```

## Implementation Notes

- All cards in hand are moved to discard pile
- Hand size becomes 0 after this effect
- Does not trigger individual card discard effects
- Often used for reset mechanics or as cost for powerful effects
- Cannot be prevented by hand size restrictions
- May trigger "hand discarded" or "cards discarded" conditions

## Related Effects

- [discard_random](discard_random.md) - Discard random cards from hand
- [discard_to](discard_to.md) - Discard down to target hand size
- [self_discard_choose](../choice/self_discard_choose.md) - Choose cards to discard
- [draw](draw.md) - Draw cards to hand

## Real Usage Examples

From card definitions:
- Happy Chaos's "Curse": `{ "timing": "cleanup", "effect_type": "discard_hand" }`
- Various "reset" effects that clear hand for fresh start
- Powerful ultimates that require discarding hand as cost
- Character exceed effects that clear resources