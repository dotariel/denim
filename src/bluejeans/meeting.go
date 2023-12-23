package bluejeans

import (
	"encoding/json"
	"fmt"
	"strings"

	base32 "github.com/manifoldco/go-base32"
)

const (
	// ContextVersion is a fixed value.
	ContextVersion = "1.0.0"

	// PhoneUSA is the United States dial-in number for BlueJeans meetings.
	PhoneUSA = "+14087407256"

	// MeetingAPI is the URL to the BlueJeans meeting API.
	MeetingAPI = "https://bluejeans.com"
)

// Meeting encapsulates the model that is required to construct a BlueJeans URL for a meeting.
type Meeting struct {
	ContextVersion string `json:"ctxver"`
	MeetingAPI     string `json:"meeting_api"`
	MeetingID      string `json:"meeting_id"`
	RolePasscode   string `json:"role_passcode"`
	ReleaseChannel string `json:"release_channel"`
	UserFullName   string `json:"user_full_name,omitempty"`
}

// New creates a Meeting from a given id.
func New(id string) *Meeting {
	return &Meeting{
		ContextVersion: ContextVersion,
		MeetingAPI:     MeetingAPI,
		MeetingID:      id,
		RolePasscode:   "",
		ReleaseChannel: "live",
	}
}

func Parse(input string) *Meeting {
	parts := strings.Fields(input)

	if !strings.HasPrefix(input, "#") && len(parts) > 1 {
		return New(parts[1])
	}

	return nil
}

func (m Meeting) Classification() string {
	return "BlueJeans Room"
}

// ID returns the internal ID of the Meeting
func (m Meeting) ID() string {
	return m.MeetingID
}

// AppURL returns a URL that can be used to open a meeting using the native BlueJeans app.
func (m Meeting) AppURL() string {
	return fmt.Sprintf("bjnb://meeting/%s?ctxver=%s", m.encode(), ContextVersion)
}

// BrowserURL returns a URL that can be used to open a meeting in a browser.
func (m Meeting) BrowserURL() string {
	return fmt.Sprintf("%s/%s/webrtc", MeetingAPI, m.MeetingID)
}

// MeetingURL returns a URL that can be used to open a meeting.
func (m Meeting) MeetingURL() string {
	return fmt.Sprintf("%s/%s", MeetingAPI, m.MeetingID)
}

// Phone returns a friendly phone number string that can be used to dial in to a
// meeting.
func (m Meeting) Phone() string {
	return fmt.Sprintf("%s,,%s##", PhoneUSA, m.MeetingID)
}

// SetUser sets the meeting participant.
func (m *Meeting) SetUser(user string) {
	m.UserFullName = user
}

func (m Meeting) marshal() string {
	bytes, _ := json.Marshal(m)
	return string(bytes)
}

func (m Meeting) encode() string {
	return base32.EncodeToString([]byte(m.marshal()))
}
