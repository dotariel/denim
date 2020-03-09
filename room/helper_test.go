package room

import (
	"fmt"
	"io/ioutil"
	"os"
)

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

	touch(tmpDir.UserHome + "/.denim/hangouts")
	touch(tmpDir.AppHome + "/hangouts")
	touch(tmpDir.Root + "/hangouts")

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
