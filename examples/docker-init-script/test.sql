BEGIN;

CREATE TABLE IF NOT EXISTS test_sql (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

INSERT INTO test_sql (name, created_at, updated_at) VALUES (:'VAR_1', '2024-01-01 00:00:00', '2024-01-01 00:00:00');
INSERT INTO test_sql (name, created_at, updated_at) VALUES (:'SECRET_1', '2024-01-02 00:00:00', '2024-01-02 00:00:00');

COMMIT;