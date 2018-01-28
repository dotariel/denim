package cmd

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/pkg/browser"
	"github.com/spf13/cobra"
)

// Open returns a command to open a room
func Open() *cobra.Command {
	var useBrowser bool

	cmd := &cobra.Command{
		Use:   "open [room]",
		Short: "open a room",
		Run: func(cmd *cobra.Command, args []string) {
			r := args[0]
			rm, err := room.Find(r)
			if err != nil {
				fmt.Println(err)
				return
			}

			if useBrowser {
				browser.OpenURL(rm.BrowserURL())
			} else {
				browser.OpenURL(rm.AppURL())
			}

		},
		Args: cobra.ExactArgs(1),
	}

	cmd.Flags().BoolVarP(&useBrowser, "browser", "b", false, "open in browser")

	return cmd
}
