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

// New creates a Meeting from a given id.
func New(id string) Hangout {
	return Hangout{
		ContextVersion: ContextVersion,
		HangoutAPI:     HangoutAPI,
		HangoutID:      id,
	}
}

func (m Hangout) AppURL() string {
	return fmt.Sprintf("%s/%s", HangoutAPI, m.HangoutID)
}

// BrowserURL returns a URL that can be used to open a meeting in a browser.
func (m Hangout) BrowserURL() string {
	return fmt.Sprintf("%s/%s", HangoutAPI, m.HangoutID)
}
