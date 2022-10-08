#!/usr/bin/bash

definitions_file=$(cat cached_defs/current.cached_definitions)

mkdir -p data

echo "- Chest defines: data/chest_ids.json"
cat "cached_defs/${definitions_file}" | jq '.chest_type_defines[] | {(.id|tostring):.name}' | jq -s 'add' > data/chest_ids.json
