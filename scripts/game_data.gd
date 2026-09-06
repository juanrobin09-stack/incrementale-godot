extends Node
## Incrementable — pure game data (mirrors the data tables in script.js
## from the original vanilla-JS project). Autoloaded as `GameData`.
##
## Foundation layer only: no economy/state logic lives here yet.

# ---------------------------------------------------------------------------
# Core economy constants
# ---------------------------------------------------------------------------
const TICK_MS := 100
const AUTOSAVE_MS := 10000
const MAX_OFFLINE_SECONDS := 2 * 60 * 60
const OFFLINE_EFFICIENCY := 0.5
const MIN_OFFLINE_SECONDS_TO_NOTIFY := 30

# KO (points de KO) is the currency for the Chaos Tree. It is always
# derived from existing persisted progress rather than accumulated as
# its own counter, so it can never desync from a save.
const KO_FROM_CHAOS_DIVISOR := 200
const KO_PER_OBJECTIVE := 3
const KO_PER_UNLOCK := 5

# ---------------------------------------------------------------------------
# Tiers
# ---------------------------------------------------------------------------
const TIERS := {
	"village": {"name": "Village", "icon": "🏘️", "order": 0},
	"small_town": {"name": "Petite ville", "icon": "🏙️", "order": 1},
	# big_city, metropolis, region... will slot in here in later versions.
}

# ---------------------------------------------------------------------------
# Levels
# ---------------------------------------------------------------------------
# A level is a whole world stage (its own WorldScene layout in
# world_scene.gd) — coarser-grained than a tier, which up to now was only
# ever inferred from the highest unlocked disaster (see get_current_tier_id()
# in game_state.gd, unchanged in spirit but now level-driven instead of a
# disaster-unlock heuristic, since that heuristic has nothing to say about
# *world layout*, only about the economy).
#
# Single source of truth for the level-select menu (level_select_menu.gd),
# the tier name shown in the HUD, and how far GameState.notify_structure_
# ruined() may auto-advance — replaces what used to be two separate consts
# (MAX_IMPLEMENTED_LEVEL, LEVEL_TIER_IDS) that both encoded "which levels
# actually exist" from two different angles and could in principle drift
# apart. `implemented: false` entries are reserved slots only — no
# WorldScene layout, no tier, always locked in the menu regardless of any
# unlock condition (see GameState.is_level_unlocked()) — so the UI can list
# levels 3-5 today without anything pretending they have real content.
# Adding level 6+ later is one more entry here; nothing else about this
# array's shape changes.
const LEVELS := [
	{"id": 1, "name": "Le village", "implemented": true, "tier_id": "village"},
	{"id": 2, "name": "La petite ville", "implemented": true, "tier_id": "small_town"},
	{"id": 3, "name": "Niveau 3", "implemented": false, "tier_id": ""},
	{"id": 4, "name": "Niveau 4", "implemented": false, "tier_id": ""},
	{"id": 5, "name": "Niveau 5", "implemented": false, "tier_id": ""},
]

func get_level_def(id: int) -> Dictionary:
	for lvl in LEVELS:
		if lvl["id"] == id:
			return lvl
	return {}

## Highest level id with real content — gates GameState.notify_structure_
## ruined()'s auto-advance: level 2's own destructible structures already
## report themselves ruined the same way level 1's do (see world_scene.gd),
## so the mechanism is exercised and ready, but nothing currently advances a
## fully-ruined level 2 into a level 3 that doesn't exist yet. Marking a
## future level 3 entry above as implemented=true the day its layout ships
## is the only change this needs.
func max_implemented_level() -> int:
	var highest := 0
	for lvl in LEVELS:
		if lvl["implemented"]:
			highest = max(highest, lvl["id"])
	return highest

