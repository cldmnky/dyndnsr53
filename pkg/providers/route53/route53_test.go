package route53

import (
	"context"
	"testing"

	"github.com/aws/aws-sdk-go-v2/aws"
)

func TestNewRoute53Provider(t *testing.T) {
	cfg := aws.Config{Region: "us-east-1"}

	// Test with valid zone ID
	provider, err := NewRoute53Provider(context.Background(), "Z1234567890", cfg)
	if err != nil {
		t.Fatalf("expected no error, got %v", err)
	}
	if provider == nil {
		t.Fatal("expected provider to be non-nil")
	}
	if provider.zoneID != "Z1234567890" {
		t.Errorf("expected zoneID to be Z1234567890, got %s", provider.zoneID)
	}

	// Test with empty zone ID
	_, err = NewRoute53Provider(context.Background(), "", cfg)
	if err == nil {
		t.Fatal("expected error for empty zoneID")
	}
}

func TestUpdateRecord_ValidationErrors(t *testing.T) {
	cfg := aws.Config{Region: "us-east-1"}
	provider, _ := NewRoute53Provider(context.Background(), "Z1234567890", cfg)

	// Test with empty FQDN
	err := provider.UpdateRecord("", "1.2.3.4")
	if err == nil {
		t.Fatal("expected error for empty fqdn")
	}

	// Test with empty IP
	err = provider.UpdateRecord("test.example.com", "")
	if err == nil {
		t.Fatal("expected error for empty ip")
	}
}
