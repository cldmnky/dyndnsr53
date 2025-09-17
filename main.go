/*
Copyright © 2025 NAME HERE <EMAIL ADDRESS>
*/
package main

import "github.com/cldmnky/dyndnsr53/cmd"

// Build information set by ldflags
var (
	version   = "dev"
	commit    = "unknown"
	buildDate = "unknown"
)

func main() {
	// Set build information in cmd package
	cmd.Version = version
	cmd.Commit = commit
	cmd.BuildDate = buildDate

	cmd.Execute()
}
