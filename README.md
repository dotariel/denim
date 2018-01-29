# denim

A command-line helper utility for interacting with BlueJeans.

[![Build Status](https://travis-ci.org/dotariel/denim.svg?branch=master)](https://travis-ci.org/dotariel/denim)

## Room Definitions

Denim will look for room definition files in the following locations and order:

* `$DENIM_ROOMS`
* `$HOME/.denim/rooms`
* `$DENIM_HOME/rooms`

### File Structure

The room definition file should contain one room/alias definition per new-line as follows:

```
NAME  MEETING_ID
```

For example:

```
MY_AWESOME_ROOM   123445578
```

**NOTE**: The aliases are not case-sensitive.

## Usage

Denim supports multiple commands. Use `denim -h` to display the usage.
