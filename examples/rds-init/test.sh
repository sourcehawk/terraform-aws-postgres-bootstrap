psql -v ON_ERROR_STOP=1 <<-EOSQL
CREATE TABLE IF NOT EXISTS test.test_sh (
  id SERIAL PRIMARY KEY,
  name VARCHAR(255) NOT NULL,
  created_at TIMESTAMP NOT NULL,
  updated_at TIMESTAMP NOT NULL
);

INSERT INTO test.test_sh (name, created_at, updated_at) VALUES ('$VAR_1', '2023-01-01 00:00:00', '2023-01-01 00:00:00');
INSERT INTO test.test_sh (name, created_at, updated_at) VALUES ('$VAR_2', '2023-01-02 00:00:00', '2023-01-02 00:00:00');
INSERT INTO test.test_sh (name, created_at, updated_at) VALUES ('$USERNAME_2', '2023-01-02 00:00:00', '2023-01-02 00:00:00');

EOSQL