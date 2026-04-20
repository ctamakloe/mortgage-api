#!/bin/bash

set -e

host="$1"
shift
cmd="$@"

until pg_isready -h "$host" -p 5432; do
  echo "Waiting for database..."
  sleep 2
done

echo "Database is ready!"

exec $cmd