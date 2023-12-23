package room

import (
	"bytes"
	"fmt"
	"io/ioutil"
	"net/http"
	"os"
	"strings"

	"github.com/dotariel/denim/bluejeans"
	"github.com/dotariel/denim/hangouts"
	"github.com/dotariel/denim/zoom"
	"github.com/dotariel/denim/slack"
	vcard "github.com/emersion/go-vcard"
)

var rooms []Room

// Source is the resolved room definition file.
var (
	bluejeansSource string
	hangoutsSource  string
	zoomSource      string
	slackSource      string
)

// Room wraps a meeting and provides a name to associate with it.
type Room struct {
	Session
	Name string
}

// Load searches the following paths for a `rooms` and/or `hangouts` definition file:
//   - $HOME/.denim/
//   - $DENIM_HOME/.denim/
func Load() error {
	rooms = make([]Room, 0)

	bluejeansSource = resolveSource("rooms")
	hangoutsSource = resolveSource("hangouts")
	zoomSource = resolveSource("zoom")
	slackSource = resolveSource("slack")

	loadFromFile(bluejeansSource, bluejeans.Parse)
	loadFromFile(hangoutsSource, hangouts.Parse)
	loadFromFile(zoomSource, zoom.Parse)
	loadFromFile(slackSource, slack.Parse)

	return nil
}

func loadFromFile[T Session](source string, parseFunc func(string) T) error {
	if Loaded(source) {
		bytes, err := read(source)
		if err != nil {
			return err
		}

		for _, line := range strings.Split(string(bytes), "\n") {
			parts := strings.Fields(line)

			if len(parts) > 1 {
				r := Room{
					Name:    parts[0],
					Session: parseFunc(line),
				}

				rooms = append(rooms, r)
			}
		}
	}

	return nil
}

func AnyLoaded() bool {
	return Loaded(bluejeansSource) || Loaded(hangoutsSource) || Loaded(zoomSource)
}

// Loaded indicates if the room data has been loaded
func Loaded(source string) bool {
	return source != ""
}

// Source returns the underlying source of room data
func Source() string {
	return bluejeansSource
}

// All returns a list of all the rooms.
func All() []Room {
	return rooms
}

// Find returns a room that matches the provided identifier (room id or room number).
func Find(identifier string) (Room, error) {
	for _, room := range rooms {
		id := strings.ToLower(identifier)
		if strings.ToLower(room.ID()) == id || strings.ToLower(room.Name) == id {
			return room, nil
		}
	}

	return Room{}, fmt.Errorf("room '%v' not found", identifier)
}

// Export produces a VCF file containing card entries for all the rooms.
func Export(path string, prefix string, legacy bool) (*os.File, error) {
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
		c.SetValue(vcard.FieldVersion, "3.0")

		if !legacy {
			c.SetValue(vcard.FieldVersion, "4.0")
			vcard.ToV4(c)
		}

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
		return fmt.Sprintf("%-15s (%s) Phone: %s", r.Name, r.ID(), r.Phone())
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
This meeting is scheduled in a %v called %v
Dial-in: %v
Meeting URL: %v`

	return fmt.Sprintf(template, r.Name, r.MeetingURL(), r.Phone(), r.Classification(), r.Name, r.Phone(), r.MeetingURL())
}

func resolveSource(file string) string {
	if fileExists(os.Getenv("DENIM_HOME") + "/" + file) {
		return os.Getenv("DENIM_HOME") + "/" + file
	}

	if fileExists(os.Getenv("HOME") + "/.denim/" + file) {
		return os.Getenv("HOME") + "/.denim/" + file
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
		return nil, fmt.Errorf("file could not be read; %s", file)
	}

	return bytes, nil
}

func bytesFromURL(url string) ([]byte, error) {
	r, err := http.Get(url)
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
