psql -v ON_ERROR_STOP=1 <<-EOSQL
BEGIN; -- Start the transaction

DO
\$\$
BEGIN
    IF EXISTS (
        SELECT 1 FROM pg_database WHERE datname = '$OLD_DB_NAME'
    ) THEN
        RAISE NOTICE 'Renaming database from % to %', '$OLD_DB_NAME', '$NEW_DB_NAME';
        -- Disconnect all users from the old database
        PERFORM pg_terminate_backend(pg_stat_activity.pid)
        FROM pg_stat_activity
        WHERE pg_stat_activity.datname = '$OLD_DB_NAME' AND pid <> pg_backend_pid();

        -- Rename the database
        EXECUTE 'ALTER DATABASE $OLD_DB_NAME RENAME TO $NEW_DB_NAME';
    ELSE
        RAISE NOTICE 'Database % does not exist, skipping rename.', '$OLD_DB_NAME';
    END IF;
END
\$\$;

COMMIT; -- Commit the transaction if all commands were successful
EOSQL