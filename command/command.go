// package command contains commands to manage the various operations.
package command

import (
	"fmt"

	"github.com/dotariel/denim/room"
	"github.com/spf13/cobra"
)

func validateSource(cmd *cobra.Command, args []string) error {
	if !room.AnyLoaded() {
		var msg string
		msg = msg + "room data could not be loaded from any of the following locations:\n"
		msg = msg + "  - $DENIM_ROOMS\n"
		msg = msg + "  - $HOME/.denim/rooms\n"
		msg = msg + "  - $DENIM_HOME/rooms\n"
		msg = msg + "  - $HOME/.denim/hangouts\n"
		msg = msg + "  - $DENIM_HOME/hangouts\n"
		msg = msg + "  - $HOME/.denim/zoom\n"
		msg = msg + "  - $DENIM_HOME/zoom\n"

		return fmt.Errorf(msg)
	}
	return nil
}
