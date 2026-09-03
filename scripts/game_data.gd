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
	# small_town, big_city, metropolis, region... will slot in here in later versions.
}

# ---------------------------------------------------------------------------
# Disasters
# ---------------------------------------------------------------------------
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
	},
}

# The disaster dock (bottom-left panel, in the web version) intentionally
# shows only these three, in this order — flood stays fully defined above
# (Chaos Tree branch, objective, scene captions all keep working) but is
# excluded from the dock display itself.
const DOCK_DISASTER_IDS := ["rain", "wind", "storm"]
const DOCK_LOGOS := {
	"rain": "res://assets/disasters/rain.png",
	"wind": "res://assets/disasters/wind.png",
	"storm": "res://assets/disasters/storm.png",
}

# ---------------------------------------------------------------------------
# Synergies
# ---------------------------------------------------------------------------
# Passive bonuses one disaster grants to another. Combined/triggered
# disasters (tempête, glissement de terrain...) can plug into this same
# list later as their own entries.
const SYNERGIES := [
	{"id": "wind_rain", "source": "wind", "target": "rain", "per_level": 0.05,
		"description": "Le vent intensifie la pluie"},
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
const BRANCH_ANGLES := {"wind": 0, "rain": -90, "storm": 90, "flood": 180}

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

	"flood_1": {"id": "flood_1", "name": "Ruisseau agité", "icon": "〰️", "branch": "flood", "depth": 1, "cost": 5, "requires": ["core"], "requires_disaster": "flood",
		"description": "Le petit cours d'eau du village s'agite un peu plus.", "effect": {"type": "disaster_production_mult", "target": "flood", "value": 0.08}},
	"flood_2": {"id": "flood_2", "name": "Berges fragiles", "icon": "🪨", "branch": "flood", "depth": 2, "cost": 15, "requires": ["flood_1"],
		"description": "La terre des berges commence à céder.", "effect": {"type": "disaster_production_mult", "target": "flood", "value": 0.08}},
	"flood_3": {"id": "flood_3", "name": "Crue montante", "icon": "🌊", "branch": "flood", "depth": 3, "cost": 40, "requires": ["flood_2"],
		"description": "Le niveau de l'eau grimpe visiblement.", "effect": {"type": "disaster_production_mult", "target": "flood", "value": 0.08}},
	"flood_4": {"id": "flood_4", "name": "Rupture de digue", "icon": "🧱", "branch": "flood", "depth": 4, "cost": 100, "requires": ["flood_3"],
		"description": "Les rares protections du village menacent de céder.", "effect": {"type": "disaster_production_mult", "target": "flood", "value": 0.14}},
	"flood_5": {"id": "flood_5", "name": "Inondation", "icon": "🌊", "branch": "flood", "depth": 5, "cost": null, "requires": ["flood_4"], "coming_soon": true,
		"description": "Une inondation majeure engloutira bien plus que la berge. Débarquera dans une future mise à jour."},
}
