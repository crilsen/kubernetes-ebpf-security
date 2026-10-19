-- Demo-only schema and data. Fictitious content, no real user information.
CREATE TABLE IF NOT EXISTS demo_messages (
    id   SERIAL PRIMARY KEY,
    body TEXT NOT NULL
);

INSERT INTO demo_messages (body)
VALUES ('Hello from PostgreSQL inside the eBPF security lab')
ON CONFLICT DO NOTHING;