# ---------------------------------------------------------------------------
# Disasters
# ---------------------------------------------------------------------------
# Capped on request: each disaster's level (rain/wind/storm/flood, "les
# compétences") now stops at 15 rather than climbing forever — a deliberate
# early ceiling, not a balance tweak derived from the visual-stage curve
# below (max_visual_stage/levels_per_stage already caps each disaster's
# damage art well before level 15 on its own).
const MAX_DISASTER_LEVEL := 15

const DISASTERS := {
	"rain": {
		"id": "rain", "name": "Pluie", "icon": "🌧️", "tier": "village",
		"description": "Une pluie douce qui trempe le village goutte à goutte.",
		"tags": ["water", "sky"],
		"unlock": null,
		"base_cost": 10, "cost_growth": 1.13,
		"base_production": 1,
		"max_visual_stage": 4, "levels_per_stage": 3,
	},
	"wind": {
		"id": "wind", "name": "Vent", "icon": "💨", "tier": "village",
		"description": "Des rafales qui agitent les arbres, les nuages et le moulin.",
		"tags": ["air"],
		"unlock": {"chaos": 150},
		"base_cost": 75, "cost_growth": 1.14,
		"base_production": 2.5,
		"max_visual_stage": 3, "levels_per_stage": 3,
	},
	"storm": {
		"id": "storm", "name": "Petit orage", "icon": "⚡", "tier": "village",
		"description": "Grondements et éclairs stylisés au-dessus du village.",
		"tags": ["sky", "electric"],
		"unlock": {"chaos": 1500, "disaster_level": {"id": "wind", "level": 3}},
		"base_cost": 450, "cost_growth": 1.15,
		"base_production": 8,
		"max_visual_stage": 2, "levels_per_stage": 4,
	},
	"flood": {
		"id": "flood", "name": "Petite montée des eaux", "icon": "🌊", "tier": "village",
		"description": "La rivière enfle doucement et grignote la berge.",
		"tags": ["water"],
		"unlock": {"chaos": 6000, "disaster_level": {"id": "rain", "level": 6}},
		"base_cost": 1400, "cost_growth": 1.16,
		"base_production": 18,
		"max_visual_stage": 2, "levels_per_stage": 4,
		# Excluded from the dock display on request (see get_dock_disaster_
		# ids() below) even though it stays fully defined everywhere else —
		# Chaos Tree branch, objective, scene captions all keep working.
		"dock": false,
	},

	# ---- Petite ville (niveau 2) --------------------------------------
	# Carte blanche demandée explicitement pour ces deux-là : choisies pour
	# diversifier au-delà de "encore un phénomène météo" (rain/wind/storm/
	# flood couvrent déjà air/eau/ciel/électricité à eux quatre) plutôt que
	# pour ajouter un 5e/6e effet de la même famille. "earth" est un danger
	# structurel (le sol/les fondations) au lieu d'atmosphérique ; "arcane"
	# est un danger magique qui prolonge directement le thème du jeu — le
	# joueur incarne déjà "l'Éveil du Chaos" (voir UPGRADE_TREE.core plus
	# bas), donc une corruption qui grandit avec le pouvoir accumulé est la
	# même idée que le reste du jeu, pas un ajout hors-sujet. Justification
	# narrative du "pourquoi seulement à partir de la ville" : une ville
	# plus lourde et plus dense fragilise davantage ses fondations (quake)
	# et concentre davantage la propre puissance chaotique du joueur en un
	# seul endroit (blight) — deux raisons qu'un simple village isolé n'a
	# pas. `unlock.level` (nouvelle clé, voir meets_unlock_condition dans
	# game_state.gd) gate les deux sur le niveau 2 en plus de leurs propres
	# seuils, pour qu'elles n'apparaissent jamais tant que le village n'est
	# pas entièrement détruit.
	"quake": {
		"id": "quake", "name": "Secousses souterraines", "icon": "🕳️", "tier": "small_town",
		"description": "Le poids de la ville réveille de vieilles galeries qui craquent sous les rues.",
		"tags": ["earth"],
		"unlock": {"level": 2},
		"base_cost": 5500, "cost_growth": 1.17,
		"base_production": 45,
		"max_visual_stage": 3, "levels_per_stage": 4,
	},
	"blight": {
		"id": "blight", "name": "Corruption runique", "icon": "🔮", "tier": "small_town",
		"description": "Une lueur violette ronge peu à peu la pierre et le bois, portée par ton propre Chaos.",
		"tags": ["arcane"],
		"unlock": {"level": 2, "chaos": 40000, "disaster_level": {"id": "quake", "level": 5}},
		"base_cost": 20000, "cost_growth": 1.18,
		"base_production": 140,
		"max_visual_stage": 3, "levels_per_stage": 4,
	},
}

