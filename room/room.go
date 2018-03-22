package room

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"

	"github.com/dotariel/denim/bluejeans"
	"github.com/emersion/go-vcard"
)

var rooms []Room

// Source is the resolved room definition file.
var source string

// Room wraps a meeting and provides a name to associate with it.
type Room struct {
	Name string
	bluejeans.Meeting
}

// Load searches the following paths for a room definition file:
//   - $DENIM_ROOMS (path to a FILE or a URL)
//   - $HOME/.denim/rooms
//   - $DENIM_HOME/.denim/rooms
func Load() error {
	source = resolveSource()
	if !Loaded() {
		return fmt.Errorf("could not resolve room data source")
	}

	bytes, err := read(source)
	if err != nil {
		return err
	}

	rooms = make([]Room, 0)
	for _, line := range strings.Split(string(bytes), "\n") {
		parts := strings.Fields(line)

		if len(parts) > 1 {
			r := Room{
				Name:    parts[0],
				Meeting: bluejeans.New(parts[1]),
			}
			rooms = append(rooms, r)
		}
	}

	return nil
}

// Loaded indicates if the room data has been loaded
func Loaded() bool {
	return source != ""
}

// Source returns the underlying source of room data
func Source() string {
	return source
}

// All returns a list of all the rooms.
func All() []Room {
	return rooms
}

// Find returns a room that matches the provided name. The name is not case-sensitive.
func Find(name string) (Room, error) {
	for _, room := range rooms {
		if strings.ToLower(room.Name) == strings.ToLower(name) {
			return room, nil
		}
	}

	return Room{}, fmt.Errorf("room '%v' not found", name)
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
		c.SetValue(vcard.FieldTelephone, room.Phone())
		c.SetValue(vcard.FieldNote, room.Notes())

		vcard.ToV4(c)

		err := enc.Encode(c)
		if err != nil {
			return nil, err
		}
	}

	return f, nil
}

// Print returns a user-friendly string describing the room.
func (r Room) Print(verbose bool) string {
	if verbose {
		return fmt.Sprintf("%-15s (%s) Phone: %s", r.Name, r.MeetingID, r.Phone())
	}

	return r.Name
}

func (r Room) String() string {
	return r.Print(false)
}

// Notes returns a formated notes portion of the vCard
func (r Room) Notes() string {
	template := `Use for meeting location:
%v: %v
OR
%v

Put in meeting body:
This meeting is scheduled in a BlueJeans Room called %v
Dial-in: %v
Meeting URL: %v`

	return fmt.Sprintf(template, r.Name, r.MeetingURL(), r.Phone(), r.Name, r.Phone(), r.MeetingURL())
}

func resolveSource() string {
	if fileExists(os.Getenv("DENIM_ROOMS")) || isURL(os.Getenv("DENIM_ROOMS")) {
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

func read(path string) ([]byte, error) {
	if isURL(path) {
		return bytesFromURL(path)
	}

	return bytesFromFile(path)
}

func isURL(path string) bool {
	return strings.HasPrefix(path, "http://") || strings.HasPrefix(path, "https://")
}

func bytesFromFile(file string) ([]byte, error) {
	bytes, err := ioutil.ReadFile(file)
	if err != nil {
		return nil, fmt.Errorf("file could not be read; %s", source)
	}

	return bytes, nil
}

func bytesFromURL(url string) ([]byte, error) {
	r, err := http.Get(source)
	if err != nil {
		return nil, err
	}
	defer r.Body.Close()

	if r.StatusCode != 200 {
		return nil, fmt.Errorf("url '%s' source returned an error: %v", url, r.StatusCode)
	}

	buf := new(bytes.Buffer)
	buf.ReadFrom(r.Body)
	return buf.Bytes(), nil
}
