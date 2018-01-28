package cmd

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/pkg/browser"
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "denim",
	Short: "Denim is a command-line utility for interacting with BlueJeans",
}

var cmdList = &cobra.Command{
	Use:   "list",
	Short: "list available channels",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Rooms:")
		for _, room := range room.All() {
			fmt.Printf("%6s (%6s)\n", room.Alias, room.MeetingID)
		}
	},
}

var useBrowser bool

var cmdOpen = &cobra.Command{
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

func init() {
	cmdOpen.Flags().BoolVarP(&useBrowser, "browser", "b", false, "open in browser")
	rootCmd.AddCommand(cmdList, cmdOpen)
}

func Execute() {
	rootCmd.Execute()
}
