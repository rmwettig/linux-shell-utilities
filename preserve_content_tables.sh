#!/bin/bash
if [[ "$#" -ne 1 ]]; then
  echo "Missing parameter. Usage: <db name>"
  exit 1
fi

db="$1"
output="$(pwd)/preserve_tables.sql"
command="copy (select 'ALTER TABLE ' || schemaname || '.' || tablename || ' SET logged;' from pg_tables where not schemaname in ('pg_catalog', 'information_schema') order by schemaname, tablename) to '$output';"

echo "Creating ALTER-TABLE statements..."
psql -U postgres -d $db -c "$command"

echo "Executing ALTER-TABLE statements..."
psql -U postgres -d $db -a -f "$output"

echo "Removing sql file..."
rm "$output"
echo "Done."
