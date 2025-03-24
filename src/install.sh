#!/usr/bin/env bash

# = = = = = = = = = = = =
# Supported environments
# = = = = = = = = = = = =
# AWKPATH
# - A path for installing gawk programs.
# - Syntax rules: same as for PATH.
#
# BASH_CRUD_DOWNLOADER
# - A network command name for making http
#   requests.
# - Valid values: ["curl", "wget"]. Default: "curl".
#
# BASH_CRUD_INSTALL_VERSION
# - One of the valid version tags of this repository.
#   Represents the version to install.
# - Default: 'get_current_version_tag()'
#
# BC_TEST__PASS_COMMAND
# - A space-separated list of command names that
#   should be treated as existing commands for
#   testing purposes.
#
# BC_TEST__MISS_COMMAND
# - A space-separated list of command names that
#   should be treated as missing commands for testing
#   purposes.
#
# BC_TEST__TEST_ENVIRONMENT
# - Indicates whether the script is started for testing
#   purposes.
# - Valid values: unset for false, any value for true.


# = = = = = = = = = = = = =
#     Common Utilities
# = = = = = = = = = = = = =

print_error() {
	# [logger]
	# Print an error message to the stderr stream.
	# Arguments:
	#   A list of arguments that will be concatenated
	#   into a single string and then printed.

	printf "%s\\n" "$*" >&2
}

get_current_version_tag() {
	# [capturable]
	# Get a version tag of the
	# currently supported version.
	# Returns:
	#   The version tag.

	printf "v0.2.0"
}

includes_by_delimiter() {
	# [binary]
	# Check if a strictly delimited list of values
	# contains an item. The list is represented by
	# a string value.
	# Arguments:
	#   $1 - The list of values.
	#   $2 - The delimiter.
	#   $3 - The value to check.
	# Returns:
	#   0 - If the item is included.
	#   1 - If the item is not included.

	[[ " $(echo -n "$1" | tr "$2" " ") " == *" ${3} "* ]]
	return $?
}

has_cmd() {
	# [binary]
	# Check if a command is available on the current system.
	# Arguments:
	# 	$1 - The name of the command to check.
	# Returns:
	# 	0 - The command exists.
	# 	1 - The command does not exist.

	if includes_by_delimiter "${BC_TEST__PASS_COMMAND:-}" " " "$1"; then
		return 0
	elif includes_by_delimiter "${BC_TEST__MISS_COMMAND:-}" " " "$1"; then
		return 1
	fi

	type "$1" > /dev/null 2>&1
}


# = = = = = = = = = = = = = = = =
#    Managing: Required tools
# = = = = = = = = = = = = = = = =

get_architecture_for_jq() {
	# [capturable]
	# Get an architecture suffix for the jqlang/jq tool,
	# based on its ci.yml file and the current machine's
	# architecture.
	# Returns:
	#   The architecture suffix supported by the 'jq' tool.

	case "$(uname -m)" in
				 'x86_64') printf 'amd64';;
		'i686'|'i386') printf 'i386';;
				'aarch64') printf 'arm64';;
					's390x') printf 's390x';;
				'riscv64') printf 'riscv64';;
								*) print_error "Architecture '$(uname -m)' for 'jq' tool is not supported."; return 1;;
	esac
}

establish_jq() {
	# [control]
	# Install the 'jq' tool if it's not present on the system.

	if has_cmd "jq"; then return 0; fi
	printf "Command 'jq' not found. Downloading it for the current session..\n"

	local temp_path; temp_path="$(establish_temp_path)"
	[ $? -ne 0 ] && return 1

	local url; url="$(get_resource_url "jq")"
	[ $? -ne 0 ] && return 1

	download_file "$temp_path/jq" "$url"
	[ $? -ne 0 ] && return 1

	chmod 755 "$temp_path/jq"
	[ $? -ne 0 ] && return 1 || return 0
}

get_downloader() {
	# [capturable]
	# Get the name of a command supported by the
	# script for making network/http requests.
	# Returns:
	# 	The command name.

	local -a commands=("curl" "wget")

	for cmd in "${commands[@]}"; do
		if [ "${BASH_CRUD_DOWNLOADER:-}" == "$cmd" ]; then
			if has_cmd "$cmd"; then printf %s "$cmd"; return 0; fi
			print_error "Selected downloader command '$cmd' not found on the system."
			return 1
		fi
	done

	if [ -n "${BASH_CRUD_DOWNLOADER:-}" ]; then
		print_error "Selected downloader command '$BASH_CRUD_DOWNLOADER' not recognized."
		return 1
	fi

	for cmd in "${commands[@]}"; do
		if has_cmd "$cmd"; then printf %s "$cmd"; return 0; fi
	done

	print_error "Neither 'curl' nor 'wget' commands were found."
	return 1
}


