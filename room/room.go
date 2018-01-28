package room

import (
	"fmt"
	"io/ioutil"
	"os"
	"strings"

	"github.com/dotariel/denim/bluejeans"
	log "github.com/sirupsen/logrus"
)

var loaded bool
var rooms []Room

func load() {
	if !loaded {
		Load()
		loaded = true
	}
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

type Room struct {
	bluejeans.Meeting
	Alias string
}

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
			rooms = append(rooms, Room{Alias: parts[0], Meeting: bluejeans.New(parts[1])})

		}
	}
}

func Find(alias string) (*Room, error) {
	load()
	for _, room := range rooms {
		if strings.ToLower(room.Alias) == strings.ToLower(alias) {
			return &room, nil
		}
	}

	return nil, fmt.Errorf("room '%v' not found", alias)
}

func All() []Room {
	load()
	return rooms
}
