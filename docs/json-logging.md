# JSON Request Logging

The DynDNS server now includes comprehensive JSON request logging using klog. Every request is logged with structured data including:

## Log Fields

- `timestamp`: RFC3339 timestamp of the request
- `remote_addr`: Client IP address and port
- `method`: HTTP method (GET expected for DynDNS)
- `user_agent`: Client User-Agent header
- `username`: Authenticated username (if auth successful)
- `fqdn`: Fully qualified domain name being updated
- `ip`: IP address to update the record to
- `status_code`: HTTP response status code
- `response`: DynDNS response message
- `error_message`: Error description (if any)
- `duration`: Request processing time

## Example Logs

### Successful Request
```json
{
  "timestamp": "2025-09-17T20:38:09.588323+02:00",
  "remote_addr": "[::1]:60195",
  "method": "GET",
  "user_agent": "dyndnsr53-client",
  "username": "user",
  "fqdn": "test.example.com",
  "ip": "1.2.3.4",
  "status_code": 200,
  "response": "good 1.2.3.4",
  "error_message": "no provider configured",
  "duration": "37.417µs"
}
```

### Authentication Error
```json
{
  "timestamp": "2025-09-17T20:38:18.029172+02:00",
  "remote_addr": "[::1]:60354",
  "method": "GET",
  "user_agent": "dyndnsr53-client",
  "status_code": 401,
  "response": "badauth",
  "error_message": "invalid credentials",
  "duration": "70.166µs"
}
```

## Usage

The JSON logs are automatically output to stderr when running the server. They can be easily parsed and ingested by log aggregation systems like ELK, Splunk, or cloud logging services.

## Log Processing

These structured logs can be:
- Filtered by status_code for monitoring errors
- Analyzed for response times via the duration field
- Tracked by username for user activity
- Monitored for specific FQDNs or IP addresses
- Used for security analysis via remote_addr and error_message fields