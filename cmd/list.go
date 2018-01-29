package cmd

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

// List returns a command that displays all the available rooms
func List() *cobra.Command {
	return &cobra.Command{
		Use:   "list",
		Short: "list available channels",
		Run: func(cmd *cobra.Command, args []string) {
			fmt.Println("Rooms:")
			for _, room := range room.All() {
				fmt.Printf("%6s (%6s)\n", room.Name, room.MeetingID)
			}
		},
	}
}
