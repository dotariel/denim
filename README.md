# denim

Denim manages the use of persistent BlueJeans meetings, Slack huddles, Zoom calls, and Google Hangouts as named rooms.

![build](https://github.com/dotariel/denim/actions/workflows/main.yml/badge.svg)
[![Go Report Card](https://goreportcard.com/badge/github.com/dotariel/denim)](https://goreportcard.com/report/github.com/dotariel/denim)
[![codecov](https://codecov.io/gh/dotariel/denim/branch/master/graph/badge.svg)](https://codecov.io/gh/dotariel/denim)

## Room Definitions

Denim will look for room definition files in the following locations and order:

- `$HOME/.denim/`
- `$DENIM_HOME/`

Room definitions are managed in separate files:

- BlueJeans - `rooms`
- Zoom - `zoom`
- Slack - `slack`
- Hangouts - `hangouts` DEPRECATED

For example:

```
$DENIM_HOME
└── rooms
└── zoom
└── slack
├── hangouts
```

### File Structure

The room definition file should contain one room definition per line as follows:

```
NAME  MEETING_ID
```

For example:

```
MY_AWESOME_ROOM   123445578
```

**NOTE**: Room names are not case-sensitive.
**NOTE**: Different room types require different configuration.

### Configuration

Example config for each type:

```
: cat ~/.denim/zoom
zoom1 organization meetingId password
: cat ~/.denim/slack
slack1 team password
```

## Build

To build and run denim locally:

```
$ make install
```

## Usage

Denim supports multiple commands. Use `denim -h` to display the usage.

```
Denim manages the use of persistent BlueJeans meetings and Google Hangouts as named rooms.

Usage:
  denim [command]

Available Commands:
  export      export rooms to VCF (Variant Call Format)
  help        Help about any command
  list        list available rooms
  open        open a room
  show        show room detail
  version     display version information

Flags:
  -h, --help   help for denim

Use "denim [command] --help" for more information about a command.
```

## Bash Completions

To integrate denim bash completions into your shell, add it to your `.bashrc` file.

```
$ source bash_completions
```
