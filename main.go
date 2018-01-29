package main

import (
	"github.com/dotariel/denim/cmd"
	"github.com/dotariel/denim/room"
)

var (
	Version string = "0.0.0"
	Build   string = "0"
)

func init() {
	room.Load()
}

func main() {
	cmd.New(Version, Build).Execute()
}
