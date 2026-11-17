# Roadmap

Each phase is a playable vertical slice. Don't start the next phase until the
current one is fun/stable. Design decisions live in the project notes; this file
is the build order.

## Phase 0 - Foundations (DONE)
- [x] First-person player (WASD, sprint, mouse look, smooth camera on any refresh rate)
- [x] Generic Interactable / Interactor system
- [x] Box: pick up, carry, drop, open/close flap animations (Blender `open`/`close`)

## Phase 1 - Core order loop
Goal: complete one full order by hand, grey-boxed.
- [x] 1.1 `ItemData` resource + shelf with fixed item and stock; take an item
- [x] 1.2 Items go into the carried open box (snap slots, no physics); box contents tracked
- [x] 1.3 Close the box for real (F while carrying); pallet accepts closed boxes (2 on the floor + 2 stacked)
- [x] 1.4 Order desk: `OrderGenerator` makes an order; HUD lists item, quantity, shelf location (ticks off as the carried box fills)
- [x] 1.5 Pallet ships on a timer (10 s for development); each box is checked against the open orders. Orders are paper bills you hold to read.
- [x] 1.6 Hotbar inventory (small items + bills); bills attach to boxes and the pallet checks each box against its own bill; left click = interact, right click = use item
- [x] 1.7 Three box sizes (small 4 slots, medium 8, big 16) from three piles; pallet stacks boxes of any height

## Phase 2 - Session loop (the fun test)
Goal: the push-your-luck loop works with packing alone. Decide here whether the game is fun.
- [x] 2.1 Global state autoload (GameState): bank, energy, in-game clock (1 real s = 1 game min) + day/night sun/moon/sky; basic status readout top-left
- [x] 2.2 Warehouse entrance as the boundary: walking in clocks in and creates a fresh interior; walking out clocks out and deletes it (carried things stay behind)
- [x] 2.3 Multiplier: +0.25 per correct order while on shift, wrong box resets it to 1.0, shift pay (base x multiplier) paid into the bank on clock-out
- [x] 2.4 Energy drains on shift (x0.05 standing, x1 walking, x2.6 sprinting, +0.3 carrying; 12/h at x1), slowly regenerates off shift. At zero: fade out, wake up outside the door with 30 energy, 2 hours lost and half pay.
- [~] 2.5 HUD: health + energy bars and the shift/multiplier line are in; money and clock live on the phone (P): bank app, map app. Main menu added.

## Phase 3 - Warehouse structure
- [~] Zones: reception desk (done), back storage = decorative restock pallets (the crew "refills" the shelves between shifts). SKIPPED: cargo + truck + loading dock (needs a model).
- [x] Stockroom regions X/Y/Z: corridors of boltless shelves, IDs like XC 04 03, random stack heights (1-4) every visit
- [x] Second floor (mezzanine ring with an open middle, no stairs) with shelf regions U and V; Y always has a randomized staircase of stacks leading up to it (parkour)
- [x] Visit generator: random products and stock, finite stock (clear it out and you must clock out/in), co-workers - new every visit
- [x] Individual items: every item on a shelf is its own object; aim to highlight it, click to take THAT item; drop (Q) makes it a physics object
- [x] Items have `size` (packing spaces: toothbrush 1, toilet paper 4) and `weight` (kg); boxes have spaces (small 4 / medium 8 / big 16) and the carried weight slows you down

## Phase 4 - Supervisors, heat, mischief
- [x] Supervisor patrol (placeholder capsule) + line of sight (view cone, shelves and floors block it)
- [x] "You need to rest" lectures that freeze you for 3 s, heat tiers from the multiplier (1/2/3 supervisors)
- [x] Fixed rules: phone, smoking, gambling, snacking in a supervisor's sight = caught (multiplier halved, thrown out, 3 h ban)
- [x] Mischief in blind spots: smoke break and poker in the pockets beside Y (they lie under the 2nd floor)

## Phase 5 - Crazy-boss events (replaces the old "daily rules")
- [x] `EventData` resources (data/events): at most ONE absurd event per day, about two days in three have none (`Career.EVENT_CHANCE` = 0.32, so an event comes roughly every third day); announced by the boss, listed on the phone's notice board
- [x] 13 events: Security Upgrade (lasers), Emergency Floor Heating, Floor Waxing Day, Power Outage (flashlight), Dementia (shuffled shelves), Low Gravity, Storage Overflow (box maze), Ventilation Inspection (fans/updrafts), Demolition Inspection (wrecking ball), Workplace Safety Training (blocked doors + obstacle course), Pest Control (rats), Earthquake Aftershock (collapsing shelves), Mandatory Exercise Hour (trampolines/treadmills)

