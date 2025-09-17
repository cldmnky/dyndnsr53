package server

import (
	"encoding/base64"
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"strings"
	"time"

	"k8s.io/klog/v2"

	"github.com/cldmnky/dyndnsr53/pkg/provider"
)

// DynDNS return codes/messages
const (
	MsgGood       = "good"
	MsgNoChg      = "nochg"
	MsgBadAuth    = "badauth"
	MsgNotDonator = "!donator"
	MsgNotFQDN    = "nofqdn"
	MsgNoHost     = "nohost"
	MsgNumHost    = "numhost"
	MsgAbuse      = "abuse"
	MsgBadAgent   = "badagent"
	MsgDNSErr     = "dnserr"
	Msg911        = "911"
)

// RequestLog represents a structured log entry for DynDNS requests
type RequestLog struct {
	Timestamp    time.Time `json:"timestamp"`
	RemoteAddr   string    `json:"remote_addr"`
	Method       string    `json:"method"`
	UserAgent    string    `json:"user_agent"`
	Username     string    `json:"username,omitempty"`
	FQDN         string    `json:"fqdn,omitempty"`
	IP           string    `json:"ip,omitempty"`
	StatusCode   int       `json:"status_code"`
	Response     string    `json:"response"`
	ErrorMessage string    `json:"error_message,omitempty"`
	Duration     string    `json:"duration"`
}

// Example: hardcoded credentials and user agent for demonstration
var (
	validUser      = "user"
	validPassword  = "pass"
	validUserAgent = "dyndnsr53-client"
)

// Server holds the DNS provider and configuration
type Server struct {
	provider provider.Provider
}

// NewServer creates a new server with the given provider
func NewServer(p provider.Provider) *Server {
	return &Server{provider: p}
}

// StartServer starts the HTTP server with DynDNS-compatible handler (deprecated, use NewServer().StartServer())
func StartServer(addr string) error {
	// Create a server with no provider for backward compatibility
	s := &Server{provider: nil}
	return s.StartServer(addr)
}

// StartServerWithProvider starts the HTTP server with the given provider
func (s *Server) StartServer(addr string) error {
	http.HandleFunc("/nic/update", s.dynDNSUpdateHandler)
	slog.Info("Starting DynDNS API server", "addr", addr)
	return http.ListenAndServe(addr, nil)
}

func (s *Server) dynDNSUpdateHandler(w http.ResponseWriter, r *http.Request) {
	startTime := time.Now()

	// Initialize request log
	reqLog := &RequestLog{
		Timestamp:  startTime,
		RemoteAddr: r.RemoteAddr,
		Method:     r.Method,
		UserAgent:  r.Header.Get("User-Agent"),
	}

	// Helper function to log and respond
	logAndRespond := func(statusCode int, message, errorMsg string) {
		reqLog.StatusCode = statusCode
		reqLog.Response = message
		reqLog.ErrorMessage = errorMsg
		reqLog.Duration = time.Since(startTime).String()

		// Log as JSON using klog
		if logData, err := json.Marshal(reqLog); err == nil {
			klog.InfoS("DynDNS request", "request", string(logData))
		}

		if statusCode != http.StatusOK {
			w.WriteHeader(statusCode)
		}
		fmt.Fprintln(w, message)
	}

	log := slog.Default().With("remote", r.RemoteAddr)

	// Check User-Agent
	ua := r.Header.Get("User-Agent")
	if ua == "" || !strings.Contains(ua, validUserAgent) {
		log.Warn("bad user agent", "user-agent", ua)
		logAndRespond(http.StatusBadRequest, MsgBadAgent, "invalid user agent")
		return
	}

	// Check HTTP method (should be GET)
	if r.Method != http.MethodGet {
		log.Warn("bad method", "method", r.Method)
		logAndRespond(http.StatusMethodNotAllowed, MsgBadAgent, "method not allowed")
		return
	}

	// Check Basic Auth
	auth := r.Header.Get("Authorization")
	if !strings.HasPrefix(auth, "Basic ") {
		log.Warn("missing auth header")
		logAndRespond(http.StatusUnauthorized, MsgBadAuth, "missing authorization header")
		return
	}
	payload, err := base64.StdEncoding.DecodeString(strings.TrimPrefix(auth, "Basic "))
	if err != nil {
		log.Warn("bad base64 in auth header")
		logAndRespond(http.StatusUnauthorized, MsgBadAuth, "invalid base64 in auth header")
		return
	}
	parts := strings.SplitN(string(payload), ":", 2)
	if len(parts) != 2 || parts[0] != validUser || parts[1] != validPassword {
		log.Warn("bad credentials", "user", parts[0])
		logAndRespond(http.StatusUnauthorized, MsgBadAuth, "invalid credentials")
		return
	}

	// Set username in log
	reqLog.Username = parts[0]

	// Parse query params
	fqdn := r.URL.Query().Get("hostname")
	ip := r.URL.Query().Get("myip")
	reqLog.FQDN = fqdn
	reqLog.IP = ip

	if fqdn == "" {
		log.Warn("missing fqdn")
		logAndRespond(http.StatusOK, MsgNotFQDN, "missing hostname parameter")
		return
	}
	if ip == "" {
		log.Warn("missing ip")
		logAndRespond(http.StatusOK, MsgDNSErr, "missing myip parameter")
		return
	}

	// Use the provider to update the DNS record
	log.Info("update request", "fqdn", fqdn, "ip", ip)
	if s.provider != nil {
		if err := s.provider.UpdateRecord(fqdn, ip); err != nil {
			log.Error("failed to update DNS record", "error", err)
			logAndRespond(http.StatusOK, MsgDNSErr, fmt.Sprintf("provider error: %v", err))
			return
		}
		logAndRespond(http.StatusOK, fmt.Sprintf("%s %s", MsgGood, ip), "")
	} else {
		// Fallback for when no provider is configured
		log.Warn("no provider configured, returning success without update")
		logAndRespond(http.StatusOK, fmt.Sprintf("%s %s", MsgGood, ip), "no provider configured")
	}
}
