package room

import (
	"fmt"
	"io/ioutil"
	"os"
	"reflect"
	"testing"

	"github.com/dotariel/denim/bluejeans"
	vcard "github.com/emersion/go-vcard"
)

var wd string

func init() {
	wd, _ = os.Getwd()
}

func TestFilePath(t *testing.T) {
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
			description: "override with $DENIM_ROOMS",
			env:         map[string]string{"DENIM_ROOMS": tmpDir.AppHome + "/rooms", "DENIM_HOME": tmpDir.AppHome, "HOME": tmpDir.UserHome},
			expected:    tmpDir.AppHome + "/rooms",
		},
	}

	for _, tt := range testCases {

		for k, v := range tt.env {
			os.Setenv(k, v)
		}

		if actual := filePath(); actual != tt.expected {
			t.Errorf("'%v' failed; wanted: %v, but got: %v", tt.description, tt.expected, actual)
		}
	}

	teardown(tmpDir)
}

func TestLoad(t *testing.T) {
	tmp := setup()

	testCases := []struct {
		description string
		input       string
		expected    int
	}{
		{description: "single", input: "ABC 12345\n", expected: 1},
		{description: "multiple", input: "ABC 12345\nXYZ 9823", expected: 2},
		{description: "empty lines", input: "\nABC 12345\n\nXYZ 9823", expected: 2},
	}

	for _, tt := range testCases {
		f := touch(tmp.Root + "/rooms") // Create a local file for use
		os.Setenv("DENIM_ROOMS", f.Name())
		f.WriteString(tt.input)

		Load()

		if actual := len(rooms); actual != tt.expected {
			t.Errorf("'%v' failed; wanted: %v, but got: %v", tt.description, tt.expected, actual)
		}
	}

	teardown(tmp)
}

func TestFind(t *testing.T) {
	rooms = []Room{
		Room{Meeting: bluejeans.New("12345"), Name: "foo"},
		Room{Meeting: bluejeans.New("67890"), Name: "bar"},
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
	}

	for _, tt := range testCases {
		actual, err := Find(tt.input)

		if (err != nil) != tt.error {
			t.Errorf("expected error mismatch; wanted: %v, but got: %v", tt.error, err != nil)
		}

		if (actual != nil) != tt.expected {
			t.Errorf("failed expectation; wanted: %v, but got: %v", tt.expected, actual)
		}
	}
}

func TestExport(t *testing.T) {
	tmpDir := setup()

	testCases := []struct {
		description string
		input       []Room
		prefix      string
		expected    string
	}{
		{
			description: "single entry without prefix",
			input: []Room{
				Room{Meeting: bluejeans.New("12345"), Name: "foo_1"},
			},
			prefix:   "",
			expected: wd + "/fixtures/single-noprefix.vcf",
		},
		{
			description: "single entry with prefix",
			input: []Room{
				Room{Meeting: bluejeans.New("12345"), Name: "foo_1"},
			},
			prefix:   "foo-",
			expected: wd + "/fixtures/single-prefix.vcf",
		},
		{
			description: "multiple entries",
			input: []Room{
				Room{Meeting: bluejeans.New("12345"), Name: "foo_1"},
				Room{Meeting: bluejeans.New("12345"), Name: "bar_1"},
			},
			prefix:   "foo-",
			expected: wd + "/fixtures/multiple.vcf",
		},
	}

	for _, tt := range testCases {
		rooms = tt.input
		f, err := Export(tmpDir.Root+"/rooms.vcf", tt.prefix)

		if err != nil {
			panic(err)
		}

		expFile, _ := os.Open(tt.expected)
		defer expFile.Close()

		actFile, _ := os.Open(f.Name())
		defer actFile.Close()

		actual, _ := vcard.NewDecoder(actFile).Decode()
		expected, _ := vcard.NewDecoder(expFile).Decode()

		if !reflect.DeepEqual(actual, expected) {
			t.Errorf("'%s' failed; wanted:%v, but got:%v", tt.description, expected, actual)
		}
	}

	teardown(tmpDir)
}

type TmpDirectory struct {
	Root     string
	UserHome string
	AppHome  string
}

func setup() TmpDirectory {
	t, err := ioutil.TempDir("", "denim-test")
	if err != nil {
		panic(err)
	}

	tmpDir := TmpDirectory{
		Root:     t,
		UserHome: t + "/HOME",
		AppHome:  t + "/DENIM_HOME",
	}

	os.MkdirAll(tmpDir.AppHome, os.ModePerm)
	os.MkdirAll(tmpDir.UserHome+"/.denim", os.ModePerm)
	touch(tmpDir.UserHome + "/.denim/rooms")
	touch(tmpDir.AppHome + "/rooms")
	touch(tmpDir.Root + "/rooms")

	return tmpDir
}

func touch(path string) *os.File {
	if path != "" {
		f, err := os.Create(path)
		if err != nil {
			fmt.Println("Could not touch file;", err)
		}
		return f
	}

	return nil
}

func teardown(dir TmpDirectory) {
	os.RemoveAll(dir.Root)
}
