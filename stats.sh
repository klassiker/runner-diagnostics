#!/bin/bash
#
# Version: 1.0.0
#
# Dependencies
#
# - tput (ncurses)
# - column (util-linux)
# - awk (gawk)
# - jq
# - sed
#
# Description
#
#  This is a script to monitor the usage of a self-hosted GitHub runner
#  by extracting the job information JSON from the diagnostics log
#  located in the "<runner-dir>/_diag" directory.
#
#  Fields to extract are defined in the "process.jq" which caches the
#  the extraced json. Before saving a basic filter is applied that
#  converts the unreadable JSON from the serialization in the runner.
#
#  Formatting is applied on all cached JSON files at once using
#  the filter in "format.jq". Relative values like the idle time are
#  calculated, specified keys can be be removed or selected.
#  Output is grouped by date, table headers are inserted
#  approximately for each page.
#

function show_help() {
  cat <<EOF

 Usage: ./stats.sh [flags]

   -h (show help)
      This help.

   -v (verbose)
      Can be used multiple times to increase the log level.

   -d (debug)
      Enables "set -x" for bash.

   -n (no-cache)
      Disable caching completely. Useful if "process.jq" changes.

   -p directory-prefix (log directory and file prefix)
      Specify the directory where the diagnostic logs are located.
      All files matching "<directory-prefix>*-utc.log" are parsed.
      Default: "_diag/Worker_"

   -k field1[,field2[,...]] (display these fields)
      Specify a comma-separated list of column names.
      All other fields are removed from the output.
      This is used if "-r" is set too.

   -r field1[,field2[,...]] (remove these fields)
      Specify a comma-separated list of column names.
      All other fields are included in the output.

   -s field
      Sort the output by this field.
      Prefix this with "@" to reverse the sorting order.
      Default: as input (time)

   -g field1[=start[:end]][,field2[=start[:end][,...]]
      Group by these fields. Ordering is important.

      Specify and optional start and end. The string will
      be sliced at these offsets.

      Specify "none" as field for no grouping.

      Default: time=0:10

   -f key1=value1[=mode1][,key2=value2[=mode2][,...]] (filter entries)
      Specify a comma-separated list of "key=value[=mode]" to filter the output.
      Default is string matching. If you select a number-mode input will
      be converted to a number. Date modes are also available.

      Prefix the mode with "@" to invert the match.

      Modes
        string: exact, startswith, endswith, contains
        number: less, greater
        dates: after, before
        Default: "exact"

EOF
}

function is_cached() {
  # if cache is disable never return success
  [[ $CACHE == 0 ]] && return 1

  # if file exists return success
  [[ -f "${1}" ]]   && return 0

  # otherwise return failure
  return 1
}

function log() {
  # set default log level
  LEVEL="${2:-0}"

  # if verbosity is less or equal don't log
  [[ $VERBOSE -le $LEVEL ]] && return

  echo "$1"
}

# Default values
PREFIX="_diag/Worker_"
KEEP=""
REMOVE=""
ORDER=""
GROUP="time=0:10"
FILTER=""
CACHE=1
DEBUG=0
VERBOSE=0

OPTIND=1
while getopts "h?p:k:r:s:g:f:dvn" opt; do
    case "$opt" in
    h)  show_help
        exit 0
      ;;
    v)  VERBOSE=$(( $VERBOSE + 1 ))
      ;;
    d)  DEBUG=1
      ;;
    n)  CACHE=0
      ;;
    p)  PREFIX="${OPTARG}"
      ;;
    k)  KEEP="${OPTARG}"
      ;;
    r)  REMOVE="${OPTARG}"
      ;;
    s)  ORDER="${OPTARG}"
      ;;
    g)  GROUP="${OPTARG}"
      ;;
    f)  FILTER="${OPTARG}"
      ;;
    esac
done

[[ $DEBUG == 1 ]] && set -x

log "Preparing all files"

for FILE in "${PREFIX}"*-utc.log;do
  log "Checking if ${FILE} is a file" 2

  [[ ! -f "${FILE}" ]] && log "Path is not a file, skipping" 2 && continue

  log "Checking if file ${FILE}.json is cached" 1

  is_cached "${FILE}.json" && log "File is cached, skipping" 1 && continue

  log "Extracting timestamp from last row" 1

  TIMESTAMP=$(tail -1 "${FILE}" | sed 's|^.\(.\{10\}\) \(.\{9\}\).*|\1T\2|g')

  log "Timestamp is: ${TIMESTAMP}" 2

  log "Extracting JSON from file" 1

  awk '/^ {$/,/^}$/' "${FILE}" \
    | sed 's|[^"]\*\*\*|""|g'  \
    | jq --arg end_time "${TIMESTAMP}" -f process.jq -c > "${FILE}.json"

done

log "Processing all files"

LINES=$(tput lines)

cat "${PREFIX}"*-utc.log.json \
  | jq --arg term_lines "${LINES}" --arg delete "${REMOVE}" --arg keep "${KEEP}" --arg filter "${FILTER}" --arg order "${ORDER}" --arg group "${GROUP}" -s -f format.jq -c \
  | column -t -s ',' \
  | tr -d '"[]'

log "Done."
