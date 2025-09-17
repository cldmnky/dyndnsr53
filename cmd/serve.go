package cmd

import (
	"context"
	"fmt"
	"os"

	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/spf13/cobra"

	"github.com/cldmnky/dyndnsr53/pkg/provider"
	"github.com/cldmnky/dyndnsr53/pkg/providers/route53"
	"github.com/cldmnky/dyndnsr53/pkg/server"
)

var serveCmd = &cobra.Command{
	Use:   "serve",
	Short: "Run the DynDNS API server",
	Long:  `Start the DynDNS-compatible API server for updating DNS records.`,
	Run: func(cmd *cobra.Command, _ []string) {
		addr, _ := cmd.Flags().GetString("listen")
		if addr == "" {
			addr = ":8080"
		}

		// Get provider configuration
		providerType, _ := cmd.Flags().GetString("provider")
		zoneID, _ := cmd.Flags().GetString("zone-id")

		var p provider.Provider
		var err error

		switch providerType {
		case "route53":
			if zoneID == "" {
				fmt.Fprintf(os.Stderr, "Error: --zone-id is required when using route53 provider\n")
				os.Exit(1)
			}
			// Load AWS config
			ctx := context.Background()
			cfg, err := config.LoadDefaultConfig(ctx)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error loading AWS config: %v\n", err)
				os.Exit(1)
			}
			p, err = route53.NewRoute53Provider(ctx, zoneID, cfg)
			if err != nil {
				fmt.Fprintf(os.Stderr, "Error creating Route53 provider: %v\n", err)
				os.Exit(1)
			}
			fmt.Printf("Using Route53 provider with zone: %s\n", zoneID)
		case "none", "":
			fmt.Printf("No provider configured - running in test mode\n")
			p = nil
		default:
			fmt.Fprintf(os.Stderr, "Error: unsupported provider type: %s\n", providerType)
			fmt.Fprintf(os.Stderr, "Supported providers: route53, none\n")
			os.Exit(1)
		}

		// Create and start server
		s := server.NewServer(p)
		fmt.Printf("Starting server on %s...\n", addr)
		err = s.StartServer(addr)
		if err != nil {
			fmt.Fprintf(os.Stderr, "Server error: %v\n", err)
			os.Exit(1)
		}
	},
}

func init() {
	serveCmd.Flags().StringP("listen", "l", ":8080", "Address to listen on (default :8080)")
	serveCmd.Flags().StringP("provider", "p", "none", "DNS provider to use (route53, none)")
	serveCmd.Flags().String("zone-id", "", "Route53 hosted zone ID (required for route53 provider)")
	rootCmd.AddCommand(serveCmd)
}
