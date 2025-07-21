# reveal_hand

**Category**: Card Management
**Description**: Reveal all cards in hand. Shows hand contents to both players.

## Parameters

None - this effect has no parameters.

## Supported Timings

- `now` - Immediately when played
- `immediate` - Immediately when triggered
- `after` - After strike resolution

## Examples

**Basic hand reveal:**
```json
{
  "timing": "now",
  "effect_type": "reveal_hand"
}
```

**Post-strike reveal:**
```json
{
  "timing": "after",
  "effect_type": "reveal_hand"
}
```

## Implementation Notes

- Shows all cards in hand to both players
- Used for information gathering and mind games
- May trigger effects that care about revealed cards
- Creates reveal log message
- Often used with choice effects or hand manipulation

## Related Effects

- [reveal_topdeck](reveal_topdeck.md) - Reveal top deck card
- [reveal_strike](reveal_strike.md) - Reveal current strike
- [opponent_discard_normals_or_reveal](../cards/opponent_discard_normals_or_reveal.md) - Force reveal or discard

## Real Usage Examples

From card definitions:
- Various information-gathering effects
- Setup for conditional abilities
- Mind game and bluffing mechanics