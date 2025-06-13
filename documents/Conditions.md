# Conditions
The goal of this document is to contain list of conditions that can be used in the `conditions` field for a JSON object, so that they may be referenced when creating custom characters.
If the condition returns false, the sibling `effect` of the same JSON object will not be performed.
Some of these conditions may require additional sibling fields in the same JSON object.  Those will be stated per condition.
The conditions listed in this document will contain conditions that are used by base game characters, as well as ones that are only used by custom characters.
This list is currently incomplete and will be gradually updated.

`was_pushed_or_pulled_this_strike`
Returns true if your character had been pushed or pulled during this strike.
(Does not count if the you did not move from being pushed/pulled)

`opponent_was_pushed_or_pulled_this_strike`
Returns true if the opponent had been pushed or pulled during this strike.
(Does not count if the opponent did not move from being pushed/pulled)

`was_moved_during_strike`
Required fields: `condition_amount`
Returns true if your character had been pushed or pulled at least `condition_amount` spaces during this strike.
(Spaces where you were unable to be pushed/pulled do not count.)

`opponent_was_moved_during_strike`
Required fields: `condition_amount`
Returns true if your opponent had been pushed or pulled at least `condition_amount` spaces during this strike.
(Spaces where they were unable to be pushed/pulled do not count.)