const DOCK_LOGOS := {
	"rain": "res://assets/disasters/rain.png",
	"wind": "res://assets/disasters/wind.png",
	"storm": "res://assets/disasters/storm.png",
	# quake/blight have no dock logo yet — no reference art exists for them
	# (unlike rain/wind/storm's, provided directly) and this project has no
	# image-generation tool to fabricate one from nothing (see palette.gd's
	# own header for that same recurring constraint). disaster_dock.gd
	# falls back to the disaster's emoji icon when an id has no entry here,
	# rather than crashing on a missing load() path — real PNGs can slot in
	# later exactly the way rain/wind/storm's already did, no other change
	# needed.
}

## Dock roster for a given level: every disaster whose own tier unlocks at
## or before that level's tier (TIERS[...]["order"]), except any explicitly
## opted out via "dock": false on its own DISASTERS entry (only flood
## today). Replaces two hand-maintained per-level id lists that could
## silently drift from DISASTERS' own tier data — a disaster's tier is now
## the only thing deciding when it gains a dock slot, appended
## automatically (nothing is ever removed once earned), matching how an
## incremental game's economy keeps compounding rather than resetting per
## stage. A future level 3 disaster needs no change here, only its own
## "tier" entry in DISASTERS.
func get_dock_disaster_ids(level: int) -> Array:
	var tier_id: String = get_level_def(level).get("tier_id", "village")
	var max_order: int = TIERS[tier_id]["order"]
	var ids: Array = []
	for id in DISASTERS:
		var cfg: Dictionary = DISASTERS[id]
		if not cfg.get("dock", true):
			continue
		if TIERS[cfg["tier"]]["order"] <= max_order:
			ids.append(id)
	return ids

# ---------------------------------------------------------------------------
# Synergies
# ---------------------------------------------------------------------------
# Passive bonuses one disaster grants to another. Combined/triggered
# disasters (tempête, glissement de terrain...) can plug into this same
# list later as their own entries.
const SYNERGIES := [
	{"id": "wind_rain", "source": "wind", "target": "rain", "per_level": 0.05,
		"description": "Le vent intensifie la pluie"},
	{"id": "quake_blight", "source": "quake", "target": "blight", "per_level": 0.05,
		"description": "Les fissures libèrent une énergie que la corruption absorbe"},
]

# ---------------------------------------------------------------------------
# Objectives
# ---------------------------------------------------------------------------
# `condition` is declarative rather than the JS version's closure
# (`check: s => s.totalChaosEarned >= 100`), so this stays pure data —
# evaluating these against runtime state is future logic-layer work.
const OBJECTIVES := [
	{"id": "obj_100_chaos", "text": "Produire 100 Chaos",
		"condition": {"kind": "total_chaos_earned_gte", "value": 100}},
	{"id": "obj_rain_5", "text": "Améliorer la Pluie au niveau 5",
		"condition": {"kind": "disaster_level_gte", "disaster": "rain", "value": 5}},
	{"id": "obj_unlock_wind", "text": "Débloquer le Vent",
		"condition": {"kind": "disaster_unlocked", "disaster": "wind"}},
	{"id": "obj_5000_chaos", "text": "Atteindre 5 000 Chaos (cumulés)",
		"condition": {"kind": "total_chaos_earned_gte", "value": 5000}},
	{"id": "obj_unlock_storm", "text": "Débloquer le Petit orage",
		"condition": {"kind": "disaster_unlocked", "disaster": "storm"}},
	{"id": "obj_unlock_flood", "text": "Débloquer la Montée des eaux",
		"condition": {"kind": "disaster_unlocked", "disaster": "flood"}},
	{"id": "obj_reach_level_2", "text": "Détruire entièrement le village",
		"condition": {"kind": "level_gte", "value": 2}},
	{"id": "obj_unlock_quake", "text": "Débloquer les Secousses souterraines",
		"condition": {"kind": "disaster_unlocked", "disaster": "quake"}},
	{"id": "obj_unlock_blight", "text": "Débloquer la Corruption runique",
		"condition": {"kind": "disaster_unlocked", "disaster": "blight"}},
]

