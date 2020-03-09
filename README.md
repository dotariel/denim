# denim

Denim manages the use of persistent BlueJeans meetings as named rooms.

[![Build Status](https://travis-ci.org/dotariel/denim.svg?branch=master)](https://travis-ci.org/dotariel/denim)
[![Go Report Card](https://goreportcard.com/badge/github.com/dotariel/denim)](https://goreportcard.com/report/github.com/dotariel/denim)
[![codecov](https://codecov.io/gh/dotariel/denim/branch/master/graph/badge.svg)](https://codecov.io/gh/dotariel/denim)

## Room Definitions

Denim will look for room definition files in the following locations and order:

* `$DENIM_ROOMS`
* `$HOME/.denim/rooms`
* `$DENIM_HOME/rooms`

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

Hangouts are handled separately, in a `hangouts` file in the denim settings directory

HANGOUT_ROOM      xQb_6MjxPbC_TsHIDW3xAEEE

## Build

To build and run denim locally:

```
$ make install
```

## Usage

Denim supports multiple commands. Use `denim -h` to display the usage.

```
Denim manages the use of persistent BlueJeans meetings as named rooms.

Usage:
  denim [command]

Available Commands:
  export      export rooms to VCF (Variant Call Format)
  help        Help about any command
  list        list available rooms
  open        open a room
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
