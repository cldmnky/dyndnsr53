package route53

import (
	"context"
	"fmt"
	"strings"

	"github.com/aws/aws-sdk-go-v2/aws"
	"github.com/aws/aws-sdk-go-v2/config"
	"github.com/aws/aws-sdk-go-v2/service/route53"
	"github.com/aws/aws-sdk-go-v2/service/route53/types"

	"github.com/cldmnky/dyndnsr53/pkg/provider"
)

// Route53Provider implements the Provider interface for AWS Route53
var _ provider.Provider = (*Provider)(nil)

// Provider represents a Route53 DNS provider
type Provider struct {
	client   *route53.Client
	zoneID   string
	zoneName string // The domain name of the hosted zone (e.g., "blahonga.me")
}

// NewRoute53Provider creates a new Route53Provider for a specific hosted zone
func NewRoute53Provider(ctx context.Context, zoneID string, awsCfg aws.Config) (*Provider, error) {
	if zoneID == "" {
		return nil, fmt.Errorf("zoneID must not be empty")
	}
	client := route53.NewFromConfig(awsCfg)

	// Get the hosted zone to retrieve the zone name
	zoneResp, err := client.GetHostedZone(ctx, &route53.GetHostedZoneInput{
		Id: aws.String(zoneID),
	})
	if err != nil {
		return nil, fmt.Errorf("failed to get hosted zone %s: %w", zoneID, err)
	}

	zoneName := strings.TrimSuffix(*zoneResp.HostedZone.Name, ".")

	return &Provider{
		client:   client,
		zoneID:   zoneID,
		zoneName: zoneName,
	}, nil
}

// UpdateRecord updates the A record for the given FQDN to the specified IP address
func (p *Provider) UpdateRecord(fqdn, ip string) error {
	if fqdn == "" || ip == "" {
		return fmt.Errorf("fqdn and ip must not be empty")
	}

	// Validate that the FQDN belongs to our hosted zone
	if err := p.validateFQDN(fqdn); err != nil {
		return err
	}

	input := &route53.ChangeResourceRecordSetsInput{
		HostedZoneId: aws.String(p.zoneID),
		ChangeBatch: &types.ChangeBatch{
			Changes: []types.Change{
				{
					Action: types.ChangeActionUpsert,
					ResourceRecordSet: &types.ResourceRecordSet{
						Name:            aws.String(fqdn),
						Type:            types.RRTypeA,
						TTL:             aws.Int64(60),
						ResourceRecords: []types.ResourceRecord{{Value: aws.String(ip)}},
					},
				},
			},
		},
	}
	_, err := p.client.ChangeResourceRecordSets(context.Background(), input)
	return err
}

// validateFQDN ensures the FQDN belongs to the configured hosted zone
func (p *Provider) validateFQDN(fqdn string) error {
	// Remove trailing dot if present
	cleanFQDN := strings.TrimSuffix(fqdn, ".")
	cleanZone := strings.TrimSuffix(p.zoneName, ".")

	// Check if FQDN ends with our zone name
	if !strings.HasSuffix(cleanFQDN, "."+cleanZone) && cleanFQDN != cleanZone {
		return fmt.Errorf("FQDN %s does not belong to hosted zone %s", fqdn, p.zoneName)
	}

	// Additional check: ensure the FQDN doesn't contain the zone name multiple times
	// This prevents cases like "home.blahonga.me.blahonga.me"
	if strings.Count(cleanFQDN, cleanZone) > 1 {
		return fmt.Errorf("FQDN %s contains zone name %s multiple times", fqdn, p.zoneName)
	}

	return nil
}

// Helper to load AWS config (optional, for convenience)
func LoadAWSConfig(ctx context.Context) (aws.Config, error) {
	return config.LoadDefaultConfig(ctx)
}
