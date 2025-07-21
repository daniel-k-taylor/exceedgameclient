# nothing

**Category**: Special
**Description**: Explicitly do nothing. Used internally for placeholder effects and conditional branches that should have no effect.

## Parameters

None - this effect has no parameters.

## Supported Timings

All timings are supported since this effect does nothing.

## Examples

**Basic nothing effect:**
```json
{
  "timing": "now",
  "effect_type": "nothing"
}
```

**Conditional placeholder:**
```json
{
  "timing": "immediate",
  "condition": "some_condition",
  "effect_type": "nothing"
}
```

## Implementation Notes

- Explicitly does nothing when executed
- Used internally for conditional effects that may not trigger
- Different from `pass` which is more user-facing
- Often used as placeholder in complex conditional logic
- Does not generate log messages
- Useful for maintaining effect structure without actual effects

## Related Effects

- [pass](pass.md) - User-facing "do nothing" option
- [choice](../choice/choice.md) - May contain nothing as internal option

## Real Usage Examples

From card definitions:
- Internal conditional effects that may not execute
- Placeholder effects in complex branching logic
- Default cases in conditional effect chains
- System-level effect handling