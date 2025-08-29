extends Node

var bodyarea_map = {}

var legs_dog = [
	[7, 31, 9, 10, 11, 13, 23, 33, 34, 35, 37, 47], # front legs 
	[40, 16, 0, 12, 20, 21, 22, 24, 36, 44, 45, 46], # back legs
]
var legs_cat = [ 
	[12, 13, 16, 17, 18, 19, 20, 21, 22, 23, 63, 64], # front
	[0, 1, 32, 33, 34, 35, 41, 42, 49, 50, 51, 52, 53, 54] # back
]
var legs_bab = [ 
	[30, 31, 47, 48, 49, 50, 51, 52, 53, 54, 55, 56, 57, 58, 88, 89, 90, 91, 92, 93, 94, 95, 98, 99, 100, 101, 116, 117], # front
	[0, 1, 2, 3, 5, 6, 59, 60, 61, 62, 64, 65, 66, 67, 71, 72, 102, 103, 104, 105, 106, 107] # back
]

var body_ext_dog = [ 49, 0, 12, 16, 20, 21, 22, 24, 36, 44, 45, 46, 43, 19, 40, 57, 58, 59, 60, 61, 62 ]
var body_ext_cat = [ 2, 3, 0, 1, 32, 33, 34, 35, 41, 42, 49, 50, 51, 52, 53, 54, 25, 26, 43, 44, 45, 46, 47, 48 ]
var body_ext_bab = [ 87, 0, 1, 2, 3, 4, 5, 6, 10, 11, 32, 33, 34, 59, 60, 61, 62, 64, 65, 66, 67, 70, 71, 72, 81, 87, 94, 95, 102, 103, 104, 105, 106, 107 ]

var face_ext_dog = [ 51, 53, 55, 56, 63, 64, 17, 41, 15, 39 ]
var face_ext_cat = [ 7, 30, 31, 37, 40, 57, 58, 59, 60, 61, 62, 29 ]
var face_ext_bab = [ 7, 84, 82, 83, 85, 86, 8, 9, 79, 80, 12, 13, 14, 15, 109, 110, 111, 112, 113, 114, 115 ]

var head_ext_dog = [ 52, 1, 2, 3, 4, 5, 6, 8, 14, 15, 17, 25, 26, 27, 28, 29, 30, 32, 38, 39, 41, 51, 53, 55, 56, 63, 64 ]
var head_ext_cat = [ 24, 4, 5, 7, 8, 9, 10, 11, 14, 15, 27, 28, 29, 30, 31, 37, 40, 55, 56, 57, 58, 59, 60, 61, 62 ]
var head_ext_bab = [ 7, 8, 9, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 35, 36, 37, 38, 39, 40, 41, 42, 43, 44, 45, 46, 63, 68, 69, 73, 74, 75, 76, 77, 78, 79, 80, 82, 83, 84, 85, 86, 96, 97, 108, 109, 110, 111, 112, 113, 114, 115 ]

var foot_ext_dog = [ 
	[ 12, 20, 21, 22 ],
	[ 13, 9, 10, 11 ],
	[ 36, 44, 45, 46 ],
	[ 37, 33, 34, 35 ]
]
var foot_ext_cat = [
	[ 22, 16, 17, 18 ],
	[ 23, 19, 20, 21 ],
	[ 41, 34, 49, 50, 51 ],
	[ 42, 35, 52, 53, 54 ]
]
var foot_ext_bab = [
	[ 88, 90, 92, 98, 100, 47, 49, 51, 53, 55, 57 ],
	[ 89, 91, 93, 99, 101, 48, 50, 52, 54, 56, 58 ],
	[ 59, 61, 66, 5, 2, 102, 104, 106 ],
	[ 60, 62, 67, 6, 3, 103, 105, 107 ]
]

var ear_ext_dog = { 4: [5, 6], 28: [29, 30] }
var ear_ext_cat = { 8: [9], 10: [11]  }
var ear_ext_bab = { 28: [16, 18, 20, 22, 24, 26], 29: [17, 19, 21, 23, 25, 27]}

var eyes_dog = {14: 8, 38: 32} # iris = eye
var eyes_cat = { 27: 14, 28: 15}
var eyes_bab = { 68: 35, 69: 36 }