# = = = = = = = = = = = = = = = =
#    Managing: Http requests
# = = = = = = = = = = = = = = = =

get_resource_url() {
	# [capturable]

	local resource="$1"
	local username="gushi-cookie"
	local repo_name="bash-crud"
	local jq_release_tag="jq-1.7.1"

	local version_tag
	version_tag="${BASH_CRUD_INSTALL_VERSION:-$(get_current_version_tag)}"
	[ $? -ne 0 ] && return 1

	if [ "$resource" == "gawk" ]; then
		get_file_links_from_github_repo "$username" "$repo_name" "$version_tag" "src/gawk"
		[ $? -ne 0 ] && return 1 || return 0
	elif [ "$resource" == "bash-crud-script" ]; then
		printf %s "https://raw.githubusercontent.com/${username}/${repo_name}/${version_tag}/scripts/bash-crud.sh"
	elif [ "$resource" == "install" ]; then
		printf %s "https://raw.githubusercontent.com/${username}/${repo_name}/${version_tag}/scripts/install.sh"
	elif [ "$resource" == "jq" ]; then
		local machine; machine="$(get_architecture_for_jq)"
		[ $? -ne 0 ] && return 1
		printf %s "https://github.com/jqlang/jq/releases/download/${jq_release_tag}/jq-linux-${machine}"
	else
		print_error "Couldn't find a download link for resource type '${resource}'."
		return 1
	fi
}

