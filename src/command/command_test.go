package command

import (
	"os"
	"path/filepath"
	"testing"

	"github.com/dotariel/denim/room"
	"github.com/stretchr/testify/assert"
)

func TestValidateSource(t *testing.T) {
	const noRoomDataMsg = "room data could not be loaded from any of the following locations:\n" +
		"  - $DENIM_ROOMS\n" +
		"  - $HOME/.denim/rooms\n" +
		"  - $DENIM_HOME/rooms\n" +
		"  - $HOME/.denim/hangouts\n" +
		"  - $DENIM_HOME/hangouts\n" +
		"  - $HOME/.denim/zoom\n" +
		"  - $DENIM_HOME/zoom\n"

	testCases := []struct {
		description  string
		createRoomsFile bool
		expectError  bool
	}{
		{
			description:     "no room sources",
			createRoomsFile: false,
			expectError:     true,
		},
		{
			description:     "rooms file under DENIM_HOME",
			createRoomsFile: true,
			expectError:     false,
		},
	}

	for _, tt := range testCases {
		t.Run(tt.description, func(t *testing.T) {
			dir := t.TempDir()
			t.Setenv("HOME", dir)
			t.Setenv("DENIM_HOME", dir)
			t.Setenv("DENIM_ROOMS", "")

			if tt.createRoomsFile {
				err := os.WriteFile(filepath.Join(dir, "rooms"), []byte{}, 0644)
				assert.NoError(t, err)
			}

			room.Load()

			err := validateSource(nil, nil)

			if tt.expectError {
				assert.EqualError(t, err, noRoomDataMsg)
			} else {
				assert.NoError(t, err)
			}
		})
	}
}
