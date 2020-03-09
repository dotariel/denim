package hangouts

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

var testCases = []struct {
	input              Hangout
	user               string
	expectedJSON       string
	expectedBrowserURL string
}{
	{
		input:              New("12345"),
		user:               "",
		expectedJSON:       `{"ctxver":"1.0.0","meeting_api":"https://hangouts.google.com/call","meeting_id":"12345"}`,
		expectedBrowserURL: "https://hangouts.google.com/call/12345",
	},
}

func TestAppURL(t *testing.T) {
	for _, tt := range testCases {
		assert.Equal(t, tt.expectedBrowserURL, tt.input.AppURL())
	}
}

func TestBrowserURL(t *testing.T) {
	for _, tt := range testCases {
		assert.Equal(t, tt.expectedBrowserURL, tt.input.BrowserURL())
	}
}
