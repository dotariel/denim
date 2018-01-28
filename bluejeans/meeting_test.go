package bluejeans

import "testing"

var meeting = New("12345")

func TestAppURL(t *testing.T) {
	expected := `bjn://meeting/fch66x3retjq48hu48rjwc1e60h2r8kdcnjq8ubecxfp2w3948x24u3mehr76ehf5xh6rxb5d9jp2vkk5thpyv925gh6utb5ehmpwtuzd5j24eh264t36d1n48p24wkfdhjnyw31edtp6vv4cmh3m8h25gh74tbccngq6tazcdm62vkecnp24eh2dhmqct92fm?ctxver=1.0.0`

	if actual := meeting.AppURL(); actual != expected {
		t.Errorf("failed; wanted: %v, but got: %v", expected, actual)
	}
}

func TestBrowserURL(t *testing.T) {
	expected := `https://bluejeans.com/12345/browser`

	if actual := meeting.BrowserURL(); actual != expected {
		t.Errorf("failed; wanted: %v, but got: %v", expected, actual)
	}
}

func TestMarshal(t *testing.T) {
	expected := `{"ctxver":"1.0.0","meeting_api":"https://bluejeans.com","meeting_id":"12345","role_passcode":"","release_channel":"live"}`

	if actual := meeting.marshal(); actual != expected {
		t.Errorf("failed; wanted: %v, but got: %v", expected, actual)
	}
}

func TestEncode(t *testing.T) {
	expected := `fch66x3retjq48hu48rjwc1e60h2r8kdcnjq8ubecxfp2w3948x24u3mehr76ehf5xh6rxb5d9jp2vkk5thpyv925gh6utb5ehmpwtuzd5j24eh264t36d1n48p24wkfdhjnyw31edtp6vv4cmh3m8h25gh74tbccngq6tazcdm62vkecnp24eh2dhmqct92fm`

	if actual := meeting.encode(); actual != expected {
		t.Errorf("failed; wanted: %v, but got: %v", expected, actual)
	}
}
