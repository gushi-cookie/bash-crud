#!/usr/bin/env bash

# = = = = = = = = = = =
#    Presets Storage
# = = = = = = = = = = =

add_preset__tp() {
	# [control]
	# Add a preset key-value pair.
	# Arguments:
	#   $1 - The pair's key.
	#   $2 - The pair's value.

	local key="$1"
	local value="$2"

	if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z_0-9]*$ ]]; then
		printf "TO-DO: the key is invalid." >&2
		return 1
	fi

	PRESET_KEYS__TP+=("$key")
	PRESET_VALUES__TP+=("$value")
}

clear_presets__tp() {
	# [control]
	# Clear the presets storage.

	declare -ag PRESET_KEYS__TP=()
	declare -ag PRESET_VALUES__TP=()
}

get_preset_pair__tp() {
	# [capturable]
	# Form a valid bash assign expression from a
	# preset key-value pair. The value is enclosed
	# in double quotes and properly escaped.
	# Arguments:
	#   $1 - The preset's number.
	# Returns:
	#   The assign expression from the preset pair.

	if [ "$1" -le 0 ]; then
		printf "TO-DO: invalid preset number." >&2
		return 1
	elif [ "$1" -gt "${#PRESET_KEYS__TP[@]}" ]; then
		printf "TO-DO: out of the range." >&2
		return 1
	fi

	local key="${PRESET_KEYS__TP[(($1 - 1))]}"
	local value="${PRESET_VALUES__TP[(($1 - 1))]}"

	value="$(printf %s "$value" | gawk -i "/TO-DO/utils.gawk" '{ print escape_bash_chars($0) }' && echo -n .)"
	[ $? -ne 0 ] && return 1
	value="${value%.}"

	printf "%s=\"%s\"" "$key" "$value"
	[ $? -ne 0 ] && return 1 || return 0
}


# = = = = = = = = = = =
#   Preset Selectors
# = = = = = = = = = = =

is_selector__tp() {
	# [binary]

	if is_list_selector__tp "$1"; then
		return 0
	elif is_range_selector__tp "$1"; then
		return 0
	else
		return 1
	fi
}

is_list_selector__tp() {
	# [binary]

	[[ "$1" =~ ^[0-9]+(,[0-9]+)*$ ]]
	return $?
}

is_range_selector__tp() {
	# [binary]

	[[ "$1" =~ ^[0-9]+-[0-9]+$ ]]
	return $?
}

concat_presets__tp() {
	# [capturable]
	# Concat presets by a passed presets selector.
	# Lines are delimited by newline characters including
	# the trailing one.
	# Arguments:
	#   $1 - The presets selector.
	# Selector_format:
	#   There are two types of selectors - lists and
	#   ranges. Both use numbers (not indexes) to refer
	#   to key-value pairs.
	#   Examples with ranges:
	#   - "1-4" "2-12" LTR
	#   - "5-2" "8-6" RTL
	#   Examples with lists:
	#   - "1,2,3" "1,1,1" "7" "3,2,1"
	# Returns:
	#   The concatenated presets.

	local pair

	# List selector.
	if is_list_selector__tp "$1"; then
		for number in $(printf %s "$1" | tr ',' ' '); do
			pair="$(get_preset_pair__tp "$number")"
			[ $? -ne 0 ] && return 1
			printf "%s\n" "$pair"
		done

		return 0
	fi

	# Range selector.
	if is_range_selector__tp "$1"; then
		local from; from="$(printf %s "$1" | cut -d '-' -f 1)"
		[ $? -ne 0 ] && return 1

		local to; to="$(printf %s "$1" | cut -d '-' -f 1)"
		[ $? -ne 0 ] && return 1

		if [ "$from" -eq "$to" ]; then
			printf "TO-DO: cannot be same" >&2
			return 1
		elif [[ "$from" -le 0 || "$to" -le 0 ]]; then
			printf "TO-DO: above 0"
			return 1
		fi

		if [ "$from" -lt "$to" ]; then
			# LTR
			for ((i = "$from"; i <= "$to"; i++)); do
				pair="$(get_preset_pair__tp "$i")"
				[ $? -ne 0 ] && return 1
				printf "%s\n" "$pair"
			done
		elif [ "$from" -gt "$to" ]; then
			# RTL
			for ((i = "$to"; i >= "$from"; i--)); do
				pair="$(get_preset_pair__tp "$i")"
				[ $? -ne 0 ] && return 1
				printf "%s\n" "$pair"
			done
		fi

		return 0
	fi

	# Selector not recognized.
	printf "TO-DO: invalid selector." >&2
	return 1
}

concat_lines__tp() {
	# [capturable]
	# Concat presets and regular strings. If a passed argument
	# matches the presets selector it is handled by
	# 'concat_presets__tp()' function. Arguments that don't
	# match are concatenated as they are.
	# Arguments:
	#   $@ - The variadic sequence of preset selectors and
	#        regular strings.
	# Returns:
	#   The concatenation result.

	local value
	for arg in "$@"; do
		if is_selector__tp "$arg"; then
			value="$(concat_presets__tp "$arg" && echo -n .)"
			[ $? -ne 0 ] && return 1
			printf %s "${value%.}"
		else
			value="$arg"
			printf %s "$value"
		fi
	done
}