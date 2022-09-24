#!/usr/bin/bash

set -euo pipefail
source slide.sh

#json_getuserdetails=$(cat logs/response_getuserdetails_20220923-210623-0.json)
#json_getuserdetails=$(cat logs/response_getuserdetails_20220924-044838-0.json)

completed_challenges=$(echo "${json_getuserdetails}" | jq -r '.details.challenge_sets[] | select(.challenge_set_id=="2") | .completed_challenges')
# [ 1010, 1020, 1050, 1070, 2015, 3030, 1071, 2014, 1072, 1051, 1073, 1074, 1011, 1075, 1052, 1076, 2010, 1021, 1053, 3049, 1012, 1077, 1022, 1054, 2016, 3012, 3046, 1078, 3000, 1030, 1060, 1090, 2013, 1091, 1031, 1092, 1061, 3018, 1079, 1093, 1023, 2012, 1013, 1094, 1062, 1055, 1032, 1095, 2011, 1024, 1033, 1014, 1056, 3063, 1080, 3001, 3060, 3025, 2026, 2025, 3073, 1034, 1035, 1063, 1025, 2020, 3014 ]
#echo "completed_challenges: ${completed_challenges}"

dailies_to_complete=$(echo "${json_getuserdetails}" | jq -r ".details.challenge_sets[] | select(.challenge_set_id==\"2\") | .user_data.random_challenges - ${completed_challenges} | join(\",\")")
# 3028,3016,3022

if [ -z "${dailies_to_complete}" ]; then
  echo "- Challenge Set 2 Dailies completed already:"
  echo "${json_getuserdetails}" | jq -r '.details.challenge_sets[] | select(.challenge_set_id=="2") | .user_data.random_challenges'
  exit 0
fi

echo "dailies_to_complete minus completed_challenges: ${dailies_to_complete}"

#cat logs/response_getuserdetails_20220923-210623-0.json | jq '.defines.challenge_set_defines[] | select(.id==8)'

#{
#  "Daily017D10": "1",
#  "Daily023D10": "1000",
#  "Daily029D10": "50"
#}

echo "details of dailies"
echo "${json_getuserdetails}" | jq ".defines.challenge_set_defines[] | select(.id==2) | .details.challenges[] | select(.challenge_id == (${dailies_to_complete})) | {description,user_stat,goal,challenge_id}"

#echo "${json_getuserdetails}" | jq ".defines.challenge_set_defines[] | select(.id==2) | .details.challenges[] | select(.challenge_id == (${dailies_to_complete})) | {user_stat,goal} | {(.user_stat):.[keys[0]]}" | jq -s 'add | with_entries(.value = (.value|tostring))'

challenges_with_goals=$(echo "${json_getuserdetails}" | jq ".defines.challenge_set_defines[] | select(.id==2) | .details.challenges[] | select(.challenge_id == (${dailies_to_complete})) | {user_stat,goal} | {(.user_stat):.[keys[0]]}" | jq -s 'add | with_entries(.value = (.value|tostring))')
echo "inner payload json insert:"
echo "${challenges_with_goals}"

payload=$(jq -n --argjson stats_payload "${challenges_with_goals}" '{"challenge_sets": [{"challenge_set_id": 2,"user_data": {"stats": $stats_payload}}],"active_game_instance_id": 3}')

echo "payload: ----"
echo "${payload}"
echo "----"
echo "writing payload to payload.json"
echo "${payload}" > payload.json
