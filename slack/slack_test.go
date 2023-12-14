package slack

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

var testCases = []struct {
	input              *Slack
	expectedAppURL     string
	expectedBrowserURL string
	expectedMeetingURL string
}{
	{
		input:              New("team1", "channel1"),
		expectedAppURL:     "slack://join-huddle?team=team1&id=channel1",
                expectedBrowserURL: "https://app.slack.com/huddle/team1/channel1",
		expectedMeetingURL: "https://app.slack.com/huddle/team1/channel1",
	},
}

func TestParse(t *testing.T) {
	testCases := []struct {
		input    string
		expected *Slack
	}{
		{
			input: "NAME	12345678	abcdefghasdfwefijsdfsd",
			expected: &Slack{
				ContextVersion: ContextVersion,
				SlackID:         "12345678",
				SlackPWD:        "abcdefghasdfwefijsdfsd",
			},
		},
		{
			input:    "# NAME	12345678	abcdefghasdfwefijsdfsd",
			expected: nil,
		},
	}

	for _, tc := range testCases {
		z := Parse(tc.input)
		assert.Equal(t, z, tc.expected)
	}
}

func TestID(t *testing.T) {
	assert.Equal(t, "12345", New("12345", "abcdef").ID())
}

func TestPWD(t *testing.T) {
	assert.Equal(t, "abcdef", New("12345", "abcdef").PWD())
}

func TestClassification(t *testing.T) {
	assert.Equal(t, "Slack", New("12345", "abcdef").Classification())
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

