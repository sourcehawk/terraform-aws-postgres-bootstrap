psql -v ON_ERROR_STOP=1 <<-EOSQL
BEGIN;

CREATE OR REPLACE FUNCTION ${FUNCTION_NAME}() 
RETURNS VARCHAR AS 
\$\$
BEGIN
  RETURN '${RETURN_VALUE}';
END;
\$\$ 
LANGUAGE plpgsql;

END;
EOSQL