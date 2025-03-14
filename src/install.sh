#!/usr/bin/env bash
set -e

# Used environments:
# 	BASH_CRUD_DOWNLOADER
#			Which network command should be used for
#			downloading files and making http requests.
#			Valid values: ["curl", "wget"]. Default: "curl".
#   BC_TEST__PASS_COMMAND
#     A space-separated list of command names that
#     should be treated as an existing commands for
#     testing purposes. Used by the has_cmd() function.
#   BC_TEST__MISS_COMMAND
#     A space-separated list of command names that
#     should be treated as missing commands for testing
#   	purposes. Used by the has_cmd() function.


# = = = = = = = = = =
#     Utilities
# = = = = = = = = = =

print_error() {
	# Print an error message to the stderr stream.
	# Arguments:
	# 	A list of arguments that is combined into a
	#   single string and printed then.

	printf "%s\\n" "$*" >&2
}

print_error_and_exit() {
	# Print an error message to the stderr stream and
	# exit with code 1 from the script.
	# Arguments:
	# 	A list of arguments that is combined into a
	#   single string and printed then.

	printf "%s\\n" "$*" >&2
	return 1
}

get_current_version_tag() {
	# Get a hardcoded version tag of the currently
	# supported or developed version.

	printf "v0.1.0"
}

includes_by_delimiter() {
	# Check if a list of strictly delimited values
	# has an item with an exact value.
	# Arguments:
	#   $1 - The list of delimited values.
	#   $2 - The delimiter.
	#   $3 - The value to check.
	# Returns:
	#   0 - If the item is included.
	#   1 - If the item is not included.


	[[ " $(echo "$1" | tr "$2" " ") " == *" ${3} "* ]]
	return $?
}

has_cmd() {
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
	# Get an architecture suffix for the 'jqlang/jq' tool,
	# according to its ci.yml file and the current machine's
	# architecture.
	# Conditions:
	#		The script exits with an error if the machine's
	#		architecture not supported/listed.
	# Returns:
	# 	An architecture suffix for the 'jq' tool.


	case "$(uname -m)" in
				 'x86_64') printf 'amd64';;
		'i686'|'i386') printf 'i386';;
				'aarch64') printf 'arm64';;
					's390x') printf 's390x';;
				'riscv64') printf 'riscv64';;
								*) print_error_and_exit "Architecture '$(uname -m)' for 'jq' tool not supported.";;
	esac
}

establish_jq() {
	# Setup the 'jq' tool if it is not installed.

	if has_cmd "jq"; then return 0; fi
	printf "Command 'jq' not found. Downloading it for the current session..\n"

	local temp_path
	temp_path="$(establish_temp_path)"

	download_file "$temp_path/jq" "$(get_download_link "jq")"
	chmod 111 "$temp_path/jq"
}

get_downloader() {
	# Get a command name of the supported tool for
	# making http requests.
	# Environments:
	# 	BASH_CRUD_DOWNLOADER - force to use a specific command.
	#		Valid values are 'curl' and 'wget'.
	# Conditions:
	# 	If BASH_CRUD_DOWNLOADER is invalid or the supplied
	#		command not found - exits with an error.
	#		If none of supported commands not found - exits
	#		with an error.
	# Returns(by print):
	# 	The appropriate downloader command name.


	if [ "${BASH_CRUD_DOWNLOADER:-}" == "curl" ]; then
		if has_cmd "curl"; then printf %s "curl"; return; fi
		print_error_and_exit "Selected downloader command 'curl' not found on the system."
	fi

	if [ "${BASH_CRUD_DOWNLOADER:-}" == "wget" ]; then
		if has_cmd "wget"; then printf %s "wget"; return; fi
		print_error_and_exit "Selected downloader command 'wget' not found on the system."
	fi

	if has_cmd "curl"; then
		printf %s "curl"
	elif has_cmd "wget"; then
		printf %s "wget"
	else
		print_error_and_exit "Neither 'curl' nor 'wget' commands were found."
	fi
}


# = = = = = = = = = = = =
#    Networking: Http
# = = = = = = = = = = = =

