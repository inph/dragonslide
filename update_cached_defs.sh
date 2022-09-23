#!/usr/bin/bash

output_path="cached_defs"
play_server_host="ps7.idlechampions.com"

mobile_client_version="471"

mkdir -p "${output_path}"

datestamp=$(date "+%Y%m%d-%H%M%S")

echo "~ api:getDefinitions from ${play_server_host} mobile_client_version: ${mobile_client_version}"
curl -s -o "${output_path}/cached_definitions_${datestamp}.json" "http://${play_server_host}/~idledragons/post.php?call=getDefinitions&language_id=1&network_id=11&mobile_client_version=${mobile_client_version}&localization_aware=true&"

echo "cached_definitions_${datestamp}.json" > "${output_path}/current.cached_definitions"
echo "+ api:getDefinitions saved to: ${output_path}/cached_definitions_${datestamp}.json"
