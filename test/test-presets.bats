setup() {
	source ./src/test-presets.sh
}


# = = = = = = = = = = =
#    Presets Storage
# = = = = = = = = = = =

@test "should add to the storage: add_preset__tp()" {
	# Case 1
	add_preset__tp "ABC" "123"
	add_preset__tp "ABC" ""
	add_preset__tp "another_one" "123ASD456"
	[ "${#PRESET_KEYS__TP[@]}" -eq 3 ]
	[ "${#PRESET_VALUES__TP[@]}" -eq 3 ]

	# Case 2
	run add_preset__tp "Invalid name" "123"
	[ "$status" -eq 1 ]
}

@test "should clear the storage: clear_presets__tp()" {
	add_preset__tp "ABC" "123"
	add_preset__tp "ABC" ""
	add_preset__tp "another_one" "123ASD456"

	clear_presets__tp
	[ "${#PRESET_KEYS__TP[@]}" -eq 0 ]
	[ "${#PRESET_VALUES__TP[@]}" -eq 0 ]
}

@test "should return correct pair: get_preset_pair__tp()" {
	# Case 1
	local pair=""

	add_preset__tp "A" "VALUE"
	add_preset__tp "B" ""
	add_preset__tp "C" '"/\Complex/`\Value$$""`'
	add_preset__tp "D" "WITH"$'\n'"NEWLINE"

	pair="$(get_preset_pair__tp 1)"
	[ "$pair" == 'A="VALUE"' ]

	pair="$(get_preset_pair__tp 2)"
	[ "$pair" == 'B=""' ]

	# pair="$(get_preset_pair__tp 3)"
	# [ "$pair" == 'to-do' ]

	pair="$(get_preset_pair__tp 4)"
	[ "$pair" == 'D="WITH'$'\n''NEWLINE"' ]


	# Case 2
	run get_preset_pair__tp 0
	[ "$status" -eq 1 ]

	run get_preset_pair__tp -1
	[ "$status" -eq 1 ]

	run add_preset__tp "A" "" && get_preset_pair__tp 1
	[ "$status" -eq 0 ]

	run add_preset__tp "A" "" && get_preset_pair__tp 2
	[ "$status" -eq 2 ]
}