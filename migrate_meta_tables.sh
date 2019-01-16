#!/bin/bash
set -xe

if [[ "$#" -ne 2 ]]; then
  echo "Missing parameters. Usage: <source db> <target db>"
  exit 1
fi

sourceDb="$1"
targetDb="$2"

# export meta info one by one to be able to import users before queries
echo "Exporting data..."
pg_dump -a -U postgres -t meta.companies $sourceDb > ./${sourceDb}_companies.sql
pg_dump -a -U postgres -t meta.company_datasets $sourceDb > ./${sourceDb}_company_datasets.sql
pg_dump -a -U postgres -t meta.users $sourceDb > ./${sourceDb}_users.sql
pg_dump -a -U postgres -t meta.queries $sourceDb > ./${sourceDb}_queries.sql

# removing initial bakdata entry
echo "Removing bakdata entries..."
psql -d $targetDb -U postgres -c "delete from meta.company_datasets where company = (select id from meta.companies where lower(name) = 'bakdata gmbh');"
psql -d $targetDb -U postgres -c "delete from meta.companies where id = (select id from meta.companies where lower(name) = 'bakdata gmbh');"

# load meta data into new db
echo "Importing data..."
psql -d $targetDb -U postgres < ./${sourceDb}_companies.sql
psql -d $targetDb -U postgres < ./${sourceDb}_company_datasets.sql
psql -d $targetDb -U postgres < ./${sourceDb}_users.sql
psql -d $targetDb -U postgres < ./${sourceDb}_queries.sql

# clean up
echo "Cleaning up..."
rm ./*.sql
echo "Done."
