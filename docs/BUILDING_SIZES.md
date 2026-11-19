# Building sizes (a reference to design the town with)

The idea: build a place from the INSIDE out (door, seats, space to move, counter, kitchen, toilet), then close it with
walls, and read the real size off the result. First one: a small diner (placeholder name "Waffle Diner", the sign is
a paper label you can rename). Scene: `scenes/buildings/waffle_diner.tscn`, placed in the town at (178, 62) under
`Town/Buildings/WaffleDiner`. Floor plan with the main dimensions: [diner_plan.png](diner_plan.png).

## The diner (what is built)
| Part | Size |
|---|---|
| Outside | 14.4 m x 10.4 m (150 m2), 3.2 m high, walls 0.25 m, flat roof |
| Inside | 13.9 m x 9.9 m (138 m2) |
| Front door | 1.2 m wide opening, 2.1 m high, in the MIDDLE of the long front wall |
| Front windows | 1.5 m tall glass from 0.9 m to 2.4 m, over the whole front and the front 7.6 m of both side walls |
| Booth (4 seats) | table 0.75 x 1.7 m between two benches, each bench = two of your `bar_couch` models side by side (1.8 m); footprint 1.83 m across x 1.8 m. Every table is a booth: 3 along the front window (right of the door), 3 in a row in the middle, 4 along the east wall, 4 along the back wall |
| Counter | a quarter ring round the front-LEFT corner (left as you come in): radius 3.95-4.65 m (0.7 m deep body), top 0.9 m deep (0.2 m over the customer side), 1.12 m high because your `bar_stool` is 0.9 m high; a 1.1 m gap for the staff at the west wall; 11 stools at 0.6 m spacing on a circle of radius 5.3 m |
| Kitchen | in the corner inside the ring: a run along the front wall (fryers, grill) and one along the west wall (fridge, prep), 0.8 m deep, about 1.1 m of staff lane in front, hood at 2.4 m; a small staff pocket (dish sink, shelving) between the counter's end and the restroom |
| Restroom | 2.45 m x 2.4 m in the far (back-left) corner next to the counter side, door 0.8 m wide, toilet and sink |
| Seats | 56 (14 booths) + 11 (stools) = 67 |
| Parking | 26 m x 17 m lot, 9 yellow bays per row (2.6 m each, 5 m deep), two rows, 1.6 m walkway at the front |
| Total plot | about 26 m x 36 m (lot, building and dumpster yard) |

Walkways: about 2 m between the rows of booths, 1.1 m between the kitchen equipment and the counter, 1.0 m between the stools and the door. (0.9-1.0 m is the tightest walkable aisle, 1.2-1.5 m is comfortable.)

## Rules of thumb that came out of it
- A small restaurant like this is about 140-150 m2 (about 1,500 sq ft), roughly 14 x 10 m. These numbers are from memory and approximate, not measured
  from a specific restaurant; adjust the diner if you know better.
- Human-scale details: door 1.0-1.2 m wide and 2.1 m high; ceiling 3.0-3.2 m; counter 1.05 m; stool seat 0.65 m; table 0.75 m; booth bench 0.45 m high
  with a 0.95 m back; aisles 1.2-1.5 m; one parking bay 2.6 x 5 m, an aisle between two rows 7 m.
- The player is 1.8 m tall: a 2.1 m door is tight but right; tell me if it feels low and I will raise it.
- Buildings in the town now (measured from the scene): the shops are 8 x 7 m (4.6 m high), the houses about 6 x 5.5 m (they differ), the apartment
  blocks about 9 x 8 m. For comparison the diner is 14.4 x 10.4 m: the shops are about a third of its floor area, so a shop this size could not hold a counter, a
  kitchen and 67 seats. A real restaurant wants about 10 x 14 m and up; a small shop 6 x 10 m.

## How it is made
No script is needed: the diner is plain nodes (boxes) in one scene, so it can be moved piece by piece in the editor. The seats are two small prop scenes in
`scenes/props/diner/`: `booth.tscn` (your `bar_couch.glb` x4 and a table) and `stool.tscn` (your `bar_stool.glb` and a collision cylinder). The counter is 16 straight pieces on a circle, so it looks round. Collision is on the walls, the counter, the kitchen equipment, the booths and the stools. Inside there are 8 omni lights (always on). Nothing in it is interactive yet.
