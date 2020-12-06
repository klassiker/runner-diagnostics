# walk is not available in jq 1.5
def walk(f):
  . as $in
  | if type == "object" then
      reduce keys[] as $key
        ( {}; . + { ($key):  ($in[$key] | walk(f)) } ) | f
  elif type == "array" then map( walk(f) ) | f
  else f
  end;

# convert the funny json structure to readable json
def from_entries_map: .d | map( { "key": .k, "value": .v } ) | from_entries ;

# this condition searches for the funny json
def walk_object_condition: type == "object" and keys == [ "d", "t" ] and .t == 2 ;

# and here it is replaced recursively
def walk_object: walk( if walk_object_condition then from_entries_map else . end ) ;

# non-standard standard timestamp converter
def conv_timestamp: strptime( "%Y-%m-%d %H:%M:%S%z" ) | mktime ;

# shorthand variable definitions
def run_time: .variables."system.pipelineStartTime".value | conv_timestamp ;
def repo_owner: .contextData.github.repository_owner ;
def repo_name: .variables."system.definitionName".value ;
def run_id: .contextData.github.run_id | tonumber ;
def event_name: .contextData.github.event_name;
def actor_name: .contextData.github.actor ;
def build_id: .variables."build.buildId".value | tonumber ;
def workflow_name: .contextData.github.workflow ;
def job_name: .jobDisplayName ;
def run_number: .contextData.github.run_number | tonumber ;
def req_time: .contextData.github.event[event_name].updated_at | fromdate ;

# mostly unused, but interesting
def job_attempt: .variables."system.jobAttempt".value | tonumber ;
def job_pos: .variables."System.JobPositionInPhase".value | tonumber ;
def jobs_total: .variables."System.TotalJobsInPhase".value | tonumber ;
def phase_name: .variables."system.phaseName" ;
def phase_attempt: .variables."system.phaseAttempt" ;
def runner_group: .variables."system.runnerGroupName" ;

# strflocaltime is also not available in jq 1.5
# otherwise we could have local timestamps
# time: run_time | strflocaltime("%Y-%m-%d %H:%M:%S %Z"),

walk_object
# comment this for the full object
# and search for your own fields!
| {
    time: run_time | todate,
    time_raw: run_time,
    owner: repo_owner,
    repo: repo_name,
    run: run_id,
    event: event_name,
    actor: actor_name,
    build: build_id,
    workflow: workflow_name,
    job: job_name,
    number: run_number,
    queuing: ( run_time - req_time ),
    idle: 0,
    duration: ( ( $end_time | fromdate ) - run_time ),
  }
