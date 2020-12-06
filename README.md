# Runner Diaganostics Script

## Description

This is a script to monitor the usage of a self-hosted GitHub runner by extracting the job information JSON from the diagnostics log located in the `<runner-dir>/_diag` directory.

Fields to extract are defined in the `process.jq` which caches the the extraced json. Before saving a basic filter is applied that converts the unreadable JSON from the serialization in the runner.

Formatting is applied on all cached JSON files at once using the filter in `format.jq`. All the magic happens in this file.

Relative values like the idle time are calculated, specified keys can be be removed or selected.

Output is grouped by date, table headers are inserted approximately for each page.

The table is displayed using `column`.

More output control is available via flags (see `-h` for defaults and more information):

| Flag | Name   | Parameter                   | Description                                 |
| ---- | ------ | --------------------------- | ------------------------------------------- |
| `-k` | keep   | `field[,...]`               | Display only selected fields                |
| `-r` | remove | `field[,...]`               | Remove selected fields                      |
| `-s` | sort   | `field`                     | Sort by this field, `@` to reverse          |
| `-g` | group  | `field[=start[:end]][,...]` | Group by selected field at string slice     |
| `-f` | filter | `field=value[=mode][,...]`  | Filter output by selected fields and values |

**Filter modes**

| Mode   | Filter     | Description        |
| ------ | ---------- | ------------------ |
| string | exact      | Exact match        |
| string | startswith | Match at start     |
| string | endswith   | Match at end       |
| string | contains   | Match if contains  |
| number | less       | Match if less      |
| number | greater    | Match if greater   |
| date   | after      | Match dates after  |
| date   | before     | Match dates before |

Prefix a mode with `@` to invert the match.

## Usage

If your script is in `~/actions-runner/diagnostics` and your runner is in `~/actions-runner`:

```bash
$ ./stats.sh -p ../_diag/Worker_2020
```

I recommend to hardcode this path in `stats.sh` and set it as the default `PREFIX` value.

Then you can use the script like this:

```bash
$ ./stats.sh -r owner,event -f event=push,time=2020-01-01=after -g time=0:10,workflow -s @duration
```

Remove owner and event fields, filter by event `push` and after the date `2020-01-01`, group by the first 10 characters of time and then by the workflow name, descending sort by the duration.

Output:

```
 2020-01-01

 Workflow 1

time                  repo             run          actor   build  workflow    job    number  queuing  idle  duration
2020-01-01T00:00:00Z  repository-name  45674545454  myself  1      Workflow 1  Job 1  1       9        3600  120
2020-01-01T01:04:12Z  repository-name  45674545456  myself  3      Workflow 1  Job 1  2       12       3600  110

  Workflow 2

time                  repo             run          actor   build  workflow    job    number  queuing  idle  duration
2020-01-01T00:02:00Z  repository-name  45674545455  myself  2      Workflow 1  Job 1  1       129      0     120
2020-01-01T01:02:12Z  repository-name  45674545457  myself  4      Workflow 1  Job 1  2       122      0     110
```

Values are just made up and not consistent.
