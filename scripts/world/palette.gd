class_name Palette
extends RefCounted
## Direct translation of the PAL table in render.js. Keys are kept in
## the original's camelCase (not this project's usual snake_case) on
## purpose: this whole world layer is a large, purely mechanical port
## of hand-tuned pixel values with no way to visually re-check them —
## keeping identical keys means a lookup here can be compared line-by-
## line against the original instead of trusting a renamed transcription.
##
## grassLight2/grassDeep/grassDry/flowerAccent/leafPale/lampIron/
## lampIronLit/skyUpperAccent have no render.js counterpart — added for
## the decor-vs-house visual coherence pass (ground/tree/lamp/sky detail
## richness) once the houses became real reference art these procedural
## primitives needed to visually hold up against. Same camelCase
## convention, kept alongside the ported keys rather than split out, so
## every world-layer colour still lives in one place.

const PAL := {
	"skyTop": "#5fa8e0", "skyMid": "#a9d9f2", "skyHorizon": "#ffe6ad",
	"skyTopStorm": "#20263a", "skyMidStorm": "#3a4258", "skyHorizonStorm": "#5a6274",
	"sun": "#fff3c4", "sunMid": "#ffd873", "sunEdge": "#ffb84d",
	"cloud": "#ffffff", "cloudShadow": "#c3d2e0",
	"cloudStorm": "#5c6577", "cloudStormShadow": "#3c4353",
	"hillsFar": "#82a6ae", "hillsNear": "#5f8b93",
	"grassLight": "#8fcf6e", "grassMid": "#6fae52", "grassDark": "#4f8f3d", "grassShadow": "#3d7230",
	"grassLight2": "#a8dc7e", "grassDeep": "#2f5c26", "grassDry": "#c2a85e", "flowerAccent": "#e0a8d8",
	"dirt": "#a3835a", "dirtDark": "#7a6142", "dirtLight": "#cfae7c",
	"waterDeep": "#1f6f9c", "waterMid": "#3391c4", "waterLight": "#78d0ee", "waterFoam": "#eaf8ff",
	"wood": "#a06b38", "woodDark": "#6b4523", "woodLight": "#c98f52",
	"stone": "#a29c8e", "stoneDark": "#726c60", "stoneLight": "#c7c2b8",
	"wallCream": "#f3e3c2", "wallCreamShadow": "#d8c49f",
	"wallRose": "#ecd2c2", "wallRoseShadow": "#cfae9b",
	"wallSlate": "#dfe6ea", "wallSlateShadow": "#bcc7cd",
	"door": "#5c3a20", "doorShadow": "#40270f",
	"windowGlass": "#bfe3f7", "windowGlow": "#ffe9a0", "windowFrame": "#6b4a2c",
	"roofRed": "#c0453b", "roofRedShadow": "#8a2f27",
	"roofBlue": "#3f6fa8", "roofBlueShadow": "#2a4d78",
	"roofGreen": "#3f8f5c", "roofGreenShadow": "#2a663f",
	"roofGold": "#d6a23a", "roofGoldShadow": "#a97a22",
	"roofPurple": "#5b2963", "roofPurpleShadow": "#4a1d51",
	"leafLight": "#82c968", "leafMid": "#4f9a3d", "leafDark": "#356b28", "leafPale": "#a8e08a",
	"pineLight": "#4d9364", "pineDark": "#2f6b40",
	"trunk": "#8a5a34", "trunkDark": "#5c3b20", "trunkLit": "#a97442",
	"gold": "#f5b942",
	"attic": "#241c22",
	"rubbleWood": "#8a6a48", "rubbleWoodDark": "#5c4530",
	"lampIron": "#2b2620", "lampIronLit": "#5c5347",
	"skyUpperAccent": "#3f7cc4",
}

static func c(key: String) -> Color:
	return Color(PAL[key])
