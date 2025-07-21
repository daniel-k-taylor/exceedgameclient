# advance_INTERNAL

**Category**: Movement
**Description**: Internal implementation of advance effect. Handles the actual movement logic after advance effect is processed.

## Parameters

- `amount` (required): Number of spaces to advance
- `stop_on_buddy_space`: Buddy index to stop on if reached
- Various internal parameters for movement calculation

## Supported Timings

- Internal timing (called by advance effect)

## Examples

**Internal usage only - not for direct use in card definitions**

## Implementation Notes

- This is an internal effect used by the game engine
- Do not use directly in card definitions
- Use `advance` instead for normal advancement
- Handles actual character movement and state updates
- Calculates final position and triggers related effects

## Related Effects

- [advance](advance.md) - User-facing advance effect
- [close_INTERNAL](close_internal.md) - Internal close implementation
- [retreat_INTERNAL](retreat_internal.md) - Internal retreat implementation

## Real Usage Examples

Not used directly in card definitions - internal implementation only.