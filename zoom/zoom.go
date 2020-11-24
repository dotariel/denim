package zoom

import "fmt"

const (
	// ContextVersion is a fixed value.
	ContextVersion = "1.0.0"

	// ZoomAPI is the URL to the Zooms page.
	ZoomAPI  = "https://stackct.zoom.us/j"
	PhoneUSA = "+16468769923"
)

// zoom encapsulates the model that is required to construct a zoom.
type Zoom struct {
	ContextVersion string `json:"ctxver"`
	ZoomAPI        string `json:"meeting_api"`
	ZoomID         string `json:"meeting_id"`
	ZoomPWD        string `json:"meeting_pwd"`
}

// New creates a zoom from a given id and pwd.
func New(id string, pwd string) *Zoom {
	return &Zoom{
		ContextVersion: ContextVersion,
		ZoomAPI:        ZoomAPI,
		ZoomID:         id,
		ZoomPWD:        pwd,
	}
}

func (z Zoom) Classification() string {
	return "Zoom"
}

// ID returns the Zoom id
func (z Zoom) ID() string {
	return z.ZoomID
}

// PWD returns the Zoom pwd
func (z Zoom) PWD() string {
	return z.ZoomPWD
}

// AppURL returns the same value as the BrowserURL
func (z Zoom) AppURL() string {
	return z.BrowserURL()
}

// BrowserURL returns a URL that can be used to open a Zoom in a browser.
func (z Zoom) BrowserURL() string {
	return fmt.Sprintf("%s/%s?pwd=%s", ZoomAPI, z.ZoomID, z.ZoomPWD)
}

// MeetingURL returns the same value as the BrowserURL
func (z Zoom) MeetingURL() string {
	return z.BrowserURL()
}

// Phone returns an empty string, as Zooms do not implement a dial-in number
func (z Zoom) Phone() string {
	return fmt.Sprintf("%s,,%s#", PhoneUSA, z.ZoomID)
}

// SetUser does nothing as Zooms do not support modifying the participant name
func (z *Zoom) SetUser(user string) {
	// DO NOTHING
}
