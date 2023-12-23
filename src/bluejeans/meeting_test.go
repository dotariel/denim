package bluejeans

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

var testCases = []struct {
	input              *Meeting
	user               string
	expectedJSON       string
	expectedBrowserURL string
	expectedMeetingURL string
	expectedAppURL     string
	expectedPhone      string
}{
	{
		input:              New("12345"),
		user:               "",
		expectedJSON:       `{"ctxver":"1.0.0","meeting_api":"https://bluejeans.com","meeting_id":"12345","role_passcode":"","release_channel":"live"}`,
		expectedBrowserURL: "https://bluejeans.com/12345/webrtc",
		expectedMeetingURL: "https://bluejeans.com/12345",
		expectedAppURL:     "bjnb://meeting/fch66x3retjq48hu48rjwc1e60h2r8kdcnjq8ubecxfp2w3948x24u3mehr76ehf5xh6rxb5d9jp2vkk5thpyv925gh6utb5ehmpwtuzd5j24eh264t36d1n48p24wkfdhjnyw31edtp6vv4cmh3m8h25gh74tbccngq6tazcdm62vkecnp24eh2dhmqct92fm?ctxver=1.0.0",
		expectedPhone:      "+14087407256,,12345##",
	},
	{
		input:              New("12345"),
		user:               "John Doe",
		expectedJSON:       `{"ctxver":"1.0.0","meeting_api":"https://bluejeans.com","meeting_id":"12345","role_passcode":"","release_channel":"live","user_full_name":"John Doe"}`,
		expectedBrowserURL: "https://bluejeans.com/12345/webrtc",
		expectedMeetingURL: "https://bluejeans.com/12345",
		expectedAppURL:     "bjnb://meeting/fch66x3retjq48hu48rjwc1e60h2r8kdcnjq8ubecxfp2w3948x24u3mehr76ehf5xh6rxb5d9jp2vkk5thpyv925gh6utb5ehmpwtuzd5j24eh264t36d1n48p24wkfdhjnyw31edtp6vv4cmh3m8h25gh74tbccngq6tazcdm62vkecnp24eh2dhmqct925gh7awv5e9fpcxbcdhfpwrbdcmh3m8jadxm6w824dxjj4z8?ctxver=1.0.0",
		expectedPhone:      "+14087407256,,12345##",
	},
}

func TestParse(t *testing.T) {
	testCases := []struct {
		input    string
		expected *Meeting
	}{
		{
			input: "NAME	12345678",
			expected: &Meeting{
				ContextVersion: ContextVersion,
				MeetingAPI:     MeetingAPI,
				MeetingID:      "12345678",
				RolePasscode:   "",
				ReleaseChannel: "live",
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
	assert.Equal(t, "BlueJeans Room", New("12345").Classification())
}

func TestAppURL(t *testing.T) {
	for _, tt := range testCases {
		tt.input.SetUser(tt.user)
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
		assert.Equal(t, tt.expectedPhone, tt.input.Phone())
	}
}

func TestMarshal(t *testing.T) {
	for _, tt := range testCases {
		tt.input.SetUser(tt.user)
		assert.Equal(t, tt.expectedJSON, tt.input.marshal())
	}
}
