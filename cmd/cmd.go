package cmd

import (
	"github.com/spf13/cobra"
)

// New creates a new root command entrypoint for the application
func New(version string) *cobra.Command {
	var root *cobra.Command

	root = &cobra.Command{
		Use:   "denim",
		Short: "Denim is a command-line utility for interacting with BlueJeans",
	}
	root.AddCommand(Version(version))
	root.AddCommand(List())
	root.AddCommand(Open())

	return root
}
