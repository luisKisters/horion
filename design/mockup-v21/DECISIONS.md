# Horion v21: background shades, the text on them, and buttons

Builds on mockup-v16 round 3 (states fitted to contrast on every background), which stays locked.

## Round 1 (open)
The user said: "in the general design system there are just certain background shades and … these different background shades have certain font colours and things associated with them … There are button colours that are consistent throughout the app and different kinds of buttons … we need to check that colors are visible well and in a way that makes sense."

Found:
- 14 button views in the code (`TextButton`, `PrimaryButton`, `SecondaryButton`, `PlainButton`, `GhostButton`, `TodayButton`, `JoinCallButton`, `JoinBigButton`, `SplitButton`, `PanelFillButton`, `IconButton`, `ChromeIconButton`, `PanelIconButton`, `CopyLinkButton`), with 6 fills (act, bg2, bg3, raisedHover, hoverRail, danger) and 4 heights (26, 28, 30, 32).
- Hover inside a selected band (`selectedHover`) misses the text floors in both appearances (Dark fg1 10.5:1).
- Primary hover in Dark misses fg1's Lc 85 by a hair (85.3 with the +.6 margin).
- A Danger fill in Dark (#FF7B72 with dark text) gives the label Lc 55, below 4.5:1 / Lc 60. The mockup darkens it in 1 % steps until a white label passes.
- The Paper selected band (1.115:1) is limited first by fg3's 5:1, then fg2's 7:1, then fg1's Lc 88.

Open decisions: how many background shades; the text colours on each shade; the kinds of buttons; what a Secondary button looks like; button heights; the Paper selected band; hover inside a selected band.

Scenes: "Backgrounds and text" (each shade × text roles × states × buttons, with every contrast and a pass count), "Buttons on every background" (kind × shade, rest / hover / disabled), "Week, Dark", "Week, Paper".

With the recommended picks, every pair passes in Dark and Paper (96 pairs each).

## Round 1 (locked)
The user said: "all ur recommended things look good implement them".
- Background shades: four, Sidebar, Window, Inset, Raised. Menus and dialogs are Window.
- Text colours: the same three greys on every shade, checked on each.
- Kinds of buttons: Primary, Secondary, Ghost, Danger. Icon buttons are Ghost.
- Secondary: soft fill plus a faint edge, fitted per shade.
- Button heights: one, 26.
- Paper selected band: Paper floors relaxed to WCAG AA plus a margin (fg1 10 / Lc 80, fg2 6 / 68, fg3 4.5 / 60). Selected 1.24:1.
- Hover inside a selected band: one step back toward the shade.

Built: `Shade`, `ShadeInk`, `ShadeColors` and `.shade(_:)` in Theme.swift; `InkRGB.fitted` derives from `shadeInk`; `actHover`, `dangerFill`, `dangerHover` fitted; `Contrast.textFloors` (Paper AA), `labelFloor`, `softEdge`, `strongest(on:)`. `HButton`, `ButtonKind`, `ButtonFace` in Components.swift; the older button views wrap them. Every text button is `Dim.button` (26). The sidebar, right column, editor foot and settings sidebar set `.shade(.sidebar)`; floating surfaces `.shade(.window)`.
Tests: `ContrastSystemTests` checks every shade × text × state, the Secondary edge, hover in selected, the Primary and Danger labels. `PaletteV5Tests` expects the new Paper hover (#EEEEEE), hoverRail (#E8E8E8) and selected (#DDDDDD) and the AA soft floors.
Shots of the app after: `shots/after-dark.png`, `shots/after-paper.png` (`--snapshot v11-week`, `v11-week-paper`), `shots/after-delete.png` (`v4-delete`).
