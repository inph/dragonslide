#!/usr/bin/bash

# already claimed
#alphachests_response='{"success":true,"okay":null,"alpha_chest_seconds_remaining":48605,"actions":[],"processing_time":"0.14562","memory_usage":"2 mb","apc_stats":{"gets":0,"gets_time":"0.00000","sets":0,"sets_time":"0.00000"},"db_stats":{"10":false,"1":false,"13":false}}'

# adding chests
#alphachests_response='{"success":true,"okay":null,"alpha_chest_seconds_remaining":64597,"actions":[{"action":"update_chest_count","chest_type_id":2,"count":1060}],"processing_time":"0.01072","memory_usage":"2 mb","apc_stats":{"gets":0,"gets_time":"0.00000","sets":0,"sets_time":"0.00000"},"db_stats":{"10":false,"1":false,"13":false}}'

source ./slide.sh

find_playserver_url
find_instance_id
#api_getuserdetails

log "+ api:alphachests"
api_call "${play_server_url}?call=alphachests&language_id=1&user_id=${user_id}&hash=${hash}&instance_key=1&include_free_play_objectives=true&timestamp=1&request_id=0&network_id=${network_id}&mobile_client_version=${mobile_client_version}&localization_aware=true&instance_id=${instance_id}&"
alphachests_response="${json_response}"

actions_check=$(echo "${alphachests_response}" | jq -r '.actions[] // empty')
if [ -z "${actions_check}" ]; then
  log "- No actions in server response"
else
  actions_action=$(echo "${alphachests_response}" | jq '.actions[].action')
  log "- alphachests: action: ${actions_action}"
  # actions_chest_type_id=$(echo "${alphachests_response}" | jq '.actions[].chest_type_id')
  actions_count=$(echo "${alphachests_response}" | jq '.actions[].count')
  count_grouped=$(echo "${actions_count}" | numfmt --grouping)
  count_si=$(echo "${actions_count}" | numfmt --to=si)
  log "- Updated gold chest count: ${count_grouped} (${count_si} / raw: ${actions_count})"
fi

seconds_remaining=$(echo "${alphachests_response}" | jq '.alpha_chest_seconds_remaining')

if [ -n "${seconds_remaining}" ]; then
  log "~ seconds_remaining: ${seconds_remaining}"
  formatted_time=$(date -d"@${seconds_remaining}" -u +%H:%M:%S)
  future_date=$(date -d "+${seconds_remaining} seconds")
  log "# Alpha chests time remaining: ${formatted_time} // Future Date: ${future_date}"
fi

#echo "${alphachests_response}" | jq

