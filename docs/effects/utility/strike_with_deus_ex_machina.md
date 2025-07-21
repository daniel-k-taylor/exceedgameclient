# StrikeWithDeusExMachina

**Category**: Utility (also classified under Special Mechanics)
**Description**: Performs a strike with Deus Ex Machina enhancement, providing special properties during exceed state.

## Parameters

This effect takes no parameters.

## Supported Timings

- Exceed activation - Triggered when exceeding

## Examples

**Basic Deus Ex Machina strike:**
```json
{
  "effect_type": "strike_with_deus_ex_machina"
}
```

**In exceed context:**
```json
{
  "on_exceed": {
    "effect_type": "strike_with_deus_ex_machina"
  }
}
```

## Implementation Notes

- Only functions during active strike phases, not during boost phases
- Used specifically for exceed-related strike mechanics
- Part of character-specific exceed abilities (particularly Happy Chaos)
- Provides enhanced strike capabilities when in exceed state
- Creates special strike interactions unique to Deus Ex Machina mechanics
- Tied to advanced character mechanics and exceed state benefits

## Related Effects

- [`strike_from_gauge`](strike_from_gauge.md) - Alternative special strike source
- [`strike_faceup`](strike_faceup.md) - Strike revelation mechanics
- [`exceed`](../exceed/exceed.md) - Exceed state mechanics that enable this effect

## Real Usage Examples

From card definitions:
- Happy Chaos exceed: `"on_exceed": { "effect_type": "strike_with_deus_ex_machina" }`
- Character-specific mechanics: Used for unique exceed-state strike abilities
- Advanced gameplay: Part of high-level character mastery and exceed strategies
- Special interactions: Provides unique properties during exceed-enhanced strikes