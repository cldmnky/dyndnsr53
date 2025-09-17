package route53

import (
	"context"
	"fmt"

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
	client *route53.Client
	zoneID string
}

// NewRoute53Provider creates a new Route53Provider for a specific hosted zone
func NewRoute53Provider(_ context.Context, zoneID string, awsCfg aws.Config) (*Provider, error) {
	if zoneID == "" {
		return nil, fmt.Errorf("zoneID must not be empty")
	}
	client := route53.NewFromConfig(awsCfg)
	return &Provider{client: client, zoneID: zoneID}, nil
}

// UpdateRecord updates the A record for the given FQDN to the specified IP address
func (p *Provider) UpdateRecord(fqdn, ip string) error {
	if fqdn == "" || ip == "" {
		return fmt.Errorf("fqdn and ip must not be empty")
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

// Helper to load AWS config (optional, for convenience)
func LoadAWSConfig(ctx context.Context) (aws.Config, error) {
	return config.LoadDefaultConfig(ctx)
}
