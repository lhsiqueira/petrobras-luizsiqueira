package main

import (
	"encoding/json"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"sync/atomic"
	"time"
)

func newHandler(version string) http.Handler {
	var requests atomic.Uint64
	mux := http.NewServeMux()

	mux.HandleFunc("GET /{$}", func(w http.ResponseWriter, r *http.Request) {
		requests.Add(1)
		w.Header().Set("Content-Type", "application/json")
		_ = json.NewEncoder(w).Encode(map[string]string{
			"app":     "petrobras-luizsiqueira",
			"version": version,
		})
		slog.Info("request", "method", r.Method, "path", r.URL.Path, "status", 200)
	})

	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; charset=utf-8")
		fmt.Fprintln(w, "ok")
	})

	mux.HandleFunc("GET /metrics", func(w http.ResponseWriter, _ *http.Request) {
		w.Header().Set("Content-Type", "text/plain; version=0.0.4; charset=utf-8")
		fmt.Fprintln(w, "# HELP poc_home_requests_total Requests served by the home endpoint.")
		fmt.Fprintln(w, "# TYPE poc_home_requests_total counter")
		fmt.Fprintf(w, "poc_home_requests_total %d\n", requests.Load())
	})

	return mux
}

func main() {
	slog.SetDefault(slog.New(slog.NewJSONHandler(os.Stdout, nil)))

	version := os.Getenv("APP_VERSION")
	if version == "" {
		version = "dev"
	}

	server := &http.Server{
		Addr:              ":8080",
		Handler:           newHandler(version),
		ReadHeaderTimeout: 5 * time.Second,
	}

	slog.Info("server starting", "address", server.Addr, "version", version)
	if err := server.ListenAndServe(); err != nil {
		slog.Error("server stopped", "error", err)
		os.Exit(1)
	}
}
