BEGIN;
CREATE TABLE IF NOT EXISTS test_sql (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

INSERT INTO test_sql (name, created_at, updated_at) VALUES (:'some_name1', '2023-01-01 00:00:00', '2023-01-01 00:00:00');
INSERT INTO test_sql (name, created_at, updated_at) VALUES (:'some_name2', '2023-01-02 00:00:00', '2023-01-02 00:00:00');
INSERT INTO test_sql (name, created_at, updated_at) VALUES (:'username_1', '2023-01-02 00:00:00', '2023-01-02 00:00:00');
COMMIT;