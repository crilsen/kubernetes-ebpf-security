package main

import "testing"

func TestEnvOr(t *testing.T) {
	t.Setenv("LAB_TEST_VALUE", "set")
	if got := envOr("LAB_TEST_VALUE", "fallback"); got != "set" {
		t.Fatalf("envOr returned %q, want %q", got, "set")
	}
	if got := envOr("LAB_TEST_UNSET", "fallback"); got != "fallback" {
		t.Fatalf("envOr returned %q, want %q", got, "fallback")
	}
}

func TestDSNFromEnvDefaults(t *testing.T) {
	t.Setenv("DB_HOST", "")
	dsn := dsnFromEnv()
	if dsn == "" {
		t.Fatal("dsnFromEnv returned an empty DSN")
	}
	want := "host=postgres"
	if len(dsn) < len(want) || dsn[:len(want)] != want {
		t.Fatalf("dsn %q does not start with %q", dsn, want)
	}
}
