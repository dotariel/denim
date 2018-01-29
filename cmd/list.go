package cmd

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

// List returns a command that displays all the available rooms.
func List() *cobra.Command {
	var verbose bool

	cmd := &cobra.Command{
		Use:   "list",
		Short: "list available channels",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Print("Rooms:")
			if verbose {
				fmt.Printf(" (using '%v')", room.RoomFile)
			}
			fmt.Print("\n")

			for _, room := range room.All() {
				fmt.Printf("   %-12s", room.Name)
				if verbose {
					fmt.Printf(" (%6s)", room.MeetingID)
				}
				fmt.Printf("\n")
			}
		},
	}

	cmd.Flags().BoolVarP(&verbose, "verbose", "v", false, "verbose")

	return cmd
}
