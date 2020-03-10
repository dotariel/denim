package room

type Session interface {
	ID() string
	Classification() string
	BrowserURL() string
	AppURL() string
	MeetingURL() string
	Phone() string
	SetUser(string)
}
