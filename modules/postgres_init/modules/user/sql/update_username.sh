psql -v ON_ERROR_STOP=1 <<-EOSQL
BEGIN; -- Start the transaction

DO
\$\$
BEGIN
    IF EXISTS (
        SELECT FROM pg_roles WHERE rolname = '$OLD_USERNAME'
    ) THEN
        RAISE NOTICE 'Renaming user from % to %', '$OLD_USERNAME', '$NEW_USERNAME';
        ALTER USER $OLD_USERNAME RENAME TO $NEW_USERNAME;
    ELSE
        RAISE NOTICE 'User % does not exist, skipping rename.', '$OLD_USERNAME';
    END IF;
EXCEPTION
    WHEN OTHERS THEN
        RAISE; -- Re-raise the current exception
END
\$\$;

COMMIT; -- Commit the transaction if all commands were successful
EOSQL