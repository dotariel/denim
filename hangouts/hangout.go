package hangouts

import "fmt"

const (
	// ContextVersion is a fixed value.
	ContextVersion = "1.0.0"

	// HangoutAPI is the URL to the Hangouts page.
	HangoutAPI = "https://hangouts.google.com/call"
)

// Hangout encapsulates the model that is required to construct a Hangout.
type Hangout struct {
	ContextVersion string `json:"ctxver"`
	HangoutAPI     string `json:"meeting_api"`
	HangoutID      string `json:"meeting_id"`
}

// New creates a Hangout from a given id.
func New(id string) *Hangout {
	return &Hangout{
		ContextVersion: ContextVersion,
		HangoutAPI:     HangoutAPI,
		HangoutID:      id,
	}
}

func (h Hangout) Classification() string {
	return "Hangout"
}

// ID returns the Hangout id
func (h Hangout) ID() string {
	return h.HangoutID
}

// AppURL returns the same value as the BrowserURL
func (h Hangout) AppURL() string {
	return h.BrowserURL()
}

// BrowserURL returns a URL that can be used to open a hangout in a browser.
func (h Hangout) BrowserURL() string {
	return fmt.Sprintf("%s/%s", HangoutAPI, h.HangoutID)
}

// MeetingURL returns the same value as the BrowserURL
func (h Hangout) MeetingURL() string {
	return h.BrowserURL()
}

// Phone returns an empty string, as Hangouts do not implement a dial-in number
func (h Hangout) Phone() string {
	return ""
}

// SetUser does nothing as Hangouts do not support modifying the participant name
func (h *Hangout) SetUser(user string) {
	// DO NOTHING
}
