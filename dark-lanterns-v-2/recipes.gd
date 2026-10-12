
extends Node

const RECIPES := {
	"bridge": {
		"name": "Bridge",
		"texture": "res://Bridge_horizontal_still_v1.png",
		"vertical_texture": "res://Bridge_vertical_still_v1.png",
		"cost": {
			"wood": 2
		},

		"allowed_tiles": [
			"water",
			"grass",
			"dirt",
			"rock",
			"ice",
			"snow",
			"sand"
		],

		"transform_tile": "dirt",

		# Dimensions in world tiles, not pixels.
		"dimensions": Vector2i(48, 12)
	}
}
