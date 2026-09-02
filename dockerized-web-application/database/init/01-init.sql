-- Init script for the PostgreSQL container (mounted at /docker-entrypoint-initdb.d/).
-- Runs once on first startup of an empty data volume.

CREATE TABLE IF NOT EXISTS messages (
    id          SERIAL PRIMARY KEY,
    body        TEXT NOT NULL,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

INSERT INTO messages (body)
VALUES ('Hello from PostgreSQL inside Docker!')
ON CONFLICT DO NOTHING;
