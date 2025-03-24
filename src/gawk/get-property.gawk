@include "utils.gawk"

BEGIN {
  FS = "="
  should_exit = 0
  has_key_matched = 0

  if (ARGC < 2 + 1) {
    should_exit = 1
    print "Error: at least 2 arguments are required where: key=arg1 and arg2+ are files to process." > "/dev/stderr"
    exit 1
  }

  key = ARGV[1]; ARGV[1] = ""
  if (length(key) == 0) {
    should_exit = 1
    print "Error: empty string was passed as a name of the property (arg1)." > "/dev/stderr"
    exit 1
  }
}

$1 == key && $0 !~ /^\s*#/ {
  has_key_matched = 1
  value = remove_double_quotes($2)
}

END {
  if (!should_exit) {
    if (!has_key_matched) {
      should_exit = 1
      printf "Property '%s' not found.", key > "/dev/stderr"
      exit 2
    } else {
			print value
		}
  }
}
