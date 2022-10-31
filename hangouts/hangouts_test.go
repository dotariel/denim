package hangouts

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

var testCases = []struct {
	input              *Hangout
	user               string
	expectedJSON       string
	expectedAppURL     string
	expectedBrowserURL string
	expectedMeetingURL string
}{
	{
		input:              New("12345"),
		user:               "",
		expectedJSON:       `{"ctxver":"1.0.0","meeting_api":"https://hangouts.google.com/call","meeting_id":"12345"}`,
		expectedAppURL:     "https://hangouts.google.com/call/12345",
		expectedBrowserURL: "https://hangouts.google.com/call/12345",
		expectedMeetingURL: "https://hangouts.google.com/call/12345",
	},
}

func TestParse(t *testing.T) {
	testCases := []struct {
		input    string
		expected *Hangout
	}{
		{
			input: "NAME	12345678",
			expected: &Hangout{
				ContextVersion: ContextVersion,
				HangoutAPI:     HangoutAPI,
				HangoutID:      "12345678",
			},
		},
		{
			input:    "# NAME	12345678",
			expected: nil,
		},
	}

	for _, tc := range testCases {
		z := Parse(tc.input)
		assert.Equal(t, z, tc.expected)
	}
}

func TestID(t *testing.T) {
	assert.Equal(t, "12345", New("12345").ID())
}

func TestClassification(t *testing.T) {
	assert.Equal(t, "Hangout", New("12345").Classification())
}

func TestAppURL(t *testing.T) {
	for _, tt := range testCases {
		assert.Equal(t, tt.expectedAppURL, tt.input.AppURL())
	}
}

func TestBrowserURL(t *testing.T) {
	for _, tt := range testCases {
		assert.Equal(t, tt.expectedBrowserURL, tt.input.BrowserURL())
	}
}

func TestMeetingURL(t *testing.T) {
	for _, tt := range testCases {
		assert.Equal(t, tt.expectedMeetingURL, tt.input.MeetingURL())
	}
}

func TestPhone(t *testing.T) {
	assert.Equal(t, "", New("12345").Phone())
}