## Phase 6 - NPC employees, ranking, black market
- [x] Numeric ranking (Ranking app on the phone, bonus for best employee at midnight) and visible walking co-workers (placeholder capsules)
- [x] Black market seller: you must ask, half the time he has an edible item; restocks on entry and every 4 in-game hours; eat with E

## Phase 7 - Town and economy
- [x] Town blockout (empty buildings, road, train station under construction, lakes) - see docs/MAP.md
- [x] Bike (placeholder; twice as fast outside, not allowed at work), rent ($40 at midnight), home with a bed, sleeping
- [x] Furniture shop (5 pieces in `data/furniture`): sleep quality, rest regen, max energy
- [ ] SKIPPED: other vehicles (need models); fence for stolen goods (needs the stealing mechanic designed); home interior model; town culling
- [x] Take items out of a box (R) and peel the bill off (T) to repack into another box
- [x] Main menu: Continue / New Game (asks before overwriting) / Settings (volume, fullscreen, sensitivity) / Exit, with autosave
- [x] One save slot + backup, position/hotbar saved (warehouse saves as clocked out); hills and mountains beyond the town border
- [x] Sidewalks along all streets, and bushes/trees/grass spread over the town (your tree2, bush1, grass, sidewalk models)
- [x] The town is ONE scene with the world: ground, roads (`TownRoad`), railway, lakes, buildings, props and trees are nodes you move in the editor; the generator only makes the lake beds, sidewalks and vegetation; houses and apartment blocks are nodes too. Lakes have depth (bowl-shaped bed, water shader); the club lights only burn while it is open
- [x] 15 product models (bars, whey, chickpea powder, pills) as new items; 6 placeholder items retired (candy, chips, juice, pasta, rice, beans)
- [x] Push loose items by walking into them (stand/jump on them); caught scene: camera pans to the supervisor, reason, fade, ban quest entry
- [x] Quest log (HUD top right + phone Quests app), ban as a quest; screen messages moved above the hotbar
- [x] Sidewalk corner model only at real corners; wind (visual) leaning the grass
- [x] No warehouse events on the first 3 days of a new game (`Career.EVENT_FREE_DAYS`)
- [x] Left click puts the selected item in a box or places it; hold right click to throw (charge bar, hand shake); items are shown in the hand
- [x] Hotbar slots show the item's 3D model (rendered once per change), slot number bottom right on top, held item's name above the hotbar
- [x] Control hints on the left side of the screen (small, half transparent): everything possible right now except what the crosshair is aiming at
- [x] Eating takes 3 s (`Player.EAT_SECONDS`): you stand still, the item goes to your mouth, a bar shows progress; supervisors can catch you at it. Hints on the left no longer name items
- [x] NEW WAREHOUSE LAYOUT from the sketch: hall + office + corridor + Z/X/Y rooms + extra stock room, roofed with a higher ceiling; outside: plaza, parking, loading yard
- [x] Conveyor-belt loading line: belt -> check at the end -> robot arm -> pallet -> truck (placeholders); pallets are gone
- [x] Neighbourhood streets run on to the map edge / industrial road; thrown items no longer tunnel through walls
- [x] Bills sorted in walking order X -> Y -> Z; pay $7 per order, multiplier +0.05; Y corridors lettered from the east (A) and 7 corridors so the extra stock room is reachable
- [x] Carrying a box locks the hotbar; left click puts the box down; B attaches the bill; belt needs a bill; energy: idle ~free, sprint costs ~1.6x per metre
- [x] Bigger warehouse: 2.6 m aisles, 43 x 42 m floor + 22 m stock wing; all text is paper (PaperLabel), nothing floats or turns to face you
- [x] Weekday clock (Mon-Sun, no day counter) + Stats app (days passed and more) + Places app (venues and opening hours)
- [x] Apartment blocks in the neighbourhood (decor), gambling back room (weekdays) and underground night club (Fri-Sun nights)
- [x] Warehouse loads/unloads in slices (walls first, shelves fill in ~1 s, no frame over ~15 ms in the test)
- [x] Win at $1,000,000: pause, ending text, then "keep playing" (free play) or main menu

## Phase 8 - More mischief, slapstick fighting, audio, polish
- [ ] SKIPPED (need assets or design input): audio, slapstick fighting (animations), stealing/hiding mischief, polish