var nose_dog = [17, 41, 55]
var nose_cat = [37]
var nose_bab = [84, 82, 83, 86, 85]

var eyebrow_bab = [37, 38, 39, 40, 41, 42] # excluding eyebrows 37 to 42 too

var tail_dog = [57, 58, 59, 60, 61, 62 ]
var tail_cat = [43, 44, 45, 46, 47, 48 ]
var tail_bab = []

var tongue_dog = [63, 64]
var tongue_cat = [55, 56]
var tongue_bab = [108]

var belly_cat = 2
var belly_dog = 48
var belly_bab = 4

var projection_standards = {
	"cat": [
		{"fixed_ball": 43, "project_ball": 44, "min_projection": 80, "max_projection": 120, "comment": "tail"},
		{"fixed_ball": 44, "project_ball": 45, "min_projection": 80, "max_projection": 120, "comment": "tail"},
		{"fixed_ball": 45, "project_ball": 46, "min_projection": 80, "max_projection": 120, "comment": "tail"},
		{"fixed_ball": 46, "project_ball": 47, "min_projection": 80, "max_projection": 120, "comment": "tail"},
		{"fixed_ball": 47, "project_ball": 48, "min_projection": 80, "max_projection": 120, "comment": "tail"}
	],
	"dog": [
		{"fixed_ball": 49, "project_ball": 57, "min_projection": 20, "max_projection": 80, "comment": "tail"},
		{"fixed_ball": 51, "project_ball": 64, "min_projection": 60, "max_projection": 80, "comment": "tail"},
		{"fixed_ball": 51, "project_ball": 77, "min_projection": 60, "max_projection": 130, "comment": "tail"},
		{"fixed_ball": 52, "project_ball": 63, "min_projection": 60, "max_projection": 130, "comment": "tail"},
		{"fixed_ball": 53, "project_ball": 63, "min_projection": 50, "max_projection": 70, "comment": "tail"},
		{"fixed_ball": 56, "project_ball": 63, "min_projection": 50, "max_projection": 70, "comment": "tail"},
		{"fixed_ball": 57, "project_ball": 58, "min_projection": 0, "max_projection": 100, "comment": "tail"},
		{"fixed_ball": 58, "project_ball": 59, "min_projection": 0, "max_projection": 100, "comment": "tail"},
		{"fixed_ball": 59, "project_ball": 60, "min_projection": 0, "max_projection": 100, "comment": "tail"},
		{"fixed_ball": 59, "project_ball": 94, "min_projection": 50, "max_projection": 70, "comment": "tail"},
		{"fixed_ball": 60, "project_ball": 61, "min_projection": 0, "max_projection": 100, "comment": "tail"},
		{"fixed_ball": 61, "project_ball": 62, "min_projection": 0, "max_projection": 100, "comment": "tail"},
		{"fixed_ball": 63, "project_ball": 64, "min_projection": 50, "max_projection": 100, "comment": "tail"},
		{"fixed_ball": 64, "project_ball": 77, "min_projection": 50, "max_projection": 100, "comment": "tail"}
	],
	"bab": [
		{"fixed_ball": 4, "project_ball": 63, "min_projection": 80, "max_projection": 100, "comment": "bellyhead"}
	]
}

var symmetry_mode_hide_balls_cat = [0, 4, 8, 9, 12, 14, 16, 17, 18, 22, 25, 27, 30, 32, 34, 38, 41, 49, 50, 51, 57, 58, 59, 63]
var symmetry_mode_hide_balls_dog = []
var symmetry_mode_hide_balls_bab = []

var symmetry_mode_right_balls_cat = [1, 5, 10, 11, 13, 15, 19, 20, 21, 23, 26, 28, 31, 33, 35, 39, 42, 52, 53, 54, 60, 61, 62, 64]
var symmetry_mode_right_balls_dog = []
var symmetry_mode_right_balls_bab = []

var species
var max_base_ball_num

enum Species { CAT = 1, DOG = 2, BABY = 3 }

