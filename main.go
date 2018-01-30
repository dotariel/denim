package main

import (
	"github.com/dotariel/denim/cmd"
	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

var (
	Version string = "0.0.0"
	Build   string = "0"
)

var rootCmd *cobra.Command

func init() {
	rootCmd = &cobra.Command{
		Use: "denim",
		Long: `Denim is a command-line utility for interacting with BlueJeans.

For more information, see (https://github.com/dotariel/denim).`,
	}
	rootCmd.AddCommand(cmd.Version(Version, Build))
	rootCmd.AddCommand(cmd.List())
	rootCmd.AddCommand(cmd.Open())
	rootCmd.AddCommand(cmd.Export())

	room.Load()
}

func main() {
	rootCmd.Execute()
}
