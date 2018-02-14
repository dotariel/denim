package command

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

var verbose bool

// List returns a command that displays all the available rooms.
func List() *cobra.Command {
	cmd := &cobra.Command{
		Use:               "list",
		Short:             "list available channels",
		PersistentPreRunE: validateSource,
		Run:               listRooms,
	}
	cmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "verbose")

	return cmd
}

func listRooms(cmd *cobra.Command, args []string) {
	fmt.Print("Rooms:")
	if verbose {
		fmt.Printf(" (using '%v')", room.Source())
	}
	fmt.Print("\n")

	for _, room := range room.All() {
		fmt.Printf("  %s\n", room.Print(verbose))
	}
}
