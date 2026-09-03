class_name Palette
extends RefCounted
## Direct translation of the PAL table in render.js. Keys are kept in
## the original's camelCase (not this project's usual snake_case) on
## purpose: this whole world layer is a large, purely mechanical port
## of hand-tuned pixel values with no way to visually re-check them —
## keeping identical keys means a lookup here can be compared line-by-
## line against the original instead of trusting a renamed transcription.

const PAL := {
	"skyTop": "#5fa8e0", "skyMid": "#a9d9f2", "skyHorizon": "#ffe6ad",
	"skyTopStorm": "#20263a", "skyMidStorm": "#3a4258", "skyHorizonStorm": "#5a6274",
	"sun": "#fff3c4", "sunMid": "#ffd873", "sunEdge": "#ffb84d",
	"cloud": "#ffffff", "cloudShadow": "#c3d2e0",
	"cloudStorm": "#5c6577", "cloudStormShadow": "#3c4353",
	"hillsFar": "#82a6ae", "hillsNear": "#5f8b93",
	"grassLight": "#8fcf6e", "grassMid": "#6fae52", "grassDark": "#4f8f3d", "grassShadow": "#3d7230",
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
	"leafLight": "#82c968", "leafMid": "#4f9a3d", "leafDark": "#356b28",
	"pineLight": "#4d9364", "pineDark": "#2f6b40",
	"trunk": "#8a5a34", "trunkDark": "#5c3b20", "trunkLit": "#a97442",
	"gold": "#f5b942",
	"attic": "#241c22",
	"rubbleWood": "#8a6a48", "rubbleWoodDark": "#5c4530",
}

static func c(key: String) -> Color:
	return Color(PAL[key])
