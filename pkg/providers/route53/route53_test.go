package route53

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
)

func TestNewRoute53Provider(t *testing.T) {
	// Test with empty zone ID
	_, err := NewRoute53Provider(context.Background(), "", aws.Config{})
	if err == nil {
		t.Fatal("expected error for empty zoneID")
	}

	// Note: Testing with valid zone ID would require actual AWS API call,
	// so we skip that in unit tests. Integration tests should cover this.
}

func TestUpdateRecord_ValidationErrors(t *testing.T) {
	// Create a provider with a mock zone name for testing
	provider := &Provider{
		client:   nil, // We won't call Route53 API in these tests
		zoneID:   "Z1234567890",
		zoneName: "blahonga.me",
	}

	// Test with empty FQDN
	err := provider.UpdateRecord("", "1.2.3.4")
	if err == nil {
		t.Fatal("expected error for empty fqdn")
	}

	// Test with empty IP
	err = provider.UpdateRecord("home.blahonga.me", "")
	if err == nil {
		t.Fatal("expected error for empty ip")
	}

	// Test with invalid FQDN (different zone)
	err = provider.UpdateRecord("home.example.com", "1.2.3.4")
	if err == nil {
		t.Fatal("expected error for FQDN not in zone")
	}
}

func TestValidateFQDN(t *testing.T) {
	provider := &Provider{
		client:   nil,
		zoneID:   "Z1234567890",
		zoneName: "blahonga.me",
	}

	tests := []struct {
		name    string
		fqdn    string
		wantErr bool
	}{
		{
			name:    "valid subdomain",
			fqdn:    "home.blahonga.me",
			wantErr: false,
		},
		{
			name:    "valid subdomain with trailing dot",
			fqdn:    "home.blahonga.me.",
			wantErr: false,
		},
		{
			name:    "valid apex domain",
			fqdn:    "blahonga.me",
			wantErr: false,
		},
		{
			name:    "valid apex domain with trailing dot",
			fqdn:    "blahonga.me.",
			wantErr: false,
		},
		{
			name:    "invalid domain - different zone",
			fqdn:    "home.example.com",
			wantErr: true,
		},
		{
			name:    "invalid domain - would create double zone",
			fqdn:    "home.blahonga.me.blahonga.me",
			wantErr: true,
		},
		{
			name:    "valid deep subdomain",
			fqdn:    "api.v1.home.blahonga.me",
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := provider.validateFQDN(tt.fqdn)
			if (err != nil) != tt.wantErr {
				t.Errorf("validateFQDN() error = %v, wantErr %v", err, tt.wantErr)
			}
		})
	}
}
