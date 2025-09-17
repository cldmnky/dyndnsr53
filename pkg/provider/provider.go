package provider

// Provider defines the interface for DNS providers that can update records.
type Provider interface {
	// UpdateRecord updates the DNS record for the given FQDN to the specified IP address.
	// Returns nil on success, or an error on failure.
	UpdateRecord(fqdn, ip string) error
}
