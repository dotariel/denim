package main

import (
	"github.com/dotariel/denim/command"
	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

var rootCmd *cobra.Command

func init() {
	rootCmd = &cobra.Command{
		Use:  "denim",
		Long: "Denim manages the use of persistent BlueJeans meetings and Google Hangouts as named rooms.",
	}
	rootCmd.AddCommand(command.Version())
	rootCmd.AddCommand(command.List())
	rootCmd.AddCommand(command.Open())
	rootCmd.AddCommand(command.Export())

	room.Load()
}

func main() {
	rootCmd.Execute()
}
