package room

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"

	"github.com/dotariel/denim/bluejeans"
	vcard "github.com/emersion/go-vcard"
	log "github.com/sirupsen/logrus"
)

var loaded bool
var rooms []Room

// Room wraps a meeting and provides a name to associate with it.
type Room struct {
	Name string
	bluejeans.Meeting
}

// Load searches the following paths for a room definition file:
//   - $DENIM_ROOMS
//   - $HOME/.denim/rooms
//   - $DENIM_HOME/.denim/rooms
func Load() {
	f := filePath()
	if f == "" {
		log.Warnf("could not locate a file to load")
		return
	}

	bytes, err := ioutil.ReadFile(f)
	if err != nil {
		log.Warnf("file could not be read; %s", f)
		return
	}

	rooms = make([]Room, 0)

	for _, line := range strings.Split(string(bytes), "\n") {
		parts := strings.Fields(line)

		if len(parts) == 2 {
			rooms = append(rooms, Room{Name: parts[0], Meeting: bluejeans.New(parts[1])})

		}
	}
}

// Find returns a room that matches the provided name. The name is not case-sensitive.
func Find(name string) (*Room, error) {
	for _, room := range rooms {
		if strings.ToLower(room.Name) == strings.ToLower(name) {
			return &room, nil
		}
	}

	return nil, fmt.Errorf("room '%v' not found", name)
}

// All returns a list of all the rooms.
func All() []Room {
	return rooms
}

// Export produces a VCF file containing card entries for all the rooms.
func Export(path string, prefix string) (*os.File, error) {
	f, err := os.Create(path)
	if err != nil {
		return nil, err
	}

	enc := vcard.NewEncoder(f)

	for _, room := range rooms {
		c := vcard.Card{}

		c.SetValue(vcard.FieldName, prefix+room.Name)
		c.SetValue(vcard.FieldTelephone, fmt.Sprintf("%s,,%s##", bluejeans.PhoneUSA, room.MeetingID))
		vcard.ToV4(c)

		err := enc.Encode(c)
		if err != nil {
			return nil, err
		}
	}

	return f, nil
}

func filePath() string {
	if fileExists(os.Getenv("DENIM_ROOMS")) {
		return os.Getenv("DENIM_ROOMS")
	}

	if fileExists(os.Getenv("DENIM_HOME") + "/rooms") {
		return os.Getenv("DENIM_HOME") + "/rooms"
	}

	if fileExists(os.Getenv("HOME") + "/.denim/rooms") {
		return os.Getenv("HOME") + "/.denim/rooms"
	}

	return ""
}

func fileExists(path string) bool {
	_, err := ioutil.ReadFile(path)
	if err == nil {
		return true
	}

	return false
}
