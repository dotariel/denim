package command

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

// Show displays a room's detail
func Show() *cobra.Command {
	return &cobra.Command{
		Use:   "show ROOM",
		Short: "show room detail",
		Run:   showRoom,
		Args:  cobra.ExactArgs(1),
	}
}

func showRoom(cmd *cobra.Command, args []string) {
	r := args[0]

	rm, err := room.Find(r)
	if err != nil {
		fmt.Println(err)
		return
	}

	fmt.Printf("%-10s %s\n", "Name:", rm.Name)
	fmt.Printf("%-10s %s\n", "App:", rm.AppURL())
	fmt.Printf("%-10s %s\n", "Browser:", rm.BrowserURL())
	fmt.Printf("%-10s %s\n", "Meeting:", rm.MeetingURL())
	fmt.Printf("%-10s %s\n", "Phone:", rm.Phone())
}
