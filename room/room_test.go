package room

import (
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/dotariel/denim/hangouts"

	"github.com/dotariel/denim/bluejeans"
	vcard "github.com/emersion/go-vcard"
	"github.com/stretchr/testify/assert"
)

var wd, _ = os.Getwd()

func TestResolveSource(t *testing.T) {
	tmpDir := setup()

	testCases := []struct {
		description string
		env         map[string]string
		expected    string
	}{
		{
			description: "empty all around",
			env:         map[string]string{"DENIM_ROOMS": "", "DENIM_HOME": "", "HOME": ""},
			expected:    "",
		},
		{
			description: "default to $HOME",
			env:         map[string]string{"DENIM_ROOMS": "", "DENIM_HOME": "", "HOME": tmpDir.UserHome},
			expected:    tmpDir.UserHome + "/.denim/rooms",
		},
		{
			description: "override with $DENIM_HOME",
			env:         map[string]string{"DENIM_ROOMS": "", "DENIM_HOME": tmpDir.AppHome, "HOME": tmpDir.UserHome},
			expected:    tmpDir.AppHome + "/rooms",
		},
		{
			description: "override with $DENIM_ROOMS file",
			env:         map[string]string{"DENIM_ROOMS": tmpDir.AppHome + "/rooms", "DENIM_HOME": tmpDir.AppHome, "HOME": tmpDir.UserHome},
			expected:    tmpDir.AppHome + "/rooms",
		},
	}

	for _, tt := range testCases {
		for k, v := range tt.env {
			os.Setenv(k, v)
		}

		assert.Equal(t, tt.expected, resolveSource("rooms"))
	}

	teardown(tmpDir)
}

func TestLoad(t *testing.T) {
	testCases := []struct {
		description string
		input       string
		file        string
		expected    int
	}{
		{description: "bad file", input: "FOO\r\nBAR\r\n", file: "rooms", expected: 0},
		{description: "single", input: "ABC 12345\n", file: "rooms", expected: 1},
		{description: "extra columns", input: "MORE THAN TWO COLUMNS\n", file: "rooms", expected: 1},
		{description: "multiple", input: "ABC 12345\nXYZ 9823", file: "rooms", expected: 2},
		{description: "empty lines", input: "\nABC 12345\n\nXYZ 9823", file: "rooms", expected: 2},
		{description: "single", input: "ABC 12345\n", file: "hangouts", expected: 1},
	}

	for _, tt := range testCases {
		tmp := setup()
		os.Setenv("HOME", tmp.UserHome)
		os.Setenv("DENIM_HOME", tmp.UserHome)
		f := touch(tmp.UserHome + "/" + tt.file) // Create a local file for use
		f.WriteString(tt.input)
		Load()
		assert.Equal(t, tt.expected, len(rooms))
		teardown(tmp)
	}
}

func TestFind(t *testing.T) {
	rooms = []Room{
		{Session: bluejeans.New("12345"), Name: "foo"},
		{Session: bluejeans.New("67890"), Name: "bar"},
	}

	testCases := []struct {
		input    string
		error    bool
		expected bool
	}{
		{input: "foo", error: false, expected: true},
		{input: "Foo", error: false, expected: true},
		{input: "bar", error: false, expected: true},
		{input: "baz", error: true, expected: false},
		{input: "12345", error: false, expected: true},
	}

	for _, tt := range testCases {
		actual, err := Find(tt.input)

		assert.Equal(t, tt.error, (err != nil))
		assert.Equal(t, tt.expected, (actual != Room{}))
	}
}

func TestExport(t *testing.T) {
	tmpDir := setup()

	testCases := []struct {
		description string
		input       []Room
		prefix      string
		legacy      bool
		expected    string
	}{
		{
			description: "single entry without prefix",
			input: []Room{
				{Session: bluejeans.New("12345"), Name: "foo_1"},
			},
			prefix:   "",
			legacy:   false,
			expected: wd + "/testdata/single-noprefix.vcf",
		},
		{
			description: "single entry in legacy format",
			input: []Room{
				{Session: bluejeans.New("12345"), Name: "foo_1"},
			},
			prefix:   "",
			legacy:   true,
			expected: wd + "/testdata/single-legacy.vcf",
		},
		{
			description: "single entry with prefix",
			input: []Room{
				{Session: bluejeans.New("12345"), Name: "foo_1"},
			},
			prefix:   "foo-",
			legacy:   false,
			expected: wd + "/testdata/single-prefix.vcf",
		},
		{
			description: "multiple entries",
			input: []Room{
				{Session: bluejeans.New("12345"), Name: "foo_1"},
				{Session: bluejeans.New("56789"), Name: "bar_1"},
				{Session: hangouts.New("56789"), Name: "hng_1"},
			},
			prefix:   "foo-",
			legacy:   false,
			expected: wd + "/testdata/multiple.vcf",
		},
	}

	for _, tt := range testCases {
		rooms = tt.input
		f, err := Export(tmpDir.Root+"/rooms.vcf", tt.prefix, tt.legacy)

		if err != nil {
			panic(err)
		}

		expFile, _ := os.Open(tt.expected)
		defer expFile.Close()

		actFile, _ := os.Open(f.Name())
		defer actFile.Close()

		expDec := vcard.NewDecoder(expFile)
		actDec := vcard.NewDecoder(actFile)

		for expected, _ := expDec.Decode(); len(expected) > 0; expected, _ = expDec.Decode() {
			actual, _ := actDec.Decode()
			assert.Equal(t, expected, actual)
		}
	}

	teardown(tmpDir)
}

func TestIsURL(t *testing.T) {
	testCases := []struct {
		input    string
		expected bool
	}{
		{input: "", expected: false},
		{input: "/foo", expected: false},
		{input: "http://foo.co/bar", expected: true},
		{input: "https://foo.co/bar", expected: true},
	}

	for _, tt := range testCases {
		assert.Equal(t, tt.expected, isURL(tt.input))
	}
}

func TestPrint(t *testing.T) {
	room := Room{&bluejeans.Meeting{MeetingID: "12345"}, "FOO"}

	testCases := []struct {
		input    Room
		verbose  bool
		expected string
	}{
		{input: room, verbose: false, expected: "FOO"},
		{input: room, verbose: true, expected: "FOO             (12345) Phone: +14087407256,,12345##"},
	}

	for _, tt := range testCases {
		assert.Equal(t, tt.expected, tt.input.Print(tt.verbose))
	}
}

func TestBytesFromURL(t *testing.T) {
	handler := http.HandlerFunc(func(res http.ResponseWriter, req *http.Request) {
		res.Write([]byte("OK"))
	})
	server := httptest.NewServer(handler)
	defer func() { server.Close() }()

	bytes, err := read(server.URL)
	if err != nil {
		t.Error(err)
	}

	assert.Len(t, bytes, 2)
}

func TestSource(t *testing.T) {
	bluejeansSource = "foo"
	assert.Equal(t, Source(), bluejeansSource)
}

func TestAll(t *testing.T) {
	rooms = []Room{
		{Session: bluejeans.New("12345"), Name: "foo_1"},
		{Session: bluejeans.New("67890"), Name: "foo_2"},
	}

	assert.Equal(t, All(), rooms)
}
