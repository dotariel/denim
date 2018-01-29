package cmd

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/pkg/browser"
	"github.com/spf13/cobra"
)

// Export generates an VCF file containing cards for all the rooms
func Export() *cobra.Command {
	var prefix string
	var open bool

	cmd := &cobra.Command{
		Use:   "export FILE",
		Short: "export rooms to VCF (Variant Call Format)",
		Args:  cobra.ExactArgs(1),
		Run: func(cmd *cobra.Command, args []string) {
			f, err := room.Export(args[0], prefix)
			if err != nil {
				fmt.Printf("export failed; %v", err)
			}

			if open {
				browser.OpenFile(f.Name())
			}
		},
	}

	cmd.Flags().BoolVarP(&open, "open", "o", false, "open file immediately")
	cmd.Flags().StringVarP(&prefix, "prefix", "p", "bluejeans-", "name prefix for go card entries")

	return cmd
}
