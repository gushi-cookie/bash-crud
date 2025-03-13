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

@test "should print in STDERR: print_error()" {
	local message="ERROR MESSAGE TO PRINT"

	print_error "$message" 2> "$BC_DRAFT"
	[ "$?" -eq 0 ]
	[ "$(cat "$BC_DRAFT")" == "$message" ]
}

@test "should print in STDERR and exit with 1: print_error_and_exit()" {
	local message="ERROR MESSAGE TO PRINT"

	run print_error_and_exit "$message"
	[ "$status" -eq 1 ]

	print_error_and_exit "$message" 2> "$BC_DRAFT" || true
	[ "$(cat "$BC_DRAFT")" == "$message" ]
}

@test "should return a valid semver tag starting from 'v' character: get_current_version_tag()" {
	SEMVER_REGEX="^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(\-[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?(\+[0-9A-Za-z-]+(\.[0-9A-Za-z-]+)*)?$"
	run get_current_version_tag
	[[ "$output" =~ $SEMVER_REGEX ]]
}

@test "should check if a command is available: has_cmd()" {
	run has_cmd "bash"
	[ "$status" -eq 0 ]

	run has_cmd "BC-not-even-a-command"
	[ "$status" -eq 1 ]
}

@test "should download files with 'curl' and 'wget': download_file()" {

}