# ---------------------------------------------------------------------------
# Chaos Tree
# ---------------------------------------------------------------------------
# A radial skill tree. `core` sits at the center and is always owned;
# every branch is a straight chain radiating outward at a fixed angle.
# Adding a new branch later is just adding nodes with a new `branch` key
# and an angle in BRANCH_ANGLES — nothing else to touch. `requires_disaster`
# optionally gates a node on the underlying disaster being unlocked (no
# point boosting a disaster you don't have yet). `coming_soon` nodes are
# permanently unpurchasable in V1 — they exist to preview future tiers.
#
# The flood branch (angle 180, left wing) was removed on request — the
# Chaos Tree's own layout only, not the "flood" disaster itself (still
# fully defined in DISASTERS below, still reachable from the dock/
# popover, its own unlock/objective untouched). ChaosTreeOverlay and
# game_state.gd's tree-purchase logic both already iterate from this
# const as their source of truth (confirmed before removing anything,
# not assumed) rather than from any saved state, so an existing save
# with flood_* purchases just has that stray data ignored on next load —
# the load_game() merge in game_state.gd only ever copies a saved node's
# state for ids that still exist here, by design, already.
#
# The 3 survivors were also explicitly rotated 90° rather than left at
# their old angles with a gap where flood's slot (180°, left) used to
# be: rain -90→180, wind 0→-90, storm 90→0 — each of the 4 original
# compass slots keeps exactly one branch except the vacated one, which
# lands at 90° (bottom) instead of 180° (left). Specified explicitly,
# arm by arm ("le haut va à gauche, la droite va en haut, le bas va à
# droite"), not chosen freely.
const BRANCH_ANGLES := {"wind": -90, "rain": 180, "storm": 0}

