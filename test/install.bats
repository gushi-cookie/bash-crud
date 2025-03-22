#!/usr/bin/env bats

setup() {
	BC_TEST__TEST_ENVIRONMENT="true"

	BC_TMP_DIR="/tmp/bash-crud-bats"
	BC_DRAFT="${BC_TMP_DIR}/draft"
	BC_GITHUB="https://github.com/gushi-cookie/bash-crud"

	mkdir -p "$BC_TMP_DIR"
	touch "$BC_DRAFT"

	source ./src/install.sh
}

teardown() {
	rm -rf "${BC_TMP_DIR}/*" "${BC_TMP_DIR}/.*"
}


# = = = = = = = = = = = = =
#     Common Utilities
# = = = = = = = = = = = = =

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

@test "should check if a list contains an item: includes_by_delimiter()" {
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

@test "should exit with a success: get_architecture_for_jq()" {
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

		printf "OK\n" >&3
	done

	unset BASH_CRUD_DOWNLOADER
}


# = = = = = = = = = = = = = = = =
#    Managing: Http requests
# = = = = = = = = = = = = = = = =

@test "should return correct resources: get_resource_url()" {
	local -a resources=("gawk" "bash-crud-script" "install" "jq")

	# Case 1
	run get_resource_url "Unknown_resource"
	[ "$status" -eq 1 ]

	# Case 2
	export BASH_CRUD_DOWNLOADER="curl"
	printf "   Curl:\n" >&3
	for resource in "${resources[@]}"; do
		printf %s "   - Item '${resource}': " >&3
		run get_resource_url "$resource"
		[ "$status" -eq 0 ]
		printf "OK\n" >&3
	done

	# Case 3
	printf "   Wget:\n" >&3
	export BASH_CRUD_DOWNLOADER="wget"
	for resource in "${resources[@]}"; do
		run get_resource_url "$resource"
		[ "$status" -eq 0 ]
	done

	unset BASH_CRUD_DOWNLOADER
}

@test "should download files: download_file()" {
	local file="install.bats"
	local url="${BC_GITHUB}/test/${file}"
	local tag="v0.2.0"
	local tag_checksum="TO-DO"

	for cmd in "curl" "wget"; do
		export BASH_CRUD_DOWNLOADER="$cmd"

		# Case 1: into a directory
		run download_file "${BC_TMP_DIR}/" "$url"
		[ "$status" -eq 0 ]
		[[ -s "${BC_TMP_DIR}/${file}" ]]

		# Case 2: into a file
		run download_file "${BC_TMP_DIR}/test_file" "$url"
		[ "$status" -eq 0 ]
		[[ "${BC_TMP_DIR}/${file}" -ef "${BC_TMP_DIR}/test_file" ]]
		rm "${BC_TMP_DIR}/${file}" "${BC_TMP_DIR}/test_file"

		# Case 3: with query parameters
		run download_file "${BC_TMP_DIR}/test_file" "$url" "ref=${tag}"
		[ "$status" -eq 0 ]
		[ "$(sha256sum "${BC_TMP_DIR}/test_file")" == "$tag_checksum" ]
		rm "${BC_TMP_DIR}/test_file"
	done

	unset BASH_CRUD_DOWNLOADER
}

@test "should make http GET requests: make_get_request()" {
	local url="${BC_GITHUB}/test/install.bats"
	local tag="v0.2.0"
	local tag_checksum="TO-DO"
	local checksum=""

	for cmd in "curl" "wget"; do
		export BASH_CRUD_DOWNLOADER="$cmd"

		# Case 1: primitive request
		run make_get_request "$url"
		[ "$status" -eq 0 ]

		# Case 2: with query parameters
		run make_get_request "$url" "ref=${tag}"
		[ "$status" -eq 0 ]
		checksum="$(printf %s "$output" | sha256sum | cut -d ' ' -f 1)"
		[ "$checksum" == "$tag_checksum" ]
	done

	unset BASH_CRUD_DOWNLOADER
}

@test "should resolve file links: get_file_links_from_github_repo()" {
	local username="gushi-cookie"
	local repo_name="bash-crud"
	local tag="v0.2.0"
	local path="src/gawk"

	# Case 1: without a tag
	run get_file_links_from_github_repo "$username" "$repo_name" "" ""
	[ "$status" -eq 0 ]
	[ "$(printf %s "$output" | wc -l)" -gt 1 ]

	# Case 2: with a tag
	run get_file_links_from_github_repo "$username" "$repo_name" "$tag" "$path"
	[ "$status" -eq 0 ]
	[ "$(printf %s "$output" | wc -l)" -eq 4 ]
}


# = = = = = = = = = = = = = = = = = = = =
#     Managing: Environments & Paths
# = = = = = = = = = = = = = = = = = = = =

@test "should prepare a temporary directory: establish_temp_path()" {
	run establish_temp_path
	[ "$status" -eq 0 ]
	[ -d "$output" ]
	[[ "$PATH" =~ "$output" ]]
}

@test "should return the path: establish_gawk_path()" {
	# Case 1
	run establish_gawk_path
	[[ "$status" -eq 0 && -n "$output" ]]

	# Case 2
	export AWKPATH="/some/random/path"
	run establish_gawk_path
	[ "$status" -eq 0 ]
	[ "$output" == "$AWKPATH" ]
	unset AWKPATH
}

@test "should return the path: establish_bin_path()" {
	run establish_bin_path
	[ "$status" -eq 0 ]
	[ -n "$output" ]
}


# = = = = = = = = = = =
#   The Main Section
# = = = = = = = = = = =

@test "should install: install()" {
	:
	# to-do
}