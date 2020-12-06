def multiple_of($value; $target): $value % $target == 0 ;

def calculate_idle_time($curr; $prev):
  # substract the queuing time because if a job is queued the
  # runner is not idleing around, but evaluating a job
  [ $curr.time_raw - $prev.time_raw - $curr.queuing, 0 ]
  | max
;

def calculate_idle($results):
  # for-loop to calculate idle-time
  [ range( 1; length ) ]
  | [ $results[ 0 ] ]
    + map(
        $results[. - 1] as $prev
        | $results[ . ]
        | . + { idle: calculate_idle_time( .; $prev ) }
      )
;

def evaluate_match($match; $target):
  $match
  | .value  as $test
  | $target[.key] as $value
  | if .mode == "contains" then
      $test | inside( $value | tostring )
    elif .mode == "startswith" then
      $value | tostring | startswith( $test )
    elif .mode == "endswith" then
      $value | tostring | endswith( $test )
    elif .mode == "not" then
      ( $value | tostring ) != $test
    elif .mode == "less" then
      ( $value | tonumber) < ( $test | tonumber )
    elif .mode == "greater" then
      ( $value | tonumber) > ( $test | tonumber )
    elif .mode == "after" then
      $value > $test
    elif .mode == "before" then
      $value < $test
    else
      ( $value | tostring ) == $test
    end
  | if $match.not then not else . end
;

# if keys to keep are specified they are used
# otherwise the unsorted keys of the first entry
# are used after removing the keys specified in delete
def used_keys($keep; $delete):
  if $keep != [] then
    $keep
  else
    ( .[ 0 ] | delpaths( $delete ) | keys_unsorted )
  end
;

def matches_all($filter; $target):
  $filter
  | map( evaluate_match( .; $target ) )
  | all
;

def insert_headers($keys; $term_lines):
  # for-loop to insert table-headers and newlines
  length as $amount
  | . as $results
  | [ range( 0; $amount ) ]
  | map(
      . as $index
      | ( $amount - $index ) as $index_rev
      | $results[ $index ]
      | if multiple_of( $index_rev + 0; $term_lines ) then
          $keys, .
        elif multiple_of( $index_rev - 1; $term_lines ) then
          ., [ "" ]
        else . end
    )
;

def truncate_string($len): if length > $len then .[ : $len ] + "+" else . end ;

# group by field and insert header
def group_by_fields($keys; $fields; $term_lines):
  ( $fields | length ) as $amount
  | if $amount > 0 then
      $fields[ 0 ] as $conf
      | $conf.key as $field
      | group_by( .[ $field ][ $conf.start : $conf.end ] )
      | map(
        . as $input
        | .[ 0 ][ $field ][ $conf.start : $conf.end ]
        # too long fields must be truncated
        # only works fine if first field is time :)
        | [ [ "" ], [ " " + truncate_string( 17 ) ], [ "" ] ] as $header
        | if $amount > 1 then
            $input
            | group_by_fields( $keys; $fields[ 1 : ]; $term_lines )
            | flatten( 1 )
          else
            [ $keys ] + ( $input | insert_headers( $keys; $term_lines ) )
          end
        | $header + .
      )
    else
      .
    end
;

# convert objects to arrays sorted by the keys
def object_to_array($keys):
  map(
    if type == "object" then
      . as $obj
      | $keys
      | map( $obj[ . ] | tostring )
    else
      .
    end
  )
;

def build_filter:
  split( "=" )
  | { key: .[ 0 ], value: .[ 1 ], mode: .[ 2 ], not: false}
  | if .mode then
      . + { not: .mode | startswith( "@" ) }
    else
      .
    end
  | if .not then .mode = .mode[ 1 : ] else . end
;

def build_group:
  split( "=" ) as $parts
  | { key: $parts[ 0 ], start: 0, end: null }
  | if $parts[1] then
      . as $obj
      | $parts[1]
      | split( ":" ) as $offsets
      | $obj + { start: $offsets[ 0 ] | tonumber }
      | if $offsets[1] then
          . + { end: $offsets[ 1 ] | tonumber }
        else
          .
        end
    else
      .
    end
;

# prepare variables
. as $results
| ( $term_lines | tonumber - 5 ) as $term_lines
| ( $order | startswith( "@" ) ) as $sort_reverse
| ( if $sort_reverse then $order[ 1 : ] else $order end ) as $order
| ( $delete | split( "," ) | map( [ . ] ) ) as $delete
| ( $keep   | split( "," ) ) as $keep
| ( $filter | split( "," ) | map( build_filter ) ) as $filter
| ( $group  | split( "," ) | map( build_group  ) ) as $group
| calculate_idle( $results )

## delete the temporary field used for the idle-time calculation
| map( del( .time_raw ) )

| used_keys( $keep; $delete ) as $keys

## apply the output filter
| map( select( matches_all( $filter; . ) ) )

| sort_by( .[ $order ] )
| if $sort_reverse then reverse else . end

## grouping
| if $group[0] == "none" then
    [ [ $keys ], insert_headers( $keys; $term_lines ) ]
  else
    group_by_fields( $keys; $group; $term_lines )
  end

| map( object_to_array( $keys ) )
| flatten( 1 )
| .[]
