extends Node2D
# TEMP TEST HOOK — remove before final commit.
# Smoke-test for the GameData autoload: prints spot-check values to the
# Output panel on scene start, so a human running the editor (no Godot
# binary available in the environment this was written from) can confirm
# the data layer actually loaded, not just that the script editor shows
# no red squiggles.

func _ready() -> void:
	print("=== GameData smoke test ===")
	print("Tiers: ", GameData.TIERS.keys())
	print("Disasters: ", GameData.DISASTERS.keys())
	print("Dock disaster ids (ordered): ", GameData.DOCK_DISASTER_IDS)
	print("Synergies: ", GameData.SYNERGIES.size())
	print("Objectives: ", GameData.OBJECTIVES.size())
	print("Upgrade tree nodes: ", GameData.UPGRADE_TREE.size(), " (expected 21)")
	print("Core node: ", GameData.UPGRADE_TREE["core"])
	print("Wind unlock condition: ", GameData.DISASTERS["wind"]["unlock"])
	print("Storm unlock condition: ", GameData.DISASTERS["storm"]["unlock"])
	print("=== end smoke test — if you see this with no errors above, the data layer is good ===")
