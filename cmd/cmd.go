package cmd

import (
	"github.com/spf13/cobra"
)

// New creates the root entrypoint command for the application.
func New(version, build string) *cobra.Command {
	var root *cobra.Command

	root = &cobra.Command{
		Use:   "denim",
		Short: "Denim is a command-line utility for interacting with BlueJeans",
	}
	root.AddCommand(Version(version, build))
	root.AddCommand(List())
	root.AddCommand(Open())
	root.AddCommand(Export())

	return root
}
