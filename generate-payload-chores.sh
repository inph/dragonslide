#!/usr/bin/bash

# patron weekly challenges (excluding freeplay tokens)
# seasonal milestone, weekly, and dailies challenges

set -euo pipefail

slide_args=()
die() { echo "$*" >&2; exit 2; }
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }
while getopts "vrmswxup:" OPT; do
  case "$OPT" in
    v ) VERBOSE=true; slide_args+=("-v") ;;
    r ) RANDOM_COMPLETED=true ;;
    m ) DISABLE_MILESTONE=true ;; # Disable generation of milestone_challenges
    s ) DISABLE_SEASONAL=true ;;  # Disable generation of seasonal_challenges
    w ) WRITE_PAYLOAD=true ;;
    x ) EXECUTE_SEND_PAYLOAD=true ;;
    u ) DISABLE_UNFINISHED_DETAILS=true ;;
    p ) needs_arg; slide_args+=("-p $OPTARG") ;; # pass profile to slide
    ? ) exit 2 ;;
  esac
done
shift $((OPTIND - 1))

#echo "$0: Config Profile: ${slide_args[@]-}"

source_slide() {
  local OPTIND
  #echo "# Source: slide.sh" "$@"
  source ./slide.sh "$@"
}

source_slide "${slide_args[@]-}"

#json_getuserdetails=$(cat logs/response_getuserdetails_20221002-211811448870700.json)

find_playserver_url
api_getuserdetails

# example with egs profile
#source_slide "${slide_args[@]-}" -p egs

# 1: "The \"C\" Team Weekly Challenges"
# 2: "Mirt Challenges"
# 3: "Vajra Challenges"
# 4: "Strahd Challenges"
# 5: "Idle Champions Presents Weekly Challenges"
# 6: "Zariel Challenges"
# 7: "Idle Champions Presents Weekly Challenges"
# 8: "Season 1: Heroes of Aerois"
# 9: "Idle Champs fake challenges"

challenge_sets=($(echo "${json_getuserdetails}" | jq -r '.defines.challenge_set_defines[] | select(.name as $cs_name | ["Mirt Challenges", "Vajra Challenges", "Strahd Challenges", "Zariel Challenges", "Season 1: Heroes of Aerois"] | index($cs_name)) | .id'))
# challenge_sets = 2 3 4 6

echo "# Challenge Sets:" "${challenge_sets[@]}"

printf -v challenge_sets_ids '%s,' "${challenge_sets[@]}"
echo "${json_getuserdetails}" | jq -rc --argjson challenge_sets "[${challenge_sets_ids%,}]" '.defines.challenge_set_defines[] | select(.id == ($challenge_sets|.[])) | [.id,.name]'

