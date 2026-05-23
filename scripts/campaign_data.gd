extends RefCounted
class_name CampaignData

# ── CHARACTER DEFINITIONS ─────────────────────────────────────────────────────
# "side" controls which portrait lights up when they speak.

const CHARACTERS: Dictionary = {
	"self": {
		"name":  "COMMANDER",
		"color": Color(0.90, 0.68, 0.22),  # warm amber — the resistance leader
		"side":  "left",
	},
	"hq": {
		"name":  "GHOST  [HQ]",
		"color": Color(0.32, 0.72, 0.95),  # cool blue — radio advisor
		"side":  "right",
	},
}

# ── LOCATION TABLE (mirrors globe.gd LOCATIONS) ────────────────────────────────
# Kept here so campaign_mgr.gd can set main.gd active_lat/lon without
# instantiating a Globe node or adding a cross-scene dependency.

const LOCATIONS: Array = [
	{"name": "New York, NY",       "lat": 40.7128,  "lon": -74.0060},
	{"name": "Chicago, IL",        "lat": 41.8781,  "lon": -87.6298},
	{"name": "London, UK",         "lat": 51.5074,  "lon":  -0.1278},
	{"name": "Tokyo, Japan",       "lat": 35.6762,  "lon": 139.6503},
	{"name": "Sydney, Australia",  "lat": -33.8688, "lon": 151.2093},
	{"name": "Paris, France",      "lat": 48.8566,  "lon":   2.3522},
	{"name": "Dubai, UAE",         "lat": 25.2048,  "lon":  55.2708},
	{"name": "Moscow, Russia",     "lat": 55.7558,  "lon":  37.6173},
	{"name": "Kyiv, Ukraine",      "lat": 50.4501,  "lon":  30.5234},
	{"name": "Berlin, Germany",    "lat": 52.5200,  "lon":  13.4050},
	{"name": "Fallujah, Iraq",     "lat": 33.3500,  "lon":  43.7833},
	{"name": "Stalingrad, Russia", "lat": 48.7080,  "lon":  44.5133},
]

# ── WORLD ADJACENCY ─────────────────────────────────────────────────────────────
# Keys are LOCATIONS indices.  Values are arrays of unlockable neighbour indices.

const WORLD_ADJACENCY: Dictionary = {
	0:  [1, 2],        # New York  → Chicago, London
	1:  [0, 5],        # Chicago   → New York, Paris
	2:  [0, 5, 9],     # London    → New York, Paris, Berlin
	3:  [4, 6],        # Tokyo     → Sydney, Dubai
	4:  [3],           # Sydney    → Tokyo
	5:  [1, 2, 9],     # Paris     → Chicago, London, Berlin
	6:  [3, 7, 10],    # Dubai     → Tokyo, Moscow, Fallujah
	7:  [8, 9, 11],    # Moscow    → Kyiv, Berlin, Stalingrad
	8:  [7, 9],        # Kyiv      → Moscow, Berlin
	9:  [2, 5, 7, 8],  # Berlin    → London, Paris, Moscow, Kyiv
	10: [6, 11],       # Fallujah  → Dubai, Stalingrad
	11: [7, 10],       # Stalingrad→ Moscow, Fallujah
}

# ── PROLOGUE MISSION DEFINITIONS ──────────────────────────────────────────────
#
# location_key: int   ≥ 0  = LOCATIONS index
#                     -1   = player's chosen home city
# difficulty_override: "easy"|"normal"|"hard"  (overrides globe selection)
# wave_cap: int   > 0 = stop after this many waves (story continues regardless)
#                 0   = play full WAVE_DEFS length
# pre:       Array[{speaker, text}]   — shown BEFORE the battle
# post_win:  Array[{speaker, text}]   — shown after player wins
# post_loss: Array[{speaker, text}]   — shown after player loses
#
# {HOME_CITY} in text is replaced at runtime with the player's chosen city name.

