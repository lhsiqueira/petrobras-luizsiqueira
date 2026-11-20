package main

import (
	"encoding/json"
	"errors"
	"net/http"
	"net/http/httptest"
	"testing"
	"time"
)

func TestRunConfiguresServer(t *testing.T) {
	for _, tt := range []struct {
		name    string
		version string
		want    string
	}{
		{name: "default version", want: "dev"},
		{name: "configured version", version: "v0.1.1", want: "v0.1.1"},
	} {
		t.Run(tt.name, func(t *testing.T) {
			t.Setenv("APP_VERSION", tt.version)
			called := false

			err := run(func(server *http.Server) error {
				called = true
				if server.Addr != ":8080" || server.ReadHeaderTimeout != 5*time.Second {
					t.Fatalf("server configuration: addr=%q timeout=%s",
						server.Addr, server.ReadHeaderTimeout)
				}

				response := httptest.NewRecorder()
				server.Handler.ServeHTTP(response,
					httptest.NewRequest(http.MethodGet, "/", nil))

				var body struct {
					Version string `json:"version"`
				}
				if err := json.Unmarshal(response.Body.Bytes(), &body); err != nil {
					t.Fatal(err)
				}
				if response.Code != http.StatusOK || body.Version != tt.want {
					t.Fatalf("status=%d version=%q, want HTTP 200 and version %q",
						response.Code, body.Version, tt.want)
				}
				return nil
			})

			if err != nil || !called {
				t.Fatalf("run: serve called=%t, error=%v", called, err)
			}
		})
	}
}

func TestRunReturnsServerError(t *testing.T) {
	want := errors.New("listener unavailable")
	err := run(func(*http.Server) error { return want })
	if !errors.Is(err, want) {
		t.Fatalf("run error=%v, want %v", err, want)
	}
}