const UPGRADE_TREE := {
	"core": {
		"id": "core", "name": "Éveil du Chaos", "icon": "🌀", "branch": "core", "depth": 0,
		"cost": 0, "requires": [], "auto_owned": true,
		"description": "Le point d'origine de ta puissance grandissante.",
	},

	"wind_1": {"id": "wind_1", "name": "Vent I", "icon": "🍃", "branch": "wind", "depth": 1, "cost": 5, "requires": ["core"], "requires_disaster": "wind",
		"description": "Une brise taquine se lève sur le village.", "effect": {"type": "disaster_production_mult", "target": "wind", "value": 0.08}},
	"wind_2": {"id": "wind_2", "name": "Vent II", "icon": "💨", "branch": "wind", "depth": 2, "cost": 15, "requires": ["wind_1"],
		"description": "Le vent forcit et porte plus loin.", "effect": {"type": "disaster_production_mult", "target": "wind", "value": 0.08}},
	"wind_3": {"id": "wind_3", "name": "Vent III", "icon": "🌬️", "branch": "wind", "depth": 3, "cost": 40, "requires": ["wind_2"],
		"description": "Des rafales commencent à inquiéter les villageois.", "effect": {"type": "disaster_production_mult", "target": "wind", "value": 0.08}},
	"wind_4": {"id": "wind_4", "name": "Rafales", "icon": "🌪️", "branch": "wind", "depth": 4, "cost": 100, "requires": ["wind_3"],
		"description": "Des bourrasques puissantes balaient tout sur leur passage.", "effect": {"type": "disaster_production_mult", "target": "wind", "value": 0.14}},
	"wind_5": {"id": "wind_5", "name": "Tempête", "icon": "🌀", "branch": "wind", "depth": 5, "cost": null, "requires": ["wind_4"], "coming_soon": true,
		"description": "Combinaison Vent + Pluie. Débarquera dans une future mise à jour."},

	"rain_1": {"id": "rain_1", "name": "Nuages bas", "icon": "☁️", "branch": "rain", "depth": 1, "cost": 5, "requires": ["core"],
		"description": "Le ciel commence à se couvrir au-dessus du village.", "effect": {"type": "disaster_production_mult", "target": "rain", "value": 0.08}},
	"rain_2": {"id": "rain_2", "name": "Nuages plus denses", "icon": "🌥️", "branch": "rain", "depth": 2, "cost": 15, "requires": ["rain_1"],
		"description": "Des nuages plus épais retiennent davantage d'eau.", "effect": {"type": "disaster_production_mult", "target": "rain", "value": 0.08}},
	"rain_3": {"id": "rain_3", "name": "Pluie battante", "icon": "🌧️", "branch": "rain", "depth": 3, "cost": 40, "requires": ["rain_2"],
		"description": "Les gouttes se font plus grosses et plus fréquentes.", "effect": {"type": "disaster_production_mult", "target": "rain", "value": 0.08}},
	"rain_4": {"id": "rain_4", "name": "Sol détrempé", "icon": "💧", "branch": "rain", "depth": 4, "cost": 100, "requires": ["rain_3"],
		"description": "Le sol gorgé d'eau amplifie tout ce qui touche à l'eau.", "effect": {"type": "tag_production_mult", "tag": "water", "value": 0.15}},
	"rain_5": {"id": "rain_5", "name": "Déluge", "icon": "🌊", "branch": "rain", "depth": 5, "cost": null, "requires": ["rain_4"], "coming_soon": true,
		"description": "Une pluie d'une intensité inédite. Débarquera dans une future mise à jour."},

	"storm_1": {"id": "storm_1", "name": "Étincelles", "icon": "✨", "branch": "storm", "depth": 1, "cost": 5, "requires": ["core"], "requires_disaster": "storm",
		"description": "De petites décharges crépitent dans les nuages.", "effect": {"type": "disaster_production_mult", "target": "storm", "value": 0.08}},
	"storm_2": {"id": "storm_2", "name": "Charge électrique", "icon": "🔌", "branch": "storm", "depth": 2, "cost": 15, "requires": ["storm_1"],
		"description": "L'air se charge d'électricité statique.", "effect": {"type": "disaster_production_mult", "target": "storm", "value": 0.08}},
	"storm_3": {"id": "storm_3", "name": "Grondement", "icon": "🌩️", "branch": "storm", "depth": 3, "cost": 40, "requires": ["storm_2"],
		"description": "Le tonnerre commence à se faire entendre au loin.", "effect": {"type": "disaster_production_mult", "target": "storm", "value": 0.08}},
	"storm_4": {"id": "storm_4", "name": "Éclairs violents", "icon": "⚡", "branch": "storm", "depth": 4, "cost": 100, "requires": ["storm_3"],
		"description": "Les éclairs frappent plus souvent et plus fort.", "effect": {"type": "disaster_production_mult", "target": "storm", "value": 0.14}, "lightning_boost": true},
	"storm_5": {"id": "storm_5", "name": "Cyclone", "icon": "🌀", "branch": "storm", "depth": 5, "cost": null, "requires": ["storm_4"], "coming_soon": true,
		"description": "Une tempête électrique dévastatrice. Débarquera dans une future mise à jour."},
}
