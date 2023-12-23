package slack

import (
	"fmt"
	"strings"
)

const (
	// ContextVersion is a fixed value.
	ContextVersion = "1.0.0"
)

// slack encapsulates the model that is required to construct a slack.
type Slack struct {
	ContextVersion string `json:"ctxver"`
	AppUri         string `json:"meeting_api"`
	SlackID         string `json:"meeting_id"`
	SlackPWD        string `json:"meeting_pwd"`
}

// New creates a slack from a given id and pwd.
func New(id string, pwd string) *Slack {
	return &Slack{
		ContextVersion: ContextVersion,
		SlackID:         id,
		SlackPWD:        pwd,
	}
}

func Parse(input string) *Slack {
	parts := strings.Fields(input)

	if !strings.HasPrefix(input, "#") && len(parts) > 2 {
		return New(parts[1], parts[2])
	}

	return nil
}

func (z Slack) Classification() string {
	return "Slack"
}

// ID returns the slack id
func (z Slack) ID() string {
	return z.SlackID
}

// PWD returns the slack pwd
func (z Slack) PWD() string {
	return z.SlackPWD
}

// AppURL returns the same value as the BrowserURL
func (z Slack) AppURL() string {
	return fmt.Sprintf("slack://join-huddle?team=%s&id=%s", z.SlackID, z.SlackPWD)
}

// BrowserURL returns a URL that can be used to open a slack in a browser.
func (z Slack) BrowserURL() string {
	return fmt.Sprintf("https://app.slack.com/huddle/%s/%s", z.SlackID, z.SlackPWD)
}

// MeetingURL returns the same value as the BrowserURL
func (z Slack) MeetingURL() string {
	return z.BrowserURL()
}

// Phone returns an empty string, as Hangouts do not implement a dial-in number
func (h Slack) Phone() string {
	return ""
}

// SetUser does nothing as Hangouts do not support modifying the participant name
func (h *Slack) SetUser(user string) {
	// DO NOTHING
}
