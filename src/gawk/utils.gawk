function remove_double_quotes(str) {
  gsub(/^"/, "", str)

  if(str ~ /"$/ && str !~ /\\"$/) {
    str = substr(str, 1, length(str)-1)
  }

  return str
}

function escape_bash_chars(str) {
  gsub(/\\/, "\\\\", str) # Escape backslash
  gsub(/\$/, "\\$", str)  # Escape $
  gsub(/"/, "\\\"", str)  # Escape "
  gsub(/`/, "\\`", str)   # Escape `

  return str
}
