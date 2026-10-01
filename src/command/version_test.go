package command

import (
	"bytes"
	"testing"

	"github.com/dotariel/denim/app"
	"github.com/stretchr/testify/assert"
)

func TestVersion(t *testing.T) {
	testCases := []struct {
		description string
		version     string
		buildDate   string
		expected    string
	}{
		{
			description: "release",
			version:     "0.1.12",
			buildDate:   "2026-09-23T11:22:50-04:00",
			expected:    "denim v0.1.12 (2026-09-23T11:22:50-04:00)\n",
		},
		{
			description: "dev",
			version:     "0.1.13-dev+ae6bb8a",
			buildDate:   "2026-09-23T11:22:50-04:00",
			expected:    "denim v0.1.13-dev+ae6bb8a (2026-09-23T11:22:50-04:00)\n",
		},
	}

	for _, tt := range testCases {
		t.Run(tt.description, func(t *testing.T) {
			origVersion, origBuildDate := app.Version, app.BuildDate
			t.Cleanup(func() { app.Version, app.BuildDate = origVersion, origBuildDate })

			app.Version = tt.version
			app.BuildDate = tt.buildDate

			cmd := Version()
			buf := new(bytes.Buffer)
			cmd.SetOut(buf)
			cmd.Run(cmd, []string{})

			assert.Equal(t, tt.expected, buf.String())
		})
	}
}
