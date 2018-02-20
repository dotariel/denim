# denim

Denim manages the use of persistent BlueJeans meetings as named rooms.

[![Build Status](https://travis-ci.org/dotariel/denim.svg?branch=master)](https://travis-ci.org/dotariel/denim)

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

## Build

To build and run denim locally:

```
$ export GOPATH=[SOME GOOD PLACE TO PUT A GO RUNTIME]
$ go get github.com/dotariel/denim
$ cd $GOPATH/src/github.com/dotariel/denim
$ make install
```

## Usage

Denim supports multiple commands. Use `denim -h` to display the usage.

```
Denim is a command-line utility for interacting with BlueJeans

Usage:
  denim [command]

Available Commands:
  export      export rooms to VCF (Variant Call Format)
  help        Help about any command
  list        list available channels
  open        open a room
  version     display version information

Flags:
  -h, --help   help for denim

Use "denim [command] --help" for more information about a command.
```
