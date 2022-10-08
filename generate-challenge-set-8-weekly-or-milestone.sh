#!/usr/bin/bash

set -euo pipefail
source ./slide.sh

challenge_type="available_seasonal_challenges"
#challenge_type="available_milestone_challenges"

#json_getuserdetails=$(cat logs/response_getuserdetails_20220923-210623-0.json)
#json_getuserdetails=$(cat logs/response_getuserdetails_20220924-041918-0.json)
# with seasonal challenges available
#json_getuserdetails=$(cat logs/response_getuserdetails_20220926-102010-0.json)

challenges_to_complete=$(echo "${json_getuserdetails}" | jq -r ".details.challenge_sets[] | select(.challenge_set_id==\"8\") | .user_data.${challenge_type} | join(\",\")")
# 3028,3016,3022

if [ -z "${challenges_to_complete}" ]; then
  echo "- Challenge Set 8: ${challenge_type} is empty"
  exit 0
fi

echo "challenges_to_complete: ${challenges_to_complete}"

echo "- details of challenges"
echo "${json_getuserdetails}" | jq ".defines.challenge_set_defines[] | select(.id==8) | .details.challenges[] | select(.challenge_id == (${challenges_to_complete})) | {description,user_stat,goal,challenge_id}"

#echo "${json_getuserdetails}" | jq ".defines.challenge_set_defines[] | select(.id==8) | .details.challenges[] | select(.challenge_id == (${challenges_to_complete})) | {user_stat,goal} | {(.user_stat):.[keys[0]]}" | jq -s 'add | with_entries(.value = (.value|tostring))'

challenges_with_goals=$(echo "${json_getuserdetails}" | jq ".defines.challenge_set_defines[] | select(.id==8) | .details.challenges[] | select(.challenge_id == (${challenges_to_complete})) | {user_stat,goal} | {(.user_stat):.[keys[0]]}" | jq -s 'add | with_entries(.value = (.value|tostring))')
echo "inner payload json insert:"
echo "${challenges_with_goals}"

payload=$(jq -n --argjson stats_payload "${challenges_with_goals}" '{"challenge_sets": [{"challenge_set_id": 8,"user_data": {"stats": $stats_payload}}],"active_game_instance_id": 3}')

echo "payload: ---"
echo "${payload}" | jq
echo "---"
echo "writing payload to payload.json"
echo "${payload}" > payload.json