download_file() {
	# [control]
	# Download a file using one of the supported network commands.
	# Query parameters may be passed as additional arguments.
	# Values of query parameters are encoded automatically.
	# Arguments:
	# 	$1 - The output path to a file or directory. If the path
	#        ends with '/' sign, it is treated as a directory.
	# 	$2 - The URL of the request.
	#		$Q - The list of query parameters for the request.
	# Examples:
	#   download_file /dev/null/my_file "https..com" "req=5" "delete=yes" "please=sir"
	#   download_file search.html "https://google.com"
	#   download_file ~/output_dir/ "https://api.github.com/.."

	local downloader; downloader="$(get_downloader)"
	[ $? -ne 0 ] && return 1

	local outpath="$1"
	local url="$2"
	shift 2

	[[ "$outpath" =~ /$ ]]
	local output_to_dir=$?

	local query_params=""
	while [[ $# -gt 0 ]]; do
		local key="${1%%=*}"
		local value="${1#*=}"
		shift

		value="$(jq -nr --arg val "$value" '$val | @uri')"
		[ $? -ne 0 ] && return 1

		query_params+="&${key}=${value}"
	done
	if [ -n "$query_params" ]; then
		query_params="${query_params:1}"
		url="${url}?${query_params}"
	fi

  if [ "$downloader" == "curl" ]; then
		if [ "$output_to_dir" -eq 0 ]; then
			curl -qf --compressed --progress-bar -O --output-dir "$outpath" "$url"
		else
			curl -qf --compressed --progress-bar -o "$outpath" "$url"
		fi
		[ $? -ne 0 ] && return 1 || return 0
  elif [ "$downloader" == "wget" ]; then
		if [ "$output_to_dir" -eq 0 ]; then
			wget --progress=bar -q -P "$outpath" "$url"
		else
			wget --progress=bar -q -O "$outpath" "$url"
		fi
		[ $? -ne 0 ] && return 1 || return 0
	fi
}

make_get_request() {
	# [capturable]
	# Make a GET request using one of the supported network commands.
	# Query parameters may be passed as additional arguments.
	# Values of query parameters are encoded automatically.
	# Arguments:
	# 	$1 - The URL of the request.
	#		$Q - The list of query parameters for the request.
	# Examples:
	#   make_get_request "https..com" "req=5" "delete=yes"
	#   make_get_request "https://www.google.com/search" "q=How to swim?"
	# Returns:
	# 	The received response content on success.

	local downloader; downloader="$(get_downloader)"
	[ $? -ne 0 ] && return 1

	local url="$1"
	shift

	local query_params=""
	while [[ $# -gt 0 ]]; do
		local key="${1%%=*}"
		local value="${1#*=}"
		shift

		value="$(jq -nr --arg val "$value" '$val | @uri')"
		[ $? -ne 0 ] && return 1

		query_params+="&${key}=${value}"
	done
	if [ -n "$query_params" ]; then
		query_params="${query_params:1}"
		url="${url}?${query_params}"
	fi

	if [ "$downloader" == "curl" ]; then
    curl -qfsL --compressed "$url"
		[ $? -ne 0 ] && return 1 || return 0
  elif [ "$downloader" == "wget" ]; then
    wget -qO - "$url"
		[ $? -ne 0 ] && return 1 || return 0
	fi
}

get_file_links_from_github_repo() {
	# [capturable]
	# Make a github API request to retrieve the content
	# of a specified repository's directory. Then extract
	# and return file links from that data.
	# Arguments:
	# 	$1 - The user name of the repository.
	# 	$2 - The repository name.
	# 	$3 - The name of a commit/branch/tag. Pass
	#        an empty string to omit.
	# 	$4 - The directory path in the repository.
	# Returns:
	#   The list of file URLs from the repository.
	#   Items are separated by newline characters.

	local username="$1"
	local repo_name="$2"
	local reference="$3"
	local path="$4"

	local url="https://api.github.com/repos/${username}/${repo_name}/contents/${path}"

	local response;
	if [ -n "$reference" ]; then
		response="$(make_get_request "$url" "ref=${reference}")"
	else
		response="$(make_get_request "$url")"
	fi
	[ $? -ne 0 ] && return 1

	jq -r '.[] | select(.type == "file") | .download_url' <<< "$response"
	[ $? -ne 0 ] && return 1 || return 0
}


# = = = = = = = = = = = = = = = = = = = =
#     Managing: Environments & Paths
# = = = = = = = = = = = = = = = = = = = =

append_path_variable() {
	# [control]
	# Append new paths to the PATH variable.
	# Arguments:
	#   $1 - The list of space-separated paths to append.

	for item in $1; do
		if includes_by_delimiter "$PATH" ":" "$item"; then continue; fi
		PATH+=":$item"
	done
}

establish_temp_path() {
	# [capturable]
	# Create a special directory in '/tmp' for temporary
	# files used during the installation process.
	# Returns:
	#   The path to the temporary directory.

	local temp_path="/tmp/bash-crud"

	if [ ! -d "$temp_path" ]; then
		mkdir -p "$temp_path"
		[ $? -ne 0 ] && return 1
	fi

	printf %s "$temp_path"
}

establish_gawk_path() {
	# [capturable]
	# Prepare a directory for installing gawk programs.
	# Conditions:
	# 	If AWKPATH contains multiple paths then the last one is used.
	# 	If AWKPATH is unset then 'default_awkpath' is used.
	# Returns:
	#		The directory path for placing the project's gawk programs.

	local default_awkpath="/usr/share/awk"

	local awk_path
	awk_path="$(gawk 'BEGIN { len=split(ENVIRON["AWKPATH"], arr, ":"); printf "%s", arr[len] }')"
	[ $? -ne 0 ] && return 1

	local path="${awk_path:-$default_awkpath}/bash-crud"

	mkdir -p "$path"
	[ $? -ne 0 ] && return 1

	printf %s "$path"
}

establish_bin_path() {
	# [capturable]
	# Prepare a directory for installing the project's executables.
	# Returns:
	#   The directory path for executables.

	local default="/usr/local/bin"
	printf %s "$default"
}


# = = = = = = = = = = =
#   The Main Section
# = = = = = = = = = = =

install() {
	# [control]

	# Checking required tools
	establish_jq
	[ $? -ne 0 ] && return 1


	# Installing bash-crud.sh
	local bin_path; bin_path="$(establish_bin_path)"
	[ $? -ne 0 ] && return 1

	local script_url; script_url="$(get_resource_url "bash-crud-script")"
	[ $? -ne 0 ] && return 1

	local response; response="$(make_get_request "$script_url")"
	[ $? -ne 0 ] && return 1

	local script_path="${bin_path}/bash-crud"
	printf %s "$response" > "$script_path"
	[ $? -ne 0 ] && return 1

	chmod 755 "$script_path"
	[ $? -ne 0 ] && return 1


	# Installing gawk programs
	local gawk_path; gawk_path="$(establish_gawk_path)"
	[ $? -ne 0 ] && return 1

	mapfile -t gawk_urls <<< "$(get_resource_url "gawk")"
	[ $? -ne 0 ] && return 1

	for url in "${gawk_urls[@]}"; do
		download_file "${gawk_path}/" "$url"
		[ $? -ne 0 ] && return 1
	done

	return 0
}

if [[ -z "${BC_TEST__TEST_ENVIRONMENT:-}" ]]; then
	install
fi