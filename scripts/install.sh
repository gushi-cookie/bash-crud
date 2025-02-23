#!/usr/bin/env bash
set -e

get_current_version_tag() {
	printf "v0.0.1"
}

get_download_source() {
	local version_tag; version_tag="${BASH_CRUD_INSTALL_VERSION:-$(get_current_version_tag)}"

	printf ""
}

get_bin_dir() {
	if [ -n "${BASH_CRUD_BIN_DIR:-}" ]; then
		printf %s "$BASH_CRUD_BIN_DIR"
	else
		printf "/usr/local/bin"
	fi
}

has_cmd() {
	type "$1" > /dev/null 2>&1
}

download() {
  if has_cmd "curl"; then
    curl --fail --compressed -q "$@"
  elif has_cmd "wget"; then
    # Emulate curl with wget
    ARGS=$(nvm_echo "$@" | command sed -e 's/--progress-bar /--progress=bar /' \
                            -e 's/--compressed //' \
                            -e 's/--fail //' \
                            -e 's/-L //' \
                            -e 's/-I /--server-response /' \
                            -e 's/-s /-q /' \
                            -e 's/-sS /-nv /' \
                            -e 's/-o /-O /' \
                            -e 's/-C - /-c /')
    # shellcheck disable=SC2086
    eval wget $ARGS
	else
		printf "Neither 'curl' nor 'wget' commands were found." >&2
		exit 1
	fi
}

establish_awk_path() {
	local default_path="/usr/share/awk"
	local awk_path; awk_path="$(gawk 'BEGIN { len=split(ENVIRON["AWKPATH"], arr, ":"); printf "%s", arr[len] }')"

	if [ -z "$awk_path" ]; then
		awk_path="$default_path"
	fi


	local path="${awk_path}/bash-crud"
	mkdir -p "$path"
	printf %s "$path"
}

install() {
	local awk_path=establish_awk_path
	local version_tag=get_current_version_tag


}