package main

import (
	"log"
	"os"

	"github.com/dotariel/denim/cmd"
	"github.com/dotariel/denim/room"
)

var (
	Version string = "0.0.0"
	Build   string = "0"
)

func init() {
	if err := room.Load(); err != nil {
		log.Fatal(err)
		os.Exit(1)
	}
}

func main() {
	cmd.New(Version, Build).Execute()
}
