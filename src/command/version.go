package command

import (
	"fmt"

	"github.com/dotariel/denim/app"
	"github.com/spf13/cobra"
)

// Version returns a command to display version information.
func Version() *cobra.Command {
	return &cobra.Command{
		Use:   "version",
		Short: "display version information",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Fprintf(cmd.OutOrStdout(), "denim v%s (%s)\n", app.Version, app.BuildDate)
		},
	}
}