func _ready():
	for n in range(0, 24):
		symmetry_mode_hide_balls_dog.append(n)
	for n in range(24, 48):
		symmetry_mode_right_balls_dog.append(n)
	
	# bodyarea values
	# 8 = head-related
	# 1 = body-related (safe fallback and general default)

	# [0] Z stuff  
	# [1] Body Balls  
	# [2] Right Leg Balls  
	# [3] Left Leg Balls  
	# [4] Right Hand Balls  
	# [5] Left Hand Balls  
	# [6] Right Foot Balls  
	# [7] Left Foot Balls  
	# [8] Head Balls  
	# [9] Right Arm Balls  
	# [10] Left Arm Balls  
	# [11] Right Ear Balls  
	# [12] Left Ear Balls  
	# [13] Tail Balls  
	# [14] Whisker Balls  
	# [15] Jowlz Balls  
	# [16] Tongue stuff  
	# [17] Right Brow Balls  
	# [18] Left Brow Balls  
	# [19] Extra Balls  
	# [20] Extra Head Balls 

func build_bodyarea_map():
	bodyarea_map.clear()
	if species == Species.DOG:
		_build_bodyarea_map_dog()
	elif species == Species.CAT:
		_build_bodyarea_map_cat()
	elif species == Species.BABY:
		_build_bodyarea_map_baby()

	if typeof(max_base_ball_num) == TYPE_INT:
		for i in range(0, max_base_ball_num + 1):
			if not bodyarea_map.has(i):
				bodyarea_map[i] = 1

func _build_bodyarea_map_dog():
	for b in head_ext_dog + face_ext_dog + tongue_dog:
		bodyarea_map[b] = 8
	for b in eyes_dog.keys() + eyes_dog.values() + nose_dog:
		bodyarea_map[b] = 8
	for base in ear_ext_dog:
		bodyarea_map[base] = 8
		for b in ear_ext_dog[base]:
			bodyarea_map[b] = 8
	for b in tail_dog + body_ext_dog:
		bodyarea_map[b] = 1
	for group in legs_dog + foot_ext_dog:
		for b in group:
			bodyarea_map[b] = 1
	for b in symmetry_mode_right_balls_dog + symmetry_mode_hide_balls_dog:
		if not bodyarea_map.has(b):
			bodyarea_map[b] = 1

func _build_bodyarea_map_cat():
	for b in head_ext_cat + face_ext_cat + tongue_cat:
		bodyarea_map[b] = 8
	for b in eyes_cat.keys() + eyes_cat.values() + nose_cat:
		bodyarea_map[b] = 8
	for base in ear_ext_cat:
		bodyarea_map[base] = 8
		for b in ear_ext_cat[base]:
			bodyarea_map[b] = 8
	for b in tail_cat + body_ext_cat:
		bodyarea_map[b] = 1
	for group in legs_cat + foot_ext_cat:
		for b in group:
			bodyarea_map[b] = 1
	for b in symmetry_mode_right_balls_cat + symmetry_mode_hide_balls_cat:
		if not bodyarea_map.has(b):
			bodyarea_map[b] = 1

func _build_bodyarea_map_baby():
	for b in head_ext_bab + face_ext_bab + tongue_bab:
		bodyarea_map[b] = 8
	for b in eyes_bab.keys() + eyes_bab.values() + nose_bab:
		bodyarea_map[b] = 8
	for base in ear_ext_bab:
		bodyarea_map[base] = 8
		for b in ear_ext_bab[base]:
			bodyarea_map[b] = 8
	for b in tail_bab + body_ext_bab:
		bodyarea_map[b] = 1
	for group in legs_bab + foot_ext_bab:
		for b in group:
			bodyarea_map[b] = 1
	for b in symmetry_mode_right_balls_bab + symmetry_mode_hide_balls_bab:
		if not bodyarea_map.has(b):
			bodyarea_map[b] = 1

# // --- For CAT ---

