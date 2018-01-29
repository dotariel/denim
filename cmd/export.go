package cmd

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

// Export returns a command to produce export room information to VCF.
func Export() *cobra.Command {
	var prefix string

	cmd := &cobra.Command{
		Use:   "export FILE [flags]",
		Short: "export rooms to VCF (Variant Call Format)",
		Args:  cobra.ExactArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			_, err := room.Export(args[0], prefix)
			if err != nil {
				fmt.Printf("export failed; %v", err)
			}
		},
	}

	cmd.Flags().StringVarP(&prefix, "prefix", "p", "bluejeans-", "name prefix for go card entries")

	return cmd
}
