package main

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
)

func TestHealthz(t *testing.T) {
	response := httptest.NewRecorder()
	newHandler("test").ServeHTTP(response, httptest.NewRequest(http.MethodGet, "/healthz", nil))

	if response.Code != http.StatusOK || response.Body.String() != "ok\n" {
		t.Fatalf("healthz: status=%d body=%q", response.Code, response.Body.String())
	}
}

func TestHomeVersionAndMetrics(t *testing.T) {
	handler := newHandler("v0.1.0")
	home := httptest.NewRecorder()
	handler.ServeHTTP(home, httptest.NewRequest(http.MethodGet, "/", nil))

	var payload struct {
		Version string `json:"version"`
	}
	if err := json.Unmarshal(home.Body.Bytes(), &payload); err != nil {
		t.Fatal(err)
	}
	if home.Code != http.StatusOK || payload.Version != "v0.1.0" {
		t.Fatalf("home: status=%d version=%q", home.Code, payload.Version)
	}

	metrics := httptest.NewRecorder()
	handler.ServeHTTP(metrics, httptest.NewRequest(http.MethodGet, "/metrics", nil))
	if metrics.Code != http.StatusOK ||
		!strings.Contains(metrics.Body.String(), "poc_home_requests_total 1\n") {
		t.Fatalf("metrics: status=%d body=%q", metrics.Code, metrics.Body.String())
	}
}
