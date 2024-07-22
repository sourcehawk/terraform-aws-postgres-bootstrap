# If you want to temporarily disable history recording for a session, you can start psql with the -n option.
psql -n -v ON_ERROR_STOP=1 <<-EOSQL
BEGIN; -- Start the transaction

DO
\$\$
BEGIN
    IF EXISTS (
        SELECT FROM pg_roles WHERE rolname = '$USERNAME'
    ) THEN
        RAISE NOTICE 'User % already exist, updating password.', '$USERNAME';
        ALTER USER $USERNAME WITH ENCRYPTED PASSWORD '$PASSWORD';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE; -- Re-raise the current exception
END
\$\$;

DO
\$\$
BEGIN
    IF NOT EXISTS (
        SELECT FROM pg_roles WHERE rolname = '$USERNAME'
    ) THEN
        RAISE NOTICE 'User % does not exist, creating user.', '$USERNAME';
        CREATE USER $USERNAME WITH ENCRYPTED PASSWORD '$PASSWORD';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE; -- Re-raise the current exception
END
\$\$;

COMMIT; -- Commit the transaction if all commands were successful
EOSQL