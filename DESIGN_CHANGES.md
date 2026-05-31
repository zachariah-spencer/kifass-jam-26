# Design Changes

## Opening Clarity

- After the "Our identities and our memories of them are what shape us, after all..." dialogue at the beginning, wait one second, then show this second message:

  "Your memory has failed you in a world where remembrance is everything.
  Explore to remember names. Remembered names make you stronger.
  But every door demands a name.
  What are you willing to leave behind?"

- This should make the altar/door economy clearer without overexplaining at the beginning of the game.

- Add one small in-game reinforcement after the first altar interaction:

  "The altar does not want blood. It wants a name."

## Sacrifice Rules

- Add camera shake anytime a sacrifice is made.

- Non-final altars should accept any currently learned name.

- The final altar should only accept the player's name.

- The final altar should become active after the required number of regular sanctum sacrifices, not after sacrificing specific words.

- The intended design is that every non-final sacrifice is valid but consequential. Avoid hidden required sacrifice orders that force a full reset.

- When a sacrifice changes a mechanic, immediately show a short consequence message:
  - BELL: "The silence is deafening. Nothing can stop what hunts you."
  - KEY: "The metal gates forgets what their locks were for, slamming shut."
  - MIRROR: "The reflected path fades from memory."
  - LAMP: "The dark leans closer."

## KEY, Gates, And Sanctum

- `knows_word?("KEY")` should open or keep open key-gated shortcuts.

- `word_sacrificed?("KEY")` should activate the sanctum Nameless Thing consequence.

- The hall alcove with the bell should no longer require KEY to get through.

- The sanctum key gate should be optional:
  - If the player knows KEY, they can open the shortcut through the sanctum key gate.
  - If the player does not know KEY, they can still progress through a longer zig-zag path around the gate.

- The archive maze should include a shortcut path requiring a gate opened by knowing KEY.

- Spawn the Nameless Thing in the sanctum only if KEY is sacrificed or otherwise missing as a remembered word.

- The sanctum monster is the consequence of losing KEY: without a key, the sanctum is no longer sealed from it.

- Sanctum text idea:

  "Gates forget what their locks were for... Something else remembers the openings..."

## BELL And Monster Pressure

- BELL should have a 3-second cooldown.

- Show a white/ash radial indicator above the player's head:
  - It starts full after the bell is used.
  - It clears over the cooldown duration.
  - When fully cleared, the bell can be used again.

- Pressing BELL during cooldown should produce a small failed-use feedback cue, such as a dull thud, a half-alpha pulse, or another subtle signal that the input was received but the bell is not ready.

- If the player sacrifices BELL:
  - Spawn a second monster on the other side of the archive.
  - Multiply all monster speeds by 1.25x.
  - The player can no longer use the bell stun.

- Keep archive monster escalation distinct from sanctum monster activation:
  - BELL sacrifice escalates archive monster pressure.
  - KEY sacrifice/missing KEY activates the sanctum Nameless Thing consequence.

- Playtest worst-case stacking carefully: sacrificed BELL plus sacrificed LAMP plus no MIRROR aid. That path should be tense and difficult, but still fair.

## Final Sequence

- The Nameless Thing should stop moving and fade to 0 opacity over 1.0 seconds when the player triggers the final sequence.

## Reset Hints

- Replace placeholder reset hints with hints that teach sacrifice consequences without implying one correct sacrifice order.

- Populate the world with more lamps and make the hall room smaller overall.



- Hint examples:
  - "A name left behind changes the shape of the maze..."
  - "Every offering opens something while closing one's mind off from something else..."
  - "Forgetting is not failure. It is information..."
  - "Something ancient and nameless hunts those trapped here..."