const PROLOGUE_MISSIONS: Array = [
	# ── Mission 01: The Fall ─────────────────────────────────────────────────
	{
		"title":    "MISSION 01  —  THE FALL",
		"subtitle": "Prologue: Defend {HOME_CITY} as long as you can",
		"location_key": -1,
		"difficulty_override": "hard",
		"wave_cap": 3,
		"pre": [
			{"speaker": "hq",   "text": "Commander. PMC Vanguard units crossed the outer perimeter forty minutes ago. We're already losing the western districts."},
			{"speaker": "self", "text": "How long before armoured columns reach us?"},
			{"speaker": "hq",   "text": "Maybe thirty minutes. Hold the neighbourhood — we need time to evacuate civilians through the eastern corridor."},
			{"speaker": "self", "text": "Understood. We'll buy them every second we can."},
		],
		"post_win": [
			{"speaker": "hq",   "text": "You held longer than anyone expected. Remarkable."},
			{"speaker": "self", "text": "It wasn't enough. {HOME_CITY} is gone, Ghost."},
			{"speaker": "hq",   "text": "The people aren't. That's what matters. Fall back north — there's a safehouse in Berlin."},
			{"speaker": "self", "text": "Acknowledged. Falling back. But we're coming back for this city."},
		],
		"post_loss": [
			{"speaker": "self", "text": "The district is overrun. Pulling back now."},
			{"speaker": "hq",   "text": "Expected. Get your people out alive. Fall back north — Berlin safehouse, grid seven."},
			{"speaker": "self", "text": "We'll be back for {HOME_CITY}. I promise you that."},
			{"speaker": "hq",   "text": "That's the plan. But first — survive."},
		],
	},
	# ── Mission 02: Ghost Town ───────────────────────────────────────────────
	{
		"title":    "MISSION 02  —  GHOST TOWN",
		"subtitle": "Regroup: Secure a forward operating base",
		"location_key": 9,  # Berlin, Germany
		"difficulty_override": "normal",
		"wave_cap": 0,
		"pre": [
			{"speaker": "hq",   "text": "PMC is spreading faster than we modelled. Berlin is their next major staging hub — if they take it, resupply lines cut half the continent."},
			{"speaker": "self", "text": "Then we establish a base here first. Hold it, and they can't use it."},
			{"speaker": "hq",   "text": "You'll have minimal resources. Local resistance cells are willing to fight. Use them well."},
			{"speaker": "self", "text": "Militia only for now. We make do with what we have."},
			{"speaker": "hq",   "text": "One more thing. If this works — word will spread. Other cities are watching."},
		],
		"post_win": [
			{"speaker": "hq",   "text": "Berlin holds. Resistance cells across the district are mobilising — you've given them proof."},
			{"speaker": "self", "text": "Proof that PMC can be stopped. That's all we needed."},
			{"speaker": "hq",   "text": "Contacts incoming from London, Paris, and further east. This is growing."},
			{"speaker": "self", "text": "Good. Let's build something worth fighting for."},
		],
		"post_loss": [
			{"speaker": "hq",   "text": "We lost the district. But the cell is intact — no captures."},
			{"speaker": "self", "text": "We need to be smarter. PMC adapts every engagement."},
			{"speaker": "hq",   "text": "There's a second viable site. Different approach — tighter perimeter, fewer choke points."},
			{"speaker": "self", "text": "One more shot. We make it count."},
		],
	},
	# ── Mission 03: The Network ──────────────────────────────────────────────
	{
		"title":    "MISSION 03  —  THE NETWORK",
		"subtitle": "Consolidate: Defend the arms cache long enough to extract it",
		"location_key": 2,  # London, UK
		"difficulty_override": "normal",
		"wave_cap": 0,
		"pre": [
			{"speaker": "hq",   "text": "London resistance has a weapons stockpile — anti-armour, encrypted comms, medical. Everything we need for the next phase."},
			{"speaker": "self", "text": "And PMC knows about it."},
			{"speaker": "hq",   "text": "They always do. We defend the cache long enough to ship it out. Three waves minimum."},
			{"speaker": "self", "text": "London's urban — tight sightlines. Grenadiers and snipers should hold the flanks."},
		],
		"post_win": [
			{"speaker": "hq",   "text": "Cache extracted. We're properly armed for the first time since {HOME_CITY}."},
			{"speaker": "self", "text": "Then it's time to take the fight to them."},
			{"speaker": "hq",   "text": "Almost. We still need intelligence on the home city garrison before we move."},
			{"speaker": "self", "text": "Someone's still there, Ghost. I can feel it."},
		],
		"post_loss": [
			{"speaker": "self", "text": "Lost half the cache. PMC hit harder than projected."},
			{"speaker": "hq",   "text": "Half is more than zero. We work with what survived."},
			{"speaker": "self", "text": "They're always one step ahead. We need better intelligence."},
			{"speaker": "hq",   "text": "I'm working on exactly that."},
		],
	},
	# ── Mission 04: Last Intel ───────────────────────────────────────────────
	{
		"title":    "MISSION 04  —  LAST INTEL",
		"subtitle": "Prepare: Protect the extraction of a deep-cover asset",
		"location_key": 7,  # Moscow, Russia
		"difficulty_override": "hard",
		"wave_cap": 0,
		"pre": [
			{"speaker": "hq",   "text": "PMC runs its eastern logistics through Moscow. I have an asset embedded deep inside — they have the garrison rotation schedules for {HOME_CITY}."},
			{"speaker": "self", "text": "If we secure the extraction zone long enough, we get their blind spots. We go in knowing exactly where they're weak."},
			{"speaker": "hq",   "text": "Correct. But their security here is heavier. They know someone is watching."},
			{"speaker": "self", "text": "Then we hit before they're ready. Ghost — this is the last piece before we go home."},
			{"speaker": "hq",   "text": "I know. Don't let the weight of that slow you down."},
		],
		"post_win": [
			{"speaker": "hq",   "text": "Asset extracted. Garrison rotation schedules confirmed. We have their blind spots for a six-hour window."},
			{"speaker": "self", "text": "Then we're going home."},
			{"speaker": "hq",   "text": "The resistance is ready. Every city that held a line — they're all watching this one."},
			{"speaker": "self", "text": "Let's make it worth watching."},
		],
		"post_loss": [
			{"speaker": "hq",   "text": "Asset didn't make it out. We have partial data — enough to find two of the four blind spots."},
			{"speaker": "self", "text": "It'll have to be enough. We can't wait any longer."},
			{"speaker": "hq",   "text": "Understood. You give the order. I'll work with what we have."},
			{"speaker": "self", "text": "Prepare the assault. We move at dawn."},
		],
	},
	# ── Mission 05: Liberation ───────────────────────────────────────────────
	{
		"title":    "MISSION 05  —  LIBERATION",
		"subtitle": "Final assault: Reclaim {HOME_CITY}",
		"location_key": -1,  # home city again
		"difficulty_override": "hard",
		"wave_cap": 0,
		"pre": [
			{"speaker": "self", "text": "This is the street I grew up on. They turned it into a PMC checkpoint."},
			{"speaker": "hq",   "text": "Three hardened positions across the district. All occupied. We have a six-hour window before rotation."},
			{"speaker": "self", "text": "Then we take them back. Every single one."},
			{"speaker": "hq",   "text": "Commander — if this doesn't go the way we planned—"},
			{"speaker": "self", "text": "It will. Are you ready, Ghost?"},
			{"speaker": "hq",   "text": "...Ready. Let's bring you home."},
		],
		"post_win": [
			{"speaker": "hq",   "text": "PMC forces are routing across all three positions. The district is clear."},
			{"speaker": "self", "text": "Get the civilians back into the streets. This city is ours again."},
			{"speaker": "hq",   "text": "Copy that. Commander — you actually did it."},
			{"speaker": "self", "text": "We did it. The whole resistance. Every city that held, every person who picked up a rifle..."},
			{"speaker": "hq",   "text": "This isn't over. PMC still controls dozens of cities out there."},
			{"speaker": "self", "text": "I know. But now the world knows it can be taken back. That changes everything."},
		],
		"post_loss": [
			{"speaker": "hq",   "text": "Commander, we're losing ground on all fronts. Abort — pull back now!"},
			{"speaker": "self", "text": "No. We hold until there's nothing left to hold."},
			{"speaker": "hq",   "text": "That is a direct order. Live to fight again — or this ends here for everyone!"},
			{"speaker": "self", "text": "...Understood. Falling back. But Ghost — this isn't over."},
			{"speaker": "hq",   "text": "It never is. Not for people like us. We'll get another chance."},
		],
	},
]