download_file() {
	# Download a file using curl or wget. Query parameters
	# may be passed as arguments after supplying required arguments.
	# They get url encoded automatically.
	# Arguments:
	# 	$1 - The name of the output file that may include an absolute path.
	# 	$2 - The URL of the request.
	#		$Q - The list of query parameters for the request.
	# Examples:
	# 	1) download_file /dev/null https..com "req=5" "delete=yes" "please=sir"


	local downloader=get_downloader
	local outfile="$1"
	local url="$2"
	shift 2

	local query_params=""
	while [[ $# -gt 0 ]]; do
		local key="${1%%=*}"
		local value="${1#*=}"
		shift

		value="$(jq -nr --arg val "$value" '$val | @uri')"
		query_params="${query_params}&${key}=${value}"
	done
	if [ -n "$query_params" ]; then
		query_params="${query_params:1}"
		url="${url}?${query_params}"
	fi

  if [ "$downloader" == "curl" ]; then
    curl -qf --compressed --progress-bar -o "$outfile" "$url"
  elif [ "$downloader" == "wget" ]; then
		wget --progress=bar -q -O "$outfile" "$url"
	fi
}

make_get_request() {
	# Make a GET request using curl or wget. Query parameters
	# may be passed as arguments after supplying required arguments.
	# They get url encoded automatically.
	# Arguments:
	# 	$1 - The URL of the request.
	#		$Q - The list of query parameters for the request.
	# Examples:
	# 	1) download_file /dev/null https..com "req=5" "delete=yes please=sir"
	# Returns(by print):
	# 	The received response content.


	local downloader=get_downloader
	local url="$1"
	shift

	local query_params=""
	while [[ $# -gt 0 ]]; do
		local key="${1%%=*}"
		local value="${1#*=}"
		shift

		value="$(jq -nr --arg val "$value" '$val | @uri')"
		query_params="${query_params}&${key}=${value}"
	done
	if [ -n "$query_params" ]; then
		query_params="${query_params:1}"
		url="${url}?${query_params}"
	fi

	if [ "$downloader" == "curl" ]; then
    curl -qfL --compressed "$url"
  elif [ "$downloader" == "wget" ]; then
    wget -qO - "$url"
	fi
}

get_file_links_from_github_repo() {
	# Make a github API request to retrieve the content
	# of a specified repository's directory. Then extract
	# and return file links from that data.
	# Arguments:
	# 	$1 - The user name of the repository.
	# 	$2 - The repository name.
	# 	$3 - The release tag.
	# 	$4 - The directory path in the repository.
	# Returns(by print):
	# 	The list of file links from the repository.


	# curl -GL --data-urlencode "ref=v0.1.0" "https://api.github.com/repos/gushi-cookie/bash-crud/contents/gawk"
	printf ""
}


# = = = = = = = = = = = = = = = = = = = =
#      Managing: Envs & File System
# = = = = = = = = = = = = = = = = = = = =

establish_temp_path() {
	# Prepare a directory in '/tmp' for temporary files
	# of the current session and add that path to the
	# PATH variable.
	# Returns(by print):
	#   The valid path of the temporary directory.


	local temp_path="/tmp/bash-crud"

	if [ ! -d "$temp_path" ]; then
		mkdir -p "$temp_path"
	fi

	if [[ ! "$PATH" =~ $temp_path ]]; then
		PATH="$PATH:$temp_path"
	fi

	printf %s "$temp_path"
}

establish_gawk_path() {
	# Prepare a child directory for gawk programs
	# according to a value of the AWKPATH variable.
	# Conditions:
	# 	If AWKPATH has multiple paths then the last one is used.
	# 	If AWKPATH is unset then 'default_awkpath' is used.
	# Returns(by print):
	#		A directory path for gawk programs.


	local default_awkpath="/usr/share/awk"

	local awk_path
	awk_path="$(gawk 'BEGIN { len=split(ENVIRON["AWKPATH"], arr, ":"); printf "%s", arr[len] }')"
	awk_path="${awk_path:-$default_awkpath}"

	local path="${awk_path}/bash-crud"
	mkdir -p "$path"
	printf %s "$path"
}

# get_bin_dir() {
# 	if [ -n "${BASH_CRUD_BIN_DIR:-}" ]; then
# 		printf %s "$BASH_CRUD_BIN_DIR"
# 	else
# 		printf "/usr/local/bin"
# 	fi
# }


# = = = = = = = = =
#  Download links
# = = = = = = = = =

get_download_link() {
	local resource="$1"
	local version_tag; version_tag="${BASH_CRUD_INSTALL_VERSION:-$(get_current_version_tag)}"
	local github_repo="gushi-cookie/bash-crud"

	if [ "$resource" == "gawk" ]; then
		printf %s "https://raw.githubusercontent.com/${github_repo}/${version_tag}/gawk"
	elif [ "$resource" == "main" ]; then
		printf %s "https://raw.githubusercontent.com/${github_repo}/${version_tag}/scripts/bash-crud.sh"
	elif [ "$resource" == "install" ]; then
		printf %s "https://raw.githubusercontent.com/${github_repo}/${version_tag}/scripts/install.sh"
	elif [ "$resource" == "jq" ]; then
		printf %s "https://github.com/jqlang/jq/releases/download/jq-1.7.1/jq-linux-$(get_architecture_for_jq)"
	else
		print_error_and_exit "Couldn't find a download link for resource type '${resource}'."
	fi
}

install() {
	local awk_path=establish_awk_path
	local version_tag=get_current_version_tag


}