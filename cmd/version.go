package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// Version returns a command to display version information
func Version(version, build string) *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "display version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Printf("Denim v%s-%s\n", version, build)
			return
		},
	}
}
