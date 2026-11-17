# Town ideas ("make it feel like a city")

Reference: a screenshot of Schedule 1 (a town with an elevated railway, utility poles, parked
cars, forested hills, mountains behind). Our town feels like a village of boxes next to that.
These notes are the wish list taken from it, so we do not forget them when we implement things.
Status: DONE / PARTLY / LATER (needs models, or needs a design decision).

## The general direction
- **Fewer, bigger, more detailed buildings** that feel real size (stores, restaurants, a gas station), instead of
  many small boxes. Detail comes from the user's own models and hand-placed nodes (see
  `prefer-scene-nodes-over-generators`): the generator only does high-count things.
- **City furniture everywhere**: street lamps, utility poles with cables, traffic lights, parking bays,
  road markings, benches, fire hydrants, bus stops, signs.
- **Uneven ground**: the ground has highs and lows (not a flat slab). LATER: it touches everything
  (roads, buildings, lakes sit on the flat ground now), so it needs a plan: gentle noise on a
  heightmap ground, roads and building lots flattened.
- **Close, forested hills / sharp borders**: DONE as a cliff wall all round the town (about 40 m high) with a forested plateau on top
  (about 10,500 pines in two levels of detail) and higher mountains behind; fog halved. The first version was a belt of soft hills;
  the user asked for cliffs, so the border is sharp. See docs/SYSTEMS.md "Landscape".
- **Entrance through tunnels**: PARTLY. Two tunnel portals at the ends of the main road (north and west), 36 m long,
  lit, ending in a closed shutter ("TOWN EXIT - CLOSED FOR MAINTENANCE"). They lead nowhere yet: when we have
  somewhere to go (other areas, fast travel, the player's arrival), the shutter becomes a door or a loading trigger.
- **Elevated railway** on a bridge (pillars, deck, rails) with roads passing underneath, instead of a
  railway on the ground. LATER (the station and the rail strip would move up; decide how the player gets to
  the platform).

## Systems
- **Wallet and bank account** (ATM on the street): cash in the wallet vs money in the bank. Today there is only
  the bank (phone app); the ATM would let you withdraw/deposit, and some shops/venues only take cash. LATER.
- **Food as energy sources**: a fast-food restaurant (cheap energy) and a high-end restaurant (expensive,
  luxury food: bigger energy, status). LATER.
- **Gas station**: open 24/7, expensive and low quality goods (no fuelling: there are no vehicles to fuel). LATER.
- **Pub**: a night venue (opening hours in the Places app like the club). LATER.
- **Car gallery** (vehicle shop), **theatre** (cannot enter, only makes the town feel alive: posters,
  lit marquee). LATER.

## Public places
- **Green park with benches**: DONE (first version: lawn, paths, benches, trees, lamps), see `Town/Park` in the scene.
- **Dog park**: PARTLY (a fenced pen inside the park, empty: no dogs yet).
- **Skatepark**: LATER (ramps: a curved quarter-pipe needs a model or a generated mesh).
- **Autopark** (a car park lot, with painted bays) and **small parking spots at the side of the road**:
  PARTLY (painted roadside bays via `TownRoad.parking`; no cars: they need vehicle models).
- **Traffic lights** at junctions (with a light cycle) and **street lamps**: lamps DONE (`StreetFurniture`),
  traffic lights LATER (a prop scene + a cycle script, placed at the 4-way junctions).
- **Utility poles with cables** between them: DONE (`StreetFurniture`, per road: `TownRoad.utility_poles`).

## Life and humour
- **Pigeons**: flocks sit in the street (on the ground, on lamps, poles and roofs). When you come near they fly
  away, and they fly down and land again somewhere later. LATER (needs a bird model and an animation:
  idle, take-off, flight, landing; the behaviour is a small state machine, a few dozen birds at most, only
  simulated near the player). Source: the user's idea.
- **Meme easter eggs**: many of them, spread over the whole game, small and mostly optional.
  Keep a list here; every egg gets a line (where, trigger, what happens). LATER, one by one.
  - **"State property" dialogue while fishing**: when you fish (the lakes are the place; fishing itself does
    not exist yet), the dialogue about the fish/the lake being state property appears. The exact wording and
    who says it are for the user to give when we build fishing.

## How the done parts are made (so they can be tuned or replaced)
See docs/SYSTEMS.md "Street furniture". Short version: `scripts/world/street_furniture.gd` reads the roads and
places lamps, poles, cables and road markings (MultiMesh, made from simple shapes, no models). If you make a lamp or
pole model, point the generator at it instead of the generated shapes. The park is plain nodes under
`Town/Park`: move, delete and add them in the editor.
