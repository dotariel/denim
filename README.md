# denim

Denim manages the use of persistent BlueJeans meetings, Slack huddles, Zoom calls, and Google Hangouts as named rooms.

![build](https://github.com/esumerfd/denim/actions/workflows/main.yml/badge.svg)

## Install

Denim is installed with Homebrew on macOS (arm64 and amd64) and Linux (arm64 and amd64).

The formula lives in this repository, so tap it with the explicit URL once:

```
$ brew tap esumerfd/denim https://github.com/esumerfd/denim
```

Then install using the fully-qualified name. Homebrew refuses a bare `brew install denim` from a tap it has not been told to trust.

```
$ brew install esumerfd/denim/denim
$ denim version
```

To upgrade to the latest release:

```
$ brew update && brew upgrade esumerfd/denim/denim
```

To remove it:

```
$ brew uninstall esumerfd/denim/denim
$ brew untap esumerfd/denim
```

Windows binaries are attached to each [GitHub release](https://github.com/esumerfd/denim/releases).

## macOS Gatekeeper

Installing with Homebrew needs no extra step — Homebrew downloads binaries with
`curl`, which does not set the macOS quarantine flag.

If you instead download a `.tar.gz` directly from the
[releases page](https://github.com/esumerfd/denim/releases), the extracted
`denim` binary may be blocked by Gatekeeper the first time you run it (it is
unsigned). Clear the flag with:

```
$ xattr -d com.apple.quarantine denim
```

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

```
$ make build      # build a local dev binary at gen/denim
$ make install    # build and install denim to your Go bin directory (go env GOPATH/bin)
$ make dist       # run the tests, then cross-compile all five release targets into gen/dist
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

## Cutting a release

1. Go to **Actions → Release → Run workflow** on `esumerfd/denim`.
2. Leave the **version** field blank to release the latest tag plus one patch,
   or type an exact `X.Y.Z` for a deliberate version jump.
3. The workflow builds all five binaries, publishes a GitHub release with the
   `denim_<os>_<arch>.tar.gz`/`.zip` archives and `SHA256SUMS`, rewrites
   `Formula/denim.rb` with the new URLs and checksums, and pushes that one
   commit to `master`. It then verifies a fresh install and an upgrade from
   the previous release on macOS arm64/amd64 and Linux amd64/arm64.

If the formula push fails after the release is already published (rare — a
push race with another commit), the workflow's log prints the exact version,
URLs and sha256 values so you can commit `Formula/denim.rb` by hand.
Re-running the workflow for the same version will then correctly refuse,
since the release already exists.
