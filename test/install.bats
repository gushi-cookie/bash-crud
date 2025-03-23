#!/usr/bin/env bats

setup() {
	# Preparing session files.
	BC_TMP_DIR="/tmp/bash-crud-bats"
	BC_DRAFT="${BC_TMP_DIR}/draft"
	mkdir -p "$BC_TMP_DIR"
	touch "$BC_DRAFT"

	# URLs for testing.
	BC_GITHUB_MAIN="https://raw.githubusercontent.com/gushi-cookie/bash-crud/refs/heads/main"
	BC_TARGET_TAG="v0.2.0"
	BC_GITHUB_TAGGED="https://raw.githubusercontent.com/gushi-cookie/bash-crud/refs/tags/${BC_TARGET_TAG}"

	# Importing the script for testing.
	BC_TEST__TEST_ENVIRONMENT="true"
	source ./src/install.sh
}

teardown() {
	# Removing files of the current session.
	rm -rf "${BC_TMP_DIR}/*" "${BC_TMP_DIR}/.*"
}


# = = = = = = = = = = = = =
#     Common Utilities
# = = = = = = = = = = = = =

@test "should print to STDERR: print_error()" {
	local message="ERROR MESSAGE TO PRINT"

	print_error "$message" 2> "$BC_DRAFT"
	[ "$(cat "$BC_DRAFT")" == "$message" ]
}

@test "should return a valid semver tag starting with the 'v' character: get_current_version_tag()" {
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

	local jq_path
	jq_path="$(establish_temp_path)/jq"

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
	printf "     With curl:\n" >&3
	for resource in "${resources[@]}"; do
		printf %s "     - Item '${resource}': " >&3
		run get_resource_url "$resource"
		[ "$status" -eq 0 ]
		printf "OK\n" >&3
	done

	# Case 3
	printf "     With wget:\n" >&3
	export BASH_CRUD_DOWNLOADER="wget"
	for resource in "${resources[@]}"; do
		printf %s "     - Item '${resource}': " >&3
		run get_resource_url "$resource"
		[ "$status" -eq 0 ]
		printf "OK\n" >&3
	done

	unset BASH_CRUD_DOWNLOADER
}

@test "should download files: download_file()" {
	local file="install.bats"
	local tagged_file_checksum="f72fb63c1ae61e9cf6782315470566095950a993a56948c407312c409d322395"

	for cmd in "curl" "wget"; do
		printf "   - Item '%s': " "$cmd" >&3
		export BASH_CRUD_DOWNLOADER="$cmd"

		# Case 1: into a directory
		run download_file "${BC_TMP_DIR}/" "${BC_GITHUB_MAIN}/test/${file}"
		[ "$status" -eq 0 ]
		[ -s "${BC_TMP_DIR}/${file}" ]

		# Case 2: into a file
		run download_file "${BC_TMP_DIR}/test_file" "${BC_GITHUB_MAIN}/test/${file}"
		[ "$status" -eq 0 ]
		cmp -s "${BC_TMP_DIR}/${file}" "${BC_TMP_DIR}/test_file"
		rm "${BC_TMP_DIR}/${file}" "${BC_TMP_DIR}/test_file"

		# Case 3: with query parameters
		run download_file "${BC_TMP_DIR}/test_file" "${BC_GITHUB_TAGGED}/test/${file}"
		[ "$status" -eq 0 ]
		[ "$tagged_file_checksum" == "$(sha256sum "${BC_TMP_DIR}/test_file" | cut -d ' ' -f 1)" ]
		rm "${BC_TMP_DIR}/test_file"

		printf "OK\n" >&3
	done

	unset BASH_CRUD_DOWNLOADER
}

@test "should make HTTP GET requests: make_get_request()" {
	local file="install.bats"
	local tagged_file_checksum="f72fb63c1ae61e9cf6782315470566095950a993a56948c407312c409d322395"

	for cmd in "curl" "wget"; do
		printf "   - Item '%s': " "$cmd" >&3
		export BASH_CRUD_DOWNLOADER="$cmd"

		# Case 1: regular request
		run make_get_request "${BC_GITHUB_MAIN}/test/${file}"
		[ "$status" -eq 0 ]

		# Case 2: with query parameters
		run make_get_request "${BC_GITHUB_TAGGED}/test/${file}"
		[ "$status" -eq 0 ]
		[ "$tagged_file_checksum" == "$(printf %s "$output" | sha256sum | cut -d ' ' -f 1)" ]

		printf "OK\n" >&3
	done

	unset BASH_CRUD_DOWNLOADER
}

@test "should resolve file links: get_file_links_from_github_repo()" {
	# Note: run helper strips all trailing newline characters.
	local username="gushi-cookie"
	local repo_name="bash-crud"
	local path="src/gawk"

	# Case 1: without a tag
	run get_file_links_from_github_repo "$username" "$repo_name" "" ""
	[ "$status" -eq 0 ]
	[ "$(printf "%s\n" "$output" | wc -l)" -ge 2 ]

	# Case 2: with a tag
	run get_file_links_from_github_repo "$username" "$repo_name" "${BC_TARGET_TAG}" "$path"
	[ "$status" -eq 0 ]
	[ "$(printf "%s\n" "$output" | wc -l)" -eq 4 ]
}


# = = = = = = = = = = = = = = = = = = = =
#     Managing: Environments & Paths
# = = = = = = = = = = = = = = = = = = = =

@test "should append new paths: append_path_variable()" {
	local original_path="$PATH"
	local path1="/i/love/bash-crud"
	local path2="/another/random/path"

	# Case 1: 1,2
	append_path_variable "${path1} ${path2}"
	[ "$PATH" == "${original_path}:${path1}:${path2}" ]
	PATH="$original_path"

	# Case 2: 1,1,1
	append_path_variable "${path1} ${path1} ${path1}"
	[ "$PATH" == "${original_path}:${path1}" ]
	PATH="$original_path"

	# Case 3: none
	append_path_variable ""
	[ "$PATH" == "${original_path}" ]

	# Case 4: 1,1,2,1,1,2,2
	append_path_variable "${path1} ${path1} ${path2} ${path1} ${path1} ${path2} ${path2}"
	[ "$PATH" == "${original_path}:${path1}:${path2}" ]
	PATH="$original_path"
}

@test "should prepare a temporary directory: establish_temp_path()" {
	run establish_temp_path
	[ -d "$output" ]
}

@test "should return a valid path: establish_gawk_path()" {
	# Case 1
	run establish_gawk_path
	[ "$status" -eq 0 ]
	[ -n "$output" ]

	# Case 2
	export AWKPATH="${BC_TMP_DIR}/gawk"
	run establish_gawk_path
	[ "$status" -eq 0 ]
	[ "$output" == "${AWKPATH}/bash-crud" ]
	unset AWKPATH
}

@test "should return a valid path: establish_bin_path()" {
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