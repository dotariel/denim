package command

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

var prefix string
var legacy bool

// Export returns a command to produce export room information to VCF.
func Export() *cobra.Command {
	cmd := &cobra.Command{
		Use:               "export <FILE, file.vcf> [flags]",
		Short:             "export rooms to VCF (Variant Call Format)",
		PersistentPreRunE: validateSource,
		Args:              cobra.ExactArgs(1),
		Run:               export,
	}

	cmd.Flags().StringVarP(&prefix, "prefix", "p", "", "name prefix for card entries")
	cmd.Flags().BoolVarP(&legacy, "legacy", "l", false, "use legacy (3.0) format")

	return cmd
}

func export(cmd *cobra.Command, args []string) {
	_, err := room.Export(args[0], prefix, legacy)
	if err != nil {
		fmt.Printf("export failed; %v", err)
	}
}
