package zoom

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

var testCases = []struct {
	input              *Zoom
	user               string
	expectedJSON       string
	expectedAppURL     string
	expectedBrowserURL string
	expectedMeetingURL string
	expectedPhoneUS    string
}{
	{
		input:              New("12345", "abcdef"),
		user:               "",
		expectedJSON:       `{"ctxver":"1.0.0","meeting_api":"https://stackct.zoom.us/j/","meeting_id":"12345", "meeting_pwd":"abcdef"}`,
		expectedAppURL:     "https://stackct.zoom.us/j/12345?pwd=abcdef",
		expectedBrowserURL: "https://stackct.zoom.us/j/12345?pwd=abcdef",
		expectedMeetingURL: "https://stackct.zoom.us/j/12345?pwd=abcdef",
		expectedPhoneUS:    "+16468769923,,12345#",
	},
}

func TestID(t *testing.T) {
	assert.Equal(t, "12345", New("12345", "abcdef").ID())
}

func TestPWD(t *testing.T) {
	assert.Equal(t, "abcdef", New("12345", "abcdef").PWD())
}

func TestClassification(t *testing.T) {
	assert.Equal(t, "Zoom", New("12345", "abcdef").Classification())
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
	for _, tt := range testCases {
		assert.Equal(t, tt.expectedPhoneUS, New("12345", "abcdef").Phone())
	}
}
