package server

import (
	"encoding/base64"
	"fmt"
	"io"
	"net/http"
	"net/http/httptest"
	"testing"
)

// MockProvider implements the Provider interface for testing
type MockProvider struct {
	updateCalled bool
	updateError  error
}

func (m *MockProvider) UpdateRecord(_, _ string) error {
	m.updateCalled = true
	return m.updateError
}

func TestDynDNSUpdateHandler_Success(t *testing.T) {
	mockProvider := &MockProvider{}
	server := NewServer(mockProvider)

	req := httptest.NewRequest("GET", "/nic/update?hostname=test.example.com&myip=1.2.3.4", nil)
	req.Header.Set("User-Agent", validUserAgent)
	req.Header.Set("Authorization", "Basic "+base64.StdEncoding.EncodeToString([]byte(fmt.Sprintf("%s:%s", validUser, validPassword))))

	rw := httptest.NewRecorder()

	server.dynDNSUpdateHandler(rw, req)

	resp := rw.Result()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusOK {
		t.Fatalf("expected 200 OK, got %d", resp.StatusCode)
	}
	if got := string(body); got[:4] != "good" {
		t.Errorf("expected response to start with 'good', got %q", got)
	}
	if !mockProvider.updateCalled {
		t.Error("expected provider.UpdateRecord to be called")
	}
}

func TestDynDNSUpdateHandler_BadAuth(t *testing.T) {
	mockProvider := &MockProvider{}
	server := NewServer(mockProvider)

	req := httptest.NewRequest("GET", "/nic/update?hostname=test.example.com&myip=1.2.3.4", nil)
	req.Header.Set("User-Agent", validUserAgent)
	req.Header.Set("Authorization", "Basic "+base64.StdEncoding.EncodeToString([]byte("bad:creds")))

	rw := httptest.NewRecorder()

	server.dynDNSUpdateHandler(rw, req)

	resp := rw.Result()
	body, _ := io.ReadAll(resp.Body)
	if resp.StatusCode != http.StatusUnauthorized {
		t.Fatalf("expected 401 Unauthorized, got %d", resp.StatusCode)
	}
	if got := string(body); got != MsgBadAuth+"\n" {
		t.Errorf("expected %q, got %q", MsgBadAuth+"\n", got)
	}
	if mockProvider.updateCalled {
		t.Error("expected provider.UpdateRecord not to be called")
	}
}

func TestDynDNSUpdateHandler_MissingUserAgent(t *testing.T) {
	mockProvider := &MockProvider{}
	server := NewServer(mockProvider)

	req := httptest.NewRequest("GET", "/nic/update?hostname=test.example.com&myip=1.2.3.4", nil)
	// No User-Agent
	req.Header.Set("Authorization", "Basic "+base64.StdEncoding.EncodeToString([]byte(fmt.Sprintf("%s:%s", validUser, validPassword))))

	rw := httptest.NewRecorder()

	server.dynDNSUpdateHandler(rw, req)

	resp := rw.Result()
	if resp.StatusCode != http.StatusBadRequest {
		t.Fatalf("expected 400 Bad Request, got %d", resp.StatusCode)
	}
}

func TestDynDNSUpdateHandler_MissingParams(t *testing.T) {
	mockProvider := &MockProvider{}
	server := NewServer(mockProvider)

	req := httptest.NewRequest("GET", "/nic/update?myip=1.2.3.4", nil)
	req.Header.Set("User-Agent", validUserAgent)
	req.Header.Set("Authorization", "Basic "+base64.StdEncoding.EncodeToString([]byte(fmt.Sprintf("%s:%s", validUser, validPassword))))

	rw := httptest.NewRecorder()

	server.dynDNSUpdateHandler(rw, req)

	resp := rw.Result()
	body, _ := io.ReadAll(resp.Body)
	if got := string(body); got != MsgNotFQDN+"\n" {
		t.Errorf("expected %q, got %q", MsgNotFQDN+"\n", got)
	}
}
