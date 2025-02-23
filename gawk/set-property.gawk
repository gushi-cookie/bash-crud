@include "utils.gawk"

function print_property() {
  if (no_wrap ~ /^[Tt]/) {
    printf "%s=%s\n", key, value
  } else {
    printf "%s=\"%s\"\n", key, escape_bash_chars(value)
  }
}

BEGIN {
  FS = "="
  key_occurrence_count = 0
  should_exit = 0

  if (ARGC < 3 + 1) {
    should_exit = 1
    print "Error: at least 3 arguments are required where: key=arg1, value=arg2 and arg3+ are file paths to process." > "/dev/stderr"
    exit 1
  }

  key = ARGV[1]; ARGV[1] = ""
  if (length(key) == 0) {
    should_exit = 1
    print "Error: empty string was passed as a name of the property (arg1)." > "/dev/stderr"
    exit 1
  }

  value = ARGV[2]; ARGV[2] = ""
}

{
  if ($1 != key || $0 ~ /^#/) {
    print
    next
  }

  key_occurrence_count++
  print_property()
}

END {
  if (key_occurrence_count == 0 && !should_exit) {
    print_property()
  }
}
