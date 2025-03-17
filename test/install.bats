#!/usr/bin/env bats

setup() {
	BC_TMP_DIR="/tmp/bash-crud-bats"
	BC_DRAFT="${BC_TMP_DIR}/draft"

	mkdir -p "$BC_TMP_DIR"
	touch "$BC_DRAFT"

	source ./src/install.sh
}

teardown() {
	rm -rf "${BC_TMP_DIR}/*" "${BC_TMP_DIR}/.*"
}


# = = = = = = = = = =
#     Utilities
# = = = = = = = = = =

@test "should print in STDERR: print_error()" {
	local message="ERROR MESSAGE TO PRINT"

	print_error "$message" 2> "$BC_DRAFT"
	[ $? -eq 0 ]
	[ "$(cat "$BC_DRAFT")" == "$message" ]
}

@test "should return a valid semver tag starting with 'v' character: get_current_version_tag()" {
	local SEMVER_REGEX="^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"

	run get_current_version_tag
	[[ "$status" -eq 0 ]]
	[[ "$output" =~ $SEMVER_REGEX ]]
}

@test "should check if a string is included in a list: includes_by_delimiter()" {
	# Case 1
	local list="A B C D EFG"

	run includes_by_delimiter "$list" " " "A"
	[ "$status" -eq 0 ]

	run includes_by_delimiter "$list" " " "H"
	[ "$status" -eq 1 ]

	run includes_by_delimiter "$list" " " "G"
	[ "$status" -eq 1 ]

	run includes_by_delimiter "$list" " " "EFG"
	[ "$status" -eq 0 ]


	# Case 2
	list="A*B*C*D*EFG"

	run includes_by_delimiter "$list" "*" "A"
	[ "$status" -eq 0 ]

	run includes_by_delimiter "$list" "*" "H"
	[ "$status" -eq 1 ]

	run includes_by_delimiter "$list" "*" "G"
	[ "$status" -eq 1 ]

	run includes_by_delimiter "$list" "*" "EFG"
	[ "$status" -eq 0 ]


	# Case 3
	run includes_by_delimiter "A" " " "A"
	[ "$status" -eq 0 ]

	run includes_by_delimiter "A" "*" "A"
	[ "$status" -eq 0 ]

	run includes_by_delimiter "" " " "A"
	[ "$status" -eq 1 ]

	run includes_by_delimiter "" " " ""
	[ "$status" -eq 0 ]

	run includes_by_delimiter "A B C*D E F" "*" "D E F"
	[ "$status" -eq 0 ]
}

@test "should check if a command exists: has_cmd()" {
	local fake_cmd="BC-not-even-a-command"


	# Case 1
	run has_cmd "bash"
	[ "$status" -eq 0 ]

	run has_cmd "$fake_cmd"
	[ "$status" -eq 1 ]


	# Case 2 - missing on purpose
	export BC_TEST__MISS_COMMAND="bash"
	run has_cmd "bash"
	[ "$status" -eq 1 ]
	unset BC_TEST__MISS_COMMAND

	export BC_TEST__MISS_COMMAND="ls cd"
	run has_cmd "ls"
	[ "$status" -eq 1 ]
	run has_cmd "cd"
	[ "$status" -eq 1 ]
	unset BC_TEST__MISS_COMMAND


	# Case 3 - passing on purpose
	export BC_TEST__PASS_COMMAND="$fake_cmd"
	run has_cmd "$fake_cmd"
	[ "$status" -eq 0 ]
	unset BC_TEST__PASS_COMMAND

	export BC_TEST__PASS_COMMAND="${fake_cmd}-A ${fake_cmd}-B"
	run has_cmd "${fake_cmd}-A"
	[ "$status" -eq 0 ]
	run has_cmd "${fake_cmd}-B"
	[ "$status" -eq 0 ]
	unset BC_TEST__PASS_COMMAND
}


# = = = = = = = = = = = = = = = =
#    Managing: Required tools
# = = = = = = = = = = = = = = = =

@test "should exit successfully: get_architecture_for_jq()" {
	run get_architecture_for_jq
	[ "$status" -eq 0 ]
}

@test "should install the tool: establish_jq()" {
	# Case 1
	export BC_TEST__PASS_COMMAND="jq"
	run establish_jq
	[ "$status" -eq 0 ]
	unset BC_TEST__PASS_COMMAND


	# Case 2
	export BC_TEST__MISS_COMMAND="jq"

	local jq_path; jq_path="$(establish_temp_path)/jq"
	[ $? -eq 0 ]

	run establish_jq
	[ "$status" -eq 0 ]
	[[ -f "${jq_path}" && -x "${jq_path}" ]]

	run eval "${jq_path} --help"
	[ "$status" -eq 0 ]

	unset BC_TEST__MISS_COMMAND
}

@test "should return a proper downloader command: get_downloader()" {
	local -a commands=("curl" "wget")

	for cmd in "${commands[@]}"; do
		printf %s "   - Item '${cmd}': " >&3

		export BASH_CRUD_DOWNLOADER="$cmd"

		export BC_TEST__PASS_COMMAND="$cmd"
		run get_downloader
		[[ "$status" -eq 0 && "$output" == "$cmd" ]]
		unset BC_TEST__PASS_COMMAND

		export BC_TEST__MISS_COMMAND="${commands[@]}"
		run get_downloader
		[ "$status" -eq 1 ]
		unset BC_TEST__MISS_COMMAND

		printf "%s\n" "OK" >&3
	done

	unset BASH_CRUD_DOWNLOADER
}


# = = = = = = = = = = = =
#    Networking: Http
# = = = = = = = = = = = =

@test "should download files with 'curl' and 'wget': download_file()" {
	:
}