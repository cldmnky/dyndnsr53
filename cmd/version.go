package cmd

import (
	"fmt"

	"github.com/spf13/cobra"
)

// Build information - set via ldflags
var (
	Version   = "dev"
	Commit    = "unknown"
	BuildDate = "unknown"
)

var versionCmd = &cobra.Command{
	Use:   "version",
	Short: "Print version information",
	Long:  `Display version, commit hash, and build date information for dyndnsr53.`,
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Printf("dyndnsr53 version %s\n", Version)
		fmt.Printf("Commit: %s\n", Commit)
		fmt.Printf("Built: %s\n", BuildDate)
	},
}

func init() {
	rootCmd.AddCommand(versionCmd)
}
