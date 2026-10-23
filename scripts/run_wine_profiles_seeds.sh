#!/bin/bash
set -e

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEED_DIRECTORY="db/seeds/wine_profiles"

cd "$ROOT_DIR"

seed_files=("$SEED_DIRECTORY"/*.rb)

if [ ! -e "${seed_files[0]}" ]; then
  echo "No wine profile seed files found in $ROOT_DIR/$SEED_DIRECTORY" >&2
  exit 1
fi

echo "Running wine profile seeds from $ROOT_DIR..."
for file in "${seed_files[@]}"; do
  echo "Executing $file via Rails runner"
  bundle exec rails runner "$file"
done

echo "All seeds executed."