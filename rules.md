# Binary functions
Binary functions are used in `if` conditions. Their return codes must be either `0 - true` or `1 - false`. Such functions must be reliable, simple and well tested. They ignore fails of used instructions.

Examples:
```bash
has_cmd() {
	type "$1" > /dev/null 2>&1
}

if has_cmd "git"; then
	echo "Git is presented."
else
	echo "Git is not presented." >&2
fi

if ! has_cmd "grep"; then
	echo "Error: grep not found." >&2
fi
```

# Capturable functions

## Concept 1: Error messages and exit codes
Capturable functions must print own error messages in stderr stream and exit with an appropriate non-zero code. Exit codes are described by functions itself. Code 0 always indicates a successful execution of a function.

Each instruction (command or function calls) inside a capturable function must be handled properly in cases when it is expected that an instruction may fail. Instructions that may fail always must have free access to stderr stream. If an instruction doesn't print anything on failure then a capturable function must print an error message by itself.

Examples:
```bash
capturable() {
	# The command will print in stderr by itself.
	mkdir -p /missing/dir
	[ $? -ne 0 ] && return 1

	# Example with an output enclosing.
	# The command is expected to print in
	# stderr by itself.
	VAR="$(ls -l /missing/dir)"
	[ $? -ne 0 ] && return 1

	# Another example of enclosing an output
	# and handling non-zero codes of a command
	# that doesn't print in stderr.
	if ! VAR="$(curl --silent https://google.commmm)"; then
		echo "Curl has failed for some reason." >&2
		return 1
		# Note that the actual exit code is not available in this format.
	fi

	# Bad example
	# Do not use multiple calls in a single expression.
	# The last call sets the exit code of the whole expression.
	# If any command before the last one prints an error message
	# then it is outputted but the code keeps its execution.
	VAR="${PATH}:$(cat /etc/path-mod-1):$(cat /etc/path-mod-2):$(cat /etc/path-mod-3)"
	[ $? -ne 0 ] && return 1
}

RESULT="$(capturable)"
```

## Concept 2: Output capture
Capturable functions are allowed to return string values by printing/echoing them in stdout stream. There are few constraints that guarantee a pure output return:
1. Capturable functions are always called inside command substitutions `$(..)` to capture their outputs.
2. STDOUT output of inner instruction calls must always be captured by command substitutions `$(..)` or redirected somewhere if that output is not intended to be returned.

Examples:
```bash
capturable() {
	# Case 1
	# If the command fails the error
	# message is freely printed in stderr.
	mkdir -vp "$compound_path" > /dev/null
	[ $? -ne 0 ] && return 1
	printf %s "$compound_path"

	# Case 2
	# Stdout is captured by the command
	# substitution construct. If the command
	# fails the error message is freely printed
	# in stderr.
	if "$(mkdir -vp "$compound_path")"; then
		printf %s "$compound_path"
	else
		return 1
	fi
}

RESULT="$(capturable)"
[ $? -ne 0 ] && handle_error
```


# Control functions
Control functions are regular bash functions with these constraints:
1. Can only return exit codes.
2. Can print verbose messages or command outputs.
3. Must be called outside of command substitutions `$(..)` by another control functions.
4. Must check each instruction that may fail.

Examples:
```bash
# Both functions a control ones.

download_file() {
	local outfile="$1"
	local url="$2"
	curl --compressed --progress-bar -o "$outfile" "$url"
	[ $? -ne 0 ] && return 1
	# If the command exits with non-zero code then the case must
	# be handled properly. In this case we don't handle errors
	# and just return code 1 to tell that the function has failed
	# and the error message was printed by curl. If the command would
	# be silent we would have to print own error message.
}

main_func() {
	local dir="/dev/null"
	local urls=("https://google.com" "https://youtube.come")

	for url in "${urls[@]}"; do
		download_file "$dir" "$url"
		[ $? -ne 0 ] && return 1
	done
}
```