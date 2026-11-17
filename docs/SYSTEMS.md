# How the game systems fit together

## Controls
WASD move, Shift sprint, Space jump, Ctrl/C crouch, mouse look, **Left click** interact (take the item you aim at, open things...). With an item selected in the hotbar,
**Left click** puts it into the box you aim at, or - if you aim at nothing usable - places it where you aim;
**Right click (hold)** throws it - the longer you hold, the harder (a bar fills under the crosshair and the item in your
hand shakes more), **E** eat the selected edible item (takes 3 s, you cannot move meanwhile, and a supervisor who sees it catches you), **B** stick a bill from the hotbar
on the box you aim at or carry (the selected bill, else the first one), **F** close/open the carried box, **R** take the last item out of the box you look at or carry (it must be open), **T** take the bill off
that box (it goes to your hotbar, so you can stick it on another box), **Q** put down (also gets off the bike), 1-5 / wheel select hotbar, **P** phone.
While you carry a box the hotbar is locked (greyed out; no selecting, eating or throwing - boxes are never thrown): **Left click** puts the
box down (unless you aim at something usable, e.g. the belt), **Q** does too.

## Autoloads (global singletons)
- `GameState` (scripts/core/game_state.gd): bank, health, energy, the clock, shift pay + multiplier,
  clock-in/out, pass-out, phone state. Emits signals; knows nothing about scenes.
- `Career` (scripts/core/career.gd): fixed warehouse rules + strikes, today's absurd event (at most one per day), being caught + ban, ranking,
  furniture perks, rent, the ending.

