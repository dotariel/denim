package main

import (
	"github.com/dotariel/denim/cmd"
)

var version string

func main() {
	cmd.New(version).Execute()
}
