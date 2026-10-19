// Command api serves the lab's read-only HTTP API and verifies database reachability.
package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	_ "github.com/jackc/pgx/v5/stdlib"
)

type databaseStatus struct {
	Connected  bool   `json:"connected"`
	Message    string `json:"message,omitempty"`
	ServerTime string `json:"serverTime,omitempty"`
	Error      string `json:"error,omitempty"`
}

type messageResponse struct {
	Service  string         `json:"service"`
	Pod      string         `json:"pod"`
	Message  string         `json:"message"`
	Database databaseStatus `json:"database"`
}

func main() {
	addr := envOr("LISTEN_ADDR", ":8080")
	dsn := dsnFromEnv()

	db, err := sql.Open("pgx", dsn)
	if err != nil {
		log.Fatalf("open database: %v", err)
	}
	db.SetMaxOpenConns(5)
	db.SetMaxIdleConns(2)
	db.SetConnMaxLifetime(5 * time.Minute)

	mux := http.NewServeMux()
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) {
		writeJSON(w, http.StatusOK, map[string]string{"status": "ok"})
	})
	mux.HandleFunc("GET /api/message", func(w http.ResponseWriter, r *http.Request) {
		handleMessage(w, r, db)
	})

	srv := &http.Server{
		Addr:              addr,
		Handler:           mux,
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		log.Printf("api listening on %s", addr)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			log.Fatalf("serve: %v", err)
		}
	}()

	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGINT, syscall.SIGTERM)
	<-stop

	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	if err := srv.Shutdown(ctx); err != nil {
		log.Printf("shutdown: %v", err)
	}
}

func handleMessage(w http.ResponseWriter, r *http.Request, db *sql.DB) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()

	resp := messageResponse{
		Service: "api",
		Pod:     envOr("POD_NAME", "unknown"),
		Message: "Hello from the Kubernetes eBPF Security API",
	}

	var body, serverTime string
	err := db.QueryRowContext(ctx,
		`SELECT body, to_char(now(), 'YYYY-MM-DD HH24:MI:SS TZ') FROM demo_messages ORDER BY id LIMIT 1`,
	).Scan(&body, &serverTime)
	switch {
	case err != nil:
		resp.Database.Error = err.Error()
		resp.Database.Connected = false
	case body == "":
		resp.Database.Connected = true
		resp.Database.Message = "database reachable but empty"
	default:
		resp.Database.Connected = true
		resp.Database.Message = body
		resp.Database.ServerTime = serverTime
	}

	status := http.StatusOK
	if !resp.Database.Connected {
		// The baseline scenario requires a working database path.
		status = http.StatusServiceUnavailable
	}
	writeJSON(w, status, resp)
}

func dsnFromEnv() string {
	return "host=" + envOr("DB_HOST", "postgres") +
		" port=" + envOr("DB_PORT", "5432") +
		" user=" + envOr("DB_USER", "lab") +
		" password=" + envOr("DB_PASSWORD", "lab-demo-password") +
		" dbname=" + envOr("DB_NAME", "lab") +
		" sslmode=disable connect_timeout=3"
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(payload); err != nil {
		log.Printf("encode response: %v", err)
	}
}