var cat_body_part_symmetry = {
    # // Symmetrical body parts for the Cat's head.
    "Head": {
        "Eyes": { "left": [14, 27], "right": [15, 28] }, 
        "Ears": { "left": [8, 9], "right": [10, 11] }, 
        "Cheeks_Jowls": { "left": [4, 30], "right": [5, 31] },
        "Whiskers": { "left": [57, 58, 59], "right": [60, 61, 62] }, 
        "Head_Top_Sides": { "left": [87, 88], "right": [89] }
    },
    # // Symmetrical body parts for the Cat's torso.
    "Torso": {
        "Shoulders": { "left": [38], "right": [39] },
        "Hips": { "left": [25], "right": [26] }
    },
    # // Symmetrical body parts for the Cat's front paws/arms.
    "FrontPaws": {
        "Arms": { "left": [12, 63], "right": [13, 64] }, 
        "Hands": { "left": [22], "right": [23] },
        "Fingers_Knuckles": { "left": [16, 17, 18, 34], "right": [19, 20, 21, 35] }
    },
    # // Symmetrical body parts for the Cat's back paws/legs.
    "BackPaws": {
        "Legs": { "left": [32, 0], "right": [33, 1] }, 
        "Feet": { "left": [41], "right": [42] }, 
        "Toes": { "left": [49, 50, 51], "right": [52, 53, 54] }
    }
};

# // --- For DOG ---

var dog_body_part_symmetry = {
    # // Symmetrical body parts for the Dog's head.
    "Head": {
        "Eyes": { "left": [8, 14], "right": [32, 38] }, 
        "Ears": { "left": [4, 5, 6], "right": [28, 29, 30] }, 
        "Eyebrows": { "left": [1, 2, 3], "right": [25, 26, 27] },
        "Jowls": { "left": [15], "right": [39] },
        "Nostrils": { "left": [17], "right": [41] }
    },
    # // Symmetrical body parts for the Dog's torso.
    "Torso": {
        "Shoulders": { "left": [18], "right": [42] },
        "Hips": { "left": [19], "right": [43] }
    },
    # // Symmetrical body parts for the Dog's front paws/arms.
    "FrontPaws": {
        "Arms": { "left": [7, 23], "right": [31, 47] }, 
        "Hands": { "left": [13], "right": [37] },
        "Fingers": { "left": [9, 10, 11], "right": [33, 34, 35] }
    },
    # // Symmetrical body parts for the Dog's back paws/legs.
    "BackPaws": {
        "Legs": { "left": [16, 0], "right": [40, 24] },
        "Feet": { "left": [12], "right": [36] },
        "Toes": { "left": [20, 21, 22], "right": [44, 45, 46] }
    }
};

# // --- For BABY ---

var baby_body_part_symmetry = {
    # // Symmetrical body parts for the Baby's head.
    "Head": {
        "Eyes": { "left": [35, 68], "right": [36, 69] }, 
        "Eyebrows": { "left": [37, 39, 41, 43, 45], "right": [38, 40, 42, 44, 46] }, 
        "Ears": { "left": [16, 18, 20, 22, 24, 26, 28], "right": [17, 19, 21, 23, 25, 27, 29] },
        "Face_Sides": { "left": [8, 96], "right": [9, 97] }, 
        "Mouth": { "left": [79, 85], "right": [80, 86] }
    },
    # // Symmetrical body parts for the Baby's torso.
    "Torso": {
        "Chest": { "left": [10], "right": [11] },
        "Shoulders": { "left": [94], "right": [95] },
        "Hips": { "left": [66], "right": [67] }
    },
    # // Symmetrical body parts for the Baby's hands.
    "Hands": {
        "Arms": { "left": [30, 116], "right": [31, 117] },
        "Palms": { "left": [88, 90, 92], "right": [89, 91, 93] },
        "Fingers_Thumbs": { "left": [47, 49, 51, 53, 55, 57, 98, 100], "right": [48, 50, 52, 54, 56, 58, 99, 101] }
    },
    # // Symmetrical body parts for the Baby's feet.
    "Feet": {
        "Legs": { "left": [71, 0], "right": [72, 1] },
        "Soles": { "left": [2, 64], "right": [3, 65] },
        "Toes": { "left": [5, 102, 104, 106], "right": [6, 103, 105, 107] }
    }
};

func get_mirrored_ball(ball_no, symmetry_dict):
	for main_part in symmetry_dict:
		for sub_part in symmetry_dict[main_part]:
			var part_info = symmetry_dict[main_part][sub_part]
			if part_info.has("left") and part_info.has("right"):
				if ball_no in part_info.left:
					var index = part_info.left.find(ball_no)
					if index != -1 and index < part_info.right.size():
						return part_info.right[index]
				elif ball_no in part_info.right:
					var index = part_info.right.find(ball_no)
					if index != -1 and index < part_info.left.size():
						return part_info.left[index]
	return -1 # No mirror found