- `SaveGame` (scripts/core/save_game.gd): ONE save slot (user://savegame.json) + a backup of the last good save
  (savegame.bak; written via a temp file, loading falls back to the backup). Saves bank, health, energy, date, furniture,
  ban, stats, the player's position/look direction and hotbar. The warehouse is never saved: inside it you are saved as
  clocked out, in front of the door, hotbar empty; closing the window inside asks first ("Clock out and quit").
  Autosave: Saves a second after money changes, at shift end, at midnight, every
  30 s and on window close - only while `SaveGame.active` (set by the main menu). `GameSettings` (class, not an autoload)
  keeps volume / fullscreen / mouse sensitivity in user://settings.cfg.
- `Quests` (scripts/core/quests.gd): the quest log. `Quests.add(&"id", "Short title", "Description")`, `Quests.complete(&"id")`.
  Titles show at the top right of the HUD (flash + a message when one is added), titles with descriptions in the phone's
  **Quests** app. Saved with the game. The ban after being caught is a quest ("Banned until Tue 14:30") that completes by
  itself when the ban ends. Messages (`GameState.notice`, `hud.show_message`) appear above the hotbar.
- `Stats` (scripts/core/stats.gd): counters for the phone's Stats app (days passed, shifts, orders, gambling...).
  Call `Stats.add(&"key", amount)` from anywhere.

## The week
The game shows WEEKDAYS only (Monday to Sunday; the first day is a Monday). `GameState.weekday` (0 = Monday),
`get_weekday_name()`, `get_clock_text()` ("Mon 08:30"). The old integer `GameState.day` still exists internally
(seeds, bans) and is shown only as "Days passed" in the Stats app. Opening hours: `OpeningHours`
(scripts/core/opening_hours.gd), e.g. `OpeningHours.make([4, 5, 6], 20.0, 6.0)` = Fri-Sun nights.

## Core loop
Clock in (walk onto the warehouse floor) -> print a bill at the computer -> pick products from shelves
(hotbar or open box) -> attach the bill to a box -> close it -> put it on the CONVEYOR BELT (no taking it back!) -> at the end of the
belt the box is checked against its own bill, and a robot arm stacks it on a pallet; a full pallet is loaded into a truck. Only a box WITH a bill can be put on the belt.
Correct: $7 base pay + multiplier up by 0.05 (`GameState.BASE_ORDER_PAY`, `MULTIPLIER_STEP`). Wrong: multiplier
back to 1. The bill lists the products in walking order (region X, then Y, then Z; inside a region by corridor/column/level). Clock out (step into the lobby): pay = earnings x multiplier x compliance.

## On-screen hints
The prompt under the crosshair shows only the interaction you are AIMING at (`[Click] Take Water Bottle`). Every other
action that is possible right now (place/throw the held item, eat, drop, take items or the bill out of a box, close the box,
get off the bike...) is listed small and half transparent on the left side (`Player._update_use_prompt` ->
`PlayerHUD.set_hints`).

## The warehouse layout and the loading line
Numbers: `scripts/world/warehouse_layout.gd` (rooms, belt path, supervisor route, work loops, lights). The building
is roofed (ceiling 6.5 m; the second floor's top is 3.4 m, so you do not hit your head when you jump). From the main
door (x = 0, z = 10, south): the hall and the office (x -10..10), the warehouse door (x = 10) into the corridor (x 10..53.5,
z 2..10: reception, box dispensers, the order desk, the belt), then the Z room (west), a utility block, the X room
(east), the Y room (north, 5 columns so the staircase rows climb 5 layers to the second floor) and, through a short
passage from the Y room, the extra stock room (x 59.5..75.5, restocking crates and the blind spots).
- Persistent walls (outer shell, hall, office, roof) are in scenes/levels/world.tscn under `WarehouseShell`; the walls between
  the rooms are CSG boxes in scenes/levels/warehouse.tscn - move them in the editor. If you do, check `WarehouseLayout`:
  supervisors/workers walk fixed paths and some events use the work-floor rectangles.
- `CeilingLights`: lamps in every room (they go out in a power outage). `WarehouseOutside`: plaza, parking lot with cars,
  loading-yard pavement.
- `LoadingYard` (world scene): `ConveyorBelt` (scripts/props/conveyor_belt.gd) runs from the packing area along the
  corridor and through a small opening in the south wall; you put a CLOSED box on it where you aim; at the end the box is
  checked (pay / multiplier) and `RobotArm` stacks it on the pallet (8 boxes). A full pallet slides to the truck at the
  bay (rear door opens with the truck model's "Open" animation, "Close" after), the truck drives off and the next one
  backs in. The truck is assets/models/truck.glb (scaled 0.7 in loading_yard.gd); the belt, robot and pallet are placeholders.
- Thrown/dropped items use continuous collision detection (fast items no longer slip through walls) and a safety net
  puts back items that fall out of the world.

## Pushing items
The player is far heavier than any item: walking into a LOOSE item (dropped, knocked off a shelf) pushes it along
at your speed in the direction you walk, never up or down - so you can jump onto items and stand on them
(`Player._push_items`: a sphere query in front of your feet each physics frame). Items on shelves are fixed, so shelves
can be climbed without knocking the stock off.

## Dangers and mischief
- Energy drains on shift; at zero you pass out (half pay, wake outside, 2 h lost).
- Getting caught (`WarehouseSite._on_caught`): the camera turns to the supervisor who caught you
  (`Player.look_at_point`), he says why, the screen fades, you wake up in front of the warehouse and a quest-style
  entry (`Hud.show_quest`) tells you how long you are banned for (also the top line of the phone's Notices).
- Supervisors (scripts/npc): see you in a cone, blocked by shelves. Core violations (phone, smoking,
  gambling) in sight = caught (multiplier halved, thrown out, 3 h ban). Daily rule violations = strikes.
  High multiplier = more supervisors and lectures that freeze you.
- Blind spots: the dead-end pockets east/west of region Y (smoke break, poker, black market).

## Where things live
- Interior (created on entry, deleted on exit): scenes/levels/warehouse.tscn. It contains the
  VisitGenerator (random stock) and SupervisorManager.
- Sidewalks and vegetation: `TownScenery` (scripts/world/town_scenery.gd, created by TownBuilder after the buildings;
  sidewalks follow every `TownRoad` of the scene).
  Curb pieces (`sidewalk.glb`) along both sides of every street, left open at crossings. The corner model
  (`sidewalk_corner.glb`) is used ONLY at real corners: where a street bends and where a curb turns the corner into a crossing
  street; straight curb and curb that just stops (railway, lake, border) is the plain model; invisible 34-degree ramps over them so you can walk across. `tree2.glb`, `bush1.glb`,
  `grass.glb` are scattered over the free ground (woods thick, a tree belt along the world border, shores of the lakes);
  trees have trunk colliders, bushes and grass do not. The grass has a wind (visual only): `assets/shaders/grass_wind.gdshader`
  sends gust BANDS across the world (about 9 m/s, one every ~50 m): each tuft starts leaning a moment after the tuft upwind of
  it, because its delay depends only on where it stands, so a gust visibly travels while neighbours stay almost in step; the
  wind direction drifts slowly (uniforms: `wind_strength`, `wind_speed`, `gust_scale`, `gust_sharpness`, `turn_speed`). All MultiMesh, in 60 m chunks hidden when far. Density constants
  (square metres of free ground per thing) are at the top of the script; the hand-placed `tree1` trees stay as they are.
- Scenery beyond the border: `Landscape` (scripts/world/landscape.gd, created by TownBuilder): a few mountain ranges
  (about a third of the directions; open low land elsewhere), no back sides, about 2,000 triangles, no collision. Tune `reach`,
  `max_height`, `ramp_distance`, `cell`, or delete the node for a real model.
- Town: ONE scene with the rest of the world, `scenes/levels/world.tscn`, node `Town`: `Ground`, `IndustrialPaving`, `Fields`,
  `Roads` (`TownRoad` = a Path3D with a visible strip; kind ROAD or RAIL), `Lakes` (`TownLake`: scale = the two radii; `beach`
  flag), `Buildings` (Houses = 74 houses + 7 apartment blocks, one node each; Industrial, Shops, Farms, Station,
  GamblingApartment, ClubApartment), `Props`, `Trees`. All are plain nodes: select and move them in the editor. The node
  `TownBuilder` (scripts/world/town_builder.gd) only generates the high count things at game start: the lake beds, the
  sidewalks and vegetation, the shore fence, the world border, the landscape.
  Lakes (scripts/world/lake_basin.gd, assets/shaders/lake_water.gdshader): the lake disc in the scene is the handle; at game
  start the builder cuts a hole in the ground slab, builds a bowl-shaped bed with sloping banks (sand next to the beach
  lake, 3 m deep in the middle, collider included) and puts the water 0.7 m below the ground with a depth shader: colour and
  see-through-ness follow the depth (light shallows, dark middle), a foam line at the shore, ripples that fade with distance. It first reads the scene (`TownLayout.scan`, scripts/world/town_layout.gd), so nothing
  generated lands on a road, lake or building (every MeshInstance3D under `Buildings` and `Props` counts as standing).
  Nodes in the group `editor_only` are removed when the game starts (the orange boxes marking the two apartment blocks).
  Still numbers in TownLayout: the playable area, the neighbourhood zone, the woods, KEEP_OUT.
- Data you can edit in the Inspector without code: data/items, data/events, data/furniture.

## Tuning numbers (all constants at the top of the scripts)
Pay and multiplier, energy drain/regen, rent, ban length, rule count: GameState and Career.
Supervisor sight and lecture timing: Supervisor exports. Heat thresholds: SupervisorManager exports.

## Items, boxes, weight
- Every item on a shelf is a physical `WorldItem`. Aim at it (it glows), click: it goes into the open
  box you carry if there is room, otherwise into the hotbar. Q drops the selected hotbar item as a
  physics object. Shelves themselves cannot be clicked (you can stand and climb on them).
- `ItemData.size` = packing spaces (1 toothbrush, 2-3 medium, 4 toilet paper). Boxes: small 4,
  medium 8, big 16 spaces. `ItemData.weight` (kg) + box weight slow you down (Player.get_carry_speed_factor).
- Orders ask for a space budget (4-12), so they fit a box. Stock is finite per visit.

## Second floor
A mezzanine ring (open middle) over region Y with shelf regions U and V. No stairs: region Y's stacks
are 1-4 layers high, random every visit, and two rows next to the opening always form a randomized
staircase (1 -> 4 layers) leading to the edge, where a jump lands on the slab. Fans, trampolines and low
gravity are other ways up.

## Daily events (scripts/events, data/events)
One at most per day (about 50% of days have none). `EventRunner` (in the interior) creates the effect
node from `EventData.effect_script`; each effect extends `WarehouseEvent` and implements `_start/_stop`.
New event = a script + a .tres, no other changes.

## Loading the warehouse
- `LoadQueue` (scripts/world/load_queue.gd) is a node in warehouse.tscn. Shelf creation, stocking and heavy events add small tasks with `enqueue()`; it runs ~4 ms of them per frame, so entering never freezes. Shelves fill in about a second while the player walks in. The order desk and the daily event wait for `finished`.
- Without a LoadQueue (a lone region in a test scene) everything is built at once.

## Bike
- No jumping or crouching while riding. A collision barrier on layer 4 (`no_bikes`) blocks the warehouse door; `Player.mount_bike` adds layer 4 to the player's mask, `dismount_bike` removes it.

## Apartments and night spots
- The neighbourhood replaces about 1 in 6 houses with an apartment block (shop on the ground floor, flats above;
  decoration only). Two are hand-made (scripts/world/apartment_kit.gd builds them from boxes):
  - `GamblingApartment` at TownLayout.GAMBLING_SPOT: corner shop (PurchaseCounter) on the ground floor, stairs past
    two floors of locked flats, and on the top floor "The Back Room" (slots, poker, roulette = `GamblingMachine`).
    Its door is a `TimedDoor`, unlocked **Monday-Friday**.
  - `ClubApartment` at TownLayout.CLUB_SPOT (its lights, the door lamp and the dance floor tiles are on ONLY while it is open): record shop in front; a plain back door (in a yard where no house stands)
    leads down stairs into the **Underground Club** (bar, dance floor with `DanceFloor`, disco lights). The back door
    is unlocked **Friday-Sunday, 20:00-06:00**. The stair shaft is a hole in the town's ground
    (TownLayout.ground_holes(); TownBuilder cuts the ground slab around it); the club has its own ceiling.
- `TimedDoor` (scripts/props/timed_door.gd): exports `venue_name`, `open_days`, `open_from`, `open_to`. Locked doors
  always open from the inside. Every TimedDoor is listed (with open/closed) in the phone's **Places** app. To add a
  venue: build a room, put a TimedDoor in its doorway.
- Phone apps: Bank, Map, Notices, Ranking, **Stats**, **Places**, **Quests**.

## Loading the warehouse in slices
- Entering: WarehouseSite instantiates warehouse.tscn, takes the children out of it (clearing their `owner`, which
  makes re-adding ~15 ms faster each) and adds them through the LoadQueue in view order: walls and signs, furniture,
  second-floor slabs, storage regions (shelves, then stock), and last stocking + events. The door opens once walls and
  furniture are in. Stocking is cut into the smallest pieces: one task per shelf-grid, one per item, one per co-worker.
  `ItemCatalog` keeps every item and its model in memory for the whole game (they used to be re-read from disk on every
  entry: a 30 ms hitch). At the start of every game the warehouse is built once behind a black screen and looked at
  from a few angles (`WarehouseSite._warm_up`), so the first real entry does not pay the one-time costs of drawing it
  (set the environment variable NO_WARMUP to skip this, e.g. in tests). Debugging: start the game with the environment
  variable LOADQUEUE_LOG set and the LoadQueue prints its slow tasks and long frames when it is done.
  Leaving: the room is freed a few ms per frame (`_destroy_sliced`), and a new one waits for that.

## Sleeping, notifications, box details
- **Sleeping** (`HomeBed`): interact with the bed -> the camera lies on the mattress (Player.sleep_blend / sleep_eye), the screen dims and the
  clock runs at 30 in-game minutes per second. Energy (the bed's `sleep_restore` per 8 h night) and health come back as the hours pass.
  Left click gets you up at any time. Midnight still charges rent.
- **Order results** (belt check) appear as a small "achievement" box that slides down from the top centre (`PlayerHUD.show_achievement`);
  other notices stay above the hotbar (`show_message`).
- **Carried box**: its details (size, space, weight, contents, bill) are listed on the right side, half transparent
  (`Box.get_detail_lines` -> `PlayerHUD.set_carry_lines`).
- Bike speed is `Player.bike_speed_factor` (3 x walking). Food energy is `energy_restore` in data/items/*.tres (2.5 x the old values).
- Letters: X and Y are lettered from where you enter (`StorageRegion.reverse_letters`): XA is the corridor next to the entrance. Bills go X, Y, Z, each A upwards.

## Text is paper
There is no floating text that turns to face you. Every sign, name tag and shelf label is a `PaperLabel` (scripts/world/paper_label.gd):
a Label3D that grows a real sheet of paper behind its text. Wall signs are stuck on the wall, shelf labels are tags on the shelf edge,
NPC names are badges on their chests, signs in the middle of a room hang from the ceiling on two strings (the corridor letters of the
shelf regions) or stand on a post (props, town signs). After changing `text` at run time call `set_paper_text()` so the sheet is refitted.
