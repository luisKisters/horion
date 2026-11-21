# Horion v17: event corners

Shot of the app before this round: `../mockup-v16/shots/after-dark.png` (events and chips at `Radius.small`, 5).
Shots of this round: `shots/week.png`, `shots/paper.png`, `shots/scale.png` (recommended picks), `shots/option-*.png`.

The corner scale in `Theme.swift` (`enum Radius`): 13 surfaces, 9 controls, 7 inner (control − 2, a segment in its 2 pt track, a row in a 6 pt padded menu), 5 small, 4 marks. Events and all-day chips use 5, the bottom of the scale, while every row and control around them is 7 or 9. 

## Round 1 (open)
The user said: "make an mockup of how the events could have more radius and radious that is consient with the rest ofh te app".

Open decisions, all on the existing scale:
- Event block corners: 7 inner (recommended), 9 control, grows with height (5 to 9), 5 as now.
- Calendar colour bar on rounder corners: inset 3 pt rounded bar like the "Later today" rows (recommended), flush and cut by the corner (as now), no bar with a stronger fill.
- All-day chips: same corner as blocks (recommended), 5 as now, round ends.

The selected ring keeps its rule (radius + 3), so it follows any pick. Month view chips use `Radius.event` and follow the pick.

## Round 1 (locked)
- Event block corners: 7, the inner step, like rows and segments.
- Calendar colour bar: flush, cut by the corner (as now). Not the recommendation.
- All-day chips: the same corner as event blocks.

Built: `Radius.event = Radius.inner` (7) in Theme.swift. Timed blocks, all-day chips (week and month), month view blocks and the selected ring (radius + 3) all read `Radius.event`. The bar is unchanged. `foundations.md` and `components.md` now list the code's scale (4 / 5 / 7 / 9 / 13).
Shots of the app after: `shots/after-dark.png`, `shots/after-paper.png` (`--snapshot v11-week`, `v11-week-paper`).
