package main

import (
	"github.com/dotariel/denim/cmd"
)

var (
	Version string = "0.0.1"
	Build   string = "0"
)

func main() {
	cmd.New(Version, Build).Execute()
}
