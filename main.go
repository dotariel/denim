package main

import (
	"github.com/dotariel/denim/cmd"
	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

var rootCmd *cobra.Command

func init() {
	rootCmd = &cobra.Command{
		Use:  "denim",
		Long: "Denim manages the use of persistent BlueJeans meetings as named rooms.",
	}
	rootCmd.AddCommand(cmd.Version())
	rootCmd.AddCommand(cmd.List())
	rootCmd.AddCommand(cmd.Open())
	rootCmd.AddCommand(cmd.Export())

	room.Load()
}

func main() {
	rootCmd.Execute()
}
