# pass

**Category**: Special
**Description**: Do nothing. This effect explicitly performs no action and is often used as a "do nothing" option in choices.

## Parameters

None - this effect has no parameters.

## Supported Timings

All timings are supported since this effect does nothing.

## Examples

**Basic pass:**
```json
{
  "timing": "now",
  "effect_type": "pass"
}
```

**As choice option:**
```json
{
  "timing": "immediate",
  "effect_type": "choice",
  "choice": [
    { "effect_type": "advance", "amount": 1 },
    { "effect_type": "retreat", "amount": 1 },
    { "effect_type": "pass" }
  ]
}
```

## Implementation Notes

- Explicitly does nothing when executed
- Commonly used in choice arrays to provide a "skip" option
- Logs a "passes" message for clarity
- Allows players to decline optional effects
- Different from `nothing` which is more for internal use

## Related Effects

- [nothing](nothing.md) - Similar but for internal use
- [choice](../choice/choice.md) - Often contains pass as an option

## Real Usage Examples

From card definitions:
- Choice effects across many characters include pass options
- Optional movement or action effects
- "May do X" effects where player can choose not to act
- Conditional effects that can be skipped