for challenge_set_id in "${challenge_sets[@]}"; do
  echo "+ Processing - challenge_set_id: [${challenge_set_id}]"
  completed_challenges_json=$(echo "${json_getuserdetails}" | jq -rc --argjson challenge_set_id "${challenge_set_id}" '.details.challenge_sets[] | select(.challenge_set_id == ($challenge_set_id|tostring)) | .completed_challenges')
  echo "- [${challenge_set_id}] - Completed challenges: ${completed_challenges_json}"

  if [ "${DISABLE_SEASONAL:-false}" == "true" ]; then
    echo "- [${challenge_set_id}] - DISABLE_SEASONAL: Skipping seasonal challenges"
    available_seasonal_challenges_json="[]"
  else
    available_seasonal_challenges_json=$(echo "${json_getuserdetails}" | jq -rc --argjson challenge_set_id "${challenge_set_id}" '.details.challenge_sets[] | select(.challenge_set_id == ($challenge_set_id|tostring)) | select(.user_data.available_seasonal_challenges?) | .user_data.available_seasonal_challenges')
    if [ "${available_seasonal_challenges_json}" == "" ]; then
      #echo "- [${challenge_set_id}] - No seasonal challenges detected or available!"
      available_seasonal_challenges_json="[]"
    else
      echo "- [${challenge_set_id}] - Available seasonal challenges: ${available_seasonal_challenges_json}"
    fi
  fi

  if [ "${DISABLE_MILESTONE:-false}" == "true" ]; then
    echo "- [${challenge_set_id}] - DISABLE_MILESTONE: Skipping milestone challenges"
    available_milestone_challenges_json="[]"
  else
    available_milestone_challenges_json=$(echo "${json_getuserdetails}" | jq -rc --argjson challenge_set_id "${challenge_set_id}" '.details.challenge_sets[] | select(.challenge_set_id == ($challenge_set_id|tostring)) | select(.user_data.available_milestone_challenges?) | .user_data.available_milestone_challenges')
    if [ "${available_milestone_challenges_json}" == "" ]; then
      #echo "- [${challenge_set_id}] - No milestone challenges detected or available!"
      available_milestone_challenges_json="[]"
    else
      echo "- [${challenge_set_id}] - Available milestone challenges: ${available_milestone_challenges_json}"
    fi
  fi

  #echo "scj: ${available_seasonal_challenges_json}"
  #completed_challenges_json="${random_challenges_json}"
  #echo "jq '${random_challenges_json} - completed_challenges_json'"

  random_challenges_json=$(echo "${json_getuserdetails}" | jq -rc --argjson challenge_set_id "${challenge_set_id}" '.details.challenge_sets[] | select(.challenge_set_id == ($challenge_set_id|tostring)) | .user_data.random_challenges')

  unfinished_challenges_json=$(
    echo "${json_getuserdetails}" | jq -rc \
      --argjson challenge_set_id "${challenge_set_id}" \
      --argjson completed_challenges_json "${completed_challenges_json}" \
      --argjson available_seasonal_challenges_json "${available_seasonal_challenges_json}" \
      --argjson available_milestone_challenges_json "${available_milestone_challenges_json}" \
      '.details.challenge_sets[] | select(.challenge_set_id == ($challenge_set_id|tostring)) | .user_data.random_challenges - $completed_challenges_json + $available_seasonal_challenges_json + $available_milestone_challenges_json'
  )

  echo "- [${challenge_set_id}] - Random challenges: ${random_challenges_json}"

  if [ "${unfinished_challenges_json}" == "[]" ]; then
    echo "- [${challenge_set_id}] - No unfinished challenges!"
    #echo "- [${challenge_set_id}] - Completed challenges: ${random_challenges_json}"
    if [ "${RANDOM_COMPLETED:-false}" == "true" ]; then
      echo "- Details random challenges already completed:"
      #echo "${json_getuserdetails}" | jq -r --argjson challenge_set_id "${challenge_set_id}" \
      #  --argjson random_challenges_json "${random_challenges_json}" \
      #  '.defines.challenge_set_defines[] | select(.id == ($challenge_set_id|tonumber)) | .details.challenges[] | select(.challenge_id == ($random_challenges_json|.[])) | {description,user_stat,goal,challenge_id}'
      echo "${json_getuserdetails}" | jq -r --argjson challenge_set_id "${challenge_set_id}" --argjson random_challenges_json "${random_challenges_json}" '.defines.challenge_set_defines[] | select(.id == ($challenge_set_id|tonumber)) | .details.challenges[] | select(.challenge_id == ($random_challenges_json|.[])) | {description,user_stat,goal} | {(.user_stat):.[keys[0]]}' | jq -s add
    fi
    echo "# End processing of challenge_set_id: [${challenge_set_id}]"
    continue
  fi
  
  # available_seasonal_challenges and unfinished_challenges with completed_challenges subtracted
  echo "- [${challenge_set_id}] - Challenges for payload: ${unfinished_challenges_json}"

  if [ "${DISABLE_UNFINISHED_DETAILS:-false}" == "true" ]; then
    echo "- [${challenge_set_id}] - DISABLE_UNFINISHED_DETAILS: Skipping unfinished challenge details"
  else
    echo "- [${challenge_set_id}] - Details of unfinished challenges:"
    # full-details:
    #  "description": "Earn 500 Symbols of Zariel from Zariel free plays",
    #  "user_stat": "EarnCurrencyEasyS155",
    #  "goal": 500,
    #  "challenge_id": 2
    #echo "${json_getuserdetails}" | jq -r --argjson challenge_set_id "${challenge_set_id}" --argjson unfinished_challenges_json "${unfinished_challenges_json}" '.defines.challenge_set_defines[] | select(.id == ($challenge_set_id|tonumber)) | .details.challenges[] | select(.challenge_id == ($unfinished_challenges_json|.[])) | {description,user_stat,goal,challenge_id}'
    # short-details:
    #  "NoDPSEasyS155": "Complete 250 areas WITHOUT any DPS Champions in your formation in any Zariel variants or free plays"
    echo "${json_getuserdetails}" | jq -r --argjson challenge_set_id "${challenge_set_id}" --argjson unfinished_challenges_json "${unfinished_challenges_json}" '.defines.challenge_set_defines[] | select(.id == ($challenge_set_id|tonumber)) | .details.challenges[] | select(.challenge_id == ($unfinished_challenges_json|.[])) | {description,user_stat,goal} | {(.user_stat):.[keys[0]]}' | jq -s add
  fi

  challenges_with_goals=$(echo "${json_getuserdetails}" | jq --argjson challenge_set_id "${challenge_set_id}" \
    --argjson unfinished_challenges_json "${unfinished_challenges_json}" \
    '.defines.challenge_set_defines[] | select(.id == ($challenge_set_id|tonumber)) | .details.challenges[] | select(.challenge_id == ($unfinished_challenges_json|.[])) | {user_stat,goal} | {(.user_stat):.[keys[0]]}' | \
    jq -s 'add | with_entries(.value = (.value|tostring))')

  #  echo "- [${challenge_set_id}] - Generated inner json challenges with goals:"
  #  echo "${challenges_with_goals}"

  loop_payload+=$(jq -n --argjson challenge_set_id "${challenge_set_id}" --argjson stats_payload "${challenges_with_goals}" '{"challenge_set_id": ($challenge_set_id|tonumber),"user_data": {"stats": $stats_payload}}')
  echo "# Finished processing challenge_set_id: [${challenge_set_id}]"
done

if [ -z "${loop_payload+x}" ]; then
  echo "# No unfinished or available challenges in challenge_set_ids:" "${challenge_sets[@]}"
  exit 0
else
  payload=$(jq -n --argjson stats_payload "$(echo "${loop_payload:-""}" | jq -s '.')" '{"challenge_sets": $stats_payload,"active_game_instance_id": 3}')
  echo "${payload}"
fi

if [ "${WRITE_PAYLOAD:-false}" == "true" ]; then
  echo "# Writing payload: payload.json"
  echo "${payload}" >payload.json
fi

if [ "${EXECUTE_SEND_PAYLOAD:-false}" == "true" ]; then
  echo "# Sending payload..."
  api_saveuserdetails "${payload}"
fi
