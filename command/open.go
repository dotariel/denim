package command

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/pkg/browser"
	"github.com/spf13/cobra"
)

var useBrowser bool
var userName string

// Open returns a command to open a room.
func Open() *cobra.Command {
	cmd := &cobra.Command{
		Use:               "open ROOM",
		Short:             "open a room",
		PersistentPreRunE: validateSource,
		Run:               openRoom,
		Args:              cobra.ExactArgs(1),
	}

	cmd.Flags().BoolVarP(&useBrowser, "browser", "b", false, "open in browser")
	cmd.Flags().StringVarP(&userName, "user", "u", "", "participant name")

	return cmd
}

func openRoom(cmd *cobra.Command, args []string) {
	r := args[0]
	rm, err := room.Find(r)
	if err != nil {
		fmt.Println(err)
		return
	}

	rm.SetUser(userName)

	if useBrowser {
		browser.OpenURL(rm.BrowserURL())
	} else {
		browser.OpenURL(rm.AppURL())
	}
}
