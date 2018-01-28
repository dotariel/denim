package bluejeans

import (
	"encoding/json"
	"fmt"

	base32 "github.com/manifoldco/go-base32"
)

const (
	MeetingAPI     = "https://bluejeans.com"
	ContextVersion = "1.0.0"
)

// Meeting encapsulates the model that is required to construct a bjn:// URL for a meeting
type Meeting struct {
	ContextVersion string `json:"ctxver"`
	MeetingAPI     string `json:"meeting_api"`
	MeetingID      string `json:"meeting_id"`
	RolePasscode   string `json:"role_passcode"`
	ReleaseChannel string `json:"release_channel"`
}

// New creates a Meeting from a given id
func New(id string) Meeting {
	return Meeting{
		ContextVersion: ContextVersion,
		MeetingAPI:     MeetingAPI,
		MeetingID:      id,
		RolePasscode:   "",
		ReleaseChannel: "live",
	}
}

// AppURL returns a URL that can be used to open a meeting using the native BlueJeans app
func (m Meeting) AppURL() string {
	return fmt.Sprintf("bjn://meeting/%s?ctxver=%s", m.encode(), ContextVersion)
}

// BrowserURL returns a URL that can be used to open a meeting in a browser
func (m Meeting) BrowserURL() string {
	return fmt.Sprintf("%s/%s/browser", MeetingAPI, m.MeetingID)
}

func (m Meeting) marshal() string {
	bytes, _ := json.Marshal(m)
	return string(bytes)
}

func (m Meeting) encode() string {
	return base32.EncodeToString([]byte(m.marshal()))
}
