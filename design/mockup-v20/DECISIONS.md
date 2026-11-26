# Horion v20: moving through the event panel by keyboard

The user said: "i cant well tab through these things".

What the app does now (`PanelFocus` in `Sources/Horion/Views/PanelControls.swift`): Tab stops only on the text fields (title, date,
start, end, participants, call link, location, notes). All day, repeat, calendar, busy, visibility and reminders can't be reached,
and Tab into a field selects all its text. Repeat is plain text with no menu.

## Round 1 (locked)
- Navigation model: Flat Tab. Every control is a Tab stop, top to bottom.
- Arriving in a text field by keyboard: selects all.
- Return in a one-line field: saves and moves on.
- Tab past the last control: wraps to the top.
- Flat Tab stops on Delete and Close: no.
- Jump letters (hold Option, Option + letter): on.
