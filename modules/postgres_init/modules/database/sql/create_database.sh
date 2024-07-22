# Create database statement is special case and cannot be done in a transaction block
# Thats why we're using the gexec command and using shell script
psql -v ON_ERROR_STOP=1 <<-EOSQL
SELECT 'CREATE DATABASE $DATABASE_NAME' WHERE NOT EXISTS (SELECT FROM pg_database WHERE datname = '$DATABASE_NAME')\gexec
ALTER DATABASE $DATABASE_NAME OWNER TO $DATABASE_OWNER;
GRANT ALL PRIVILEGES ON DATABASE $DATABASE_NAME TO $DATABASE_OWNER;
EOSQL
