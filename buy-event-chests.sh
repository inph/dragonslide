#!/usr/bin/bash

set -euo pipefail

source "./slide.sh"

#data_chest_ids=$(cat data/chest_ids.json)
declare -A chest_id_lookup
while IFS="=" read -r parsed_chest_id parsed_chest_name; do
  chest_id_lookup[$parsed_chest_id]="$parsed_chest_name"
done < <(jq -r "to_entries|map(\"\(.key)=\(.value)\")|.[]" data/chest_ids.json)

#for chest_id in "${!chest_id_lookup[@]}"; do
#  echo "$chest_id = ${chest_id_lookup[$chest_id]}"
#done

#echo "${chest_id_lookup[4]}"
#exit 0
find_playserver_url
api_getuserdetails
#instance_id=0

#json_getuserdetails=$(cat logs/response_getuserdetails_20221008-201024119532500.json)
#[root@darkhero dragonslide]# cat logs/response_getuserdetails_20221008-201024119532500.json | jq -rc '.details.event_details[] | select(.active==true and .event_instance > 0) | .details.years[] | [.premium_chest_type_id] | flatten' | jq -sc 'add'
#[4,72,159,245,335,428]

#| jq -rc '.details.event_details[] | select(.active==true and .event_instance > 0) | .details.years[] | [.premium_chest_type_id] | flatten' | jq -sc 'add'
#echo "${json_getuserdetails}" | jq -rc '.details.event_details[] | select(.active==true and .event_instance > 0) | .details.years[] | .premium_chest_type_id'
#exit 1

active_event_id=$(echo "${json_getuserdetails}" | jq -r '.details.event_details[] | select(.active==true and .event_instance > 0) | .event_id')
premium_chest_type_ids=$(echo "${json_getuserdetails}" | jq -r '.details.event_details[] | select(.active==true and .event_instance > 0) | .details.years[] | {premium_chest_type_id: .premium_chest_type_id, shop_desc: .shop_desc}')
#echo "${premium_chest_type_ids}"

premium_chest_ids_list=$(echo "${json_getuserdetails}" | jq -rc '.details.event_details[] | select(.active==true and .event_instance > 0) | .details.years[] | .premium_chest_type_id')
chest_ids=( $premium_chest_ids_list )

current_event_tokens=$(echo "${json_getuserdetails}" | jq '.details.event_details[] | select(.active==true and .event_instance > 0) | .user_data.event_tokens')

if [ "${current_event_tokens}" -lt 10000 ]; then
  die "# FATAL: Current Event tokens is less than 10,000 - current_event_tokens: ${current_event_tokens}"
fi

max_chests=$((current_event_tokens / 10000))

echo "- max chests per hero from tokens: ${max_chests}" 
echo "- premium_chest_ids_list: ${premium_chest_ids_list}"
echo "- number of chest ids: ${#chest_ids[@]}"

chests_each=$((max_chests / ${#chest_ids[@]}))

echo "- chests_each: ${chests_each} "

#echo "${chest_ids[@]}"
## 4 72 159 245 335 428
#delete=(428)
#for target in "${delete[@]}"; do
#  for i in "${!chest_ids[@]}"; do
#    if [[ "${chest_ids[i]}" = "${target}" ]]; then
#      unset 'chest_ids[i]'
#    fi
#  done
#done

#echo "--${chest_ids[*]}--"

api_buysoftcurrencychest() {
  local chest_type_id="${1}"
  local chests_to_purchase="${2:-1}"
  local chest_purchase_complete="0"
  local max_buy_per_call="100"

  generate_datestamp
  generate_call_parameters
  
  echo "+ api_buysoftcurrencychest: chest_type_id: ${chest_type_id} amount: ${chests_to_purchase}"
  local chests_purchased=0
  local chests_remaining="${chests_to_purchase}"
  #set -x
  loops=$((chests_to_purchase / max_buy_per_call))
  [ $((chests_to_purchase % max_buy_per_call)) -gt 0 ] && ((++loops)) # include remainder or initial call
  echo "- Estimated remote api calls: ${loops}"

  # disable logging for everything other than first and last call
  save_log_vars

  while [ "${chest_purchase_complete}" -eq 0 ]; do
    if [ "${chests_remaining}" -le "${max_buy_per_call}" ]; then
      #echo "- chests_remaining: ${chests_remaining} less equal to than 100, chest_count set to chests_remaining"
      restore_log_vars # last call enable logging
      chest_count="${chests_remaining}"
    else
      #echo "- chests_remaining: ${chests_remaining} greater to than 100, multiple calls required"
      chest_count="${max_buy_per_call}"
    fi
    echo "- Buying ${chest_count} x ${chest_name} (${chest_type_id}): ${chests_remaining} / ${chests_to_purchase}"

    api_call "${play_server_url}?call=buysoftcurrencychest&language_id=1&\
user_id=${user_id}&hash=${hash}&\
chest_type_id=${chest_type_id}&count=${chest_count}&\
timestamp=${timestamp}&request_id=${request_id}&network_id=${network_id}&mobile_client_version=${mobile_client_version}&localization_aware=true&instance_id=${instance_id}&"
    buysoftcurrencychest_response="${json_response}"
    #echo "${buysoftcurrencychest_response}"
    #printf '.'
    inv_chest_count=$(echo "${buysoftcurrencychest_response}" | jq '.chest_count // empty')
    inv_currency_remaining=$(echo "${buysoftcurrencychest_response}" | jq '.currency_remaining // empty')
    sleep 1

    echo "- Response Chest Count: ${inv_chest_count} Event tokens remaining: ${inv_currency_remaining}"
    
    chests_purchased=$((chests_purchased + chest_count))
    chests_remaining=$((chests_remaining - chest_count))
    if [ "${chests_remaining}" -eq 0 ]; then
      chest_purchase_complete=1
      echo "# chests_remaining: ${chests_remaining} / chests_purchased: ${chests_purchased} / chest_purchase_complete=1"
      #break
    fi
    disable_log_vars
  done
}

for chest_id in "${chest_ids[@]}"; do
  echo "loop: ${chest_id}"
  chest_buy_amount="${chests_each}"
  chest_name="${chest_id_lookup[${chest_id}]}"
  #echo "${chest_name}"
  printf -- "- Buy soft currency chest: chest_id: %-4s - %s - amount: %s\n" "${chest_id}" "${chest_name}" "${chest_buy_amount}"
  #printf "Echoing random number %-5s   [ OK ]" $chest_id
  #echo "- Buying chest_id: ${chest_id} - ${chest_name}"
  
  api_buysoftcurrencychest "${chest_id}" "${chest_buy_amount}"
done

#exit 0


#chest_type_id=335
#chest_count=100
#
## buy 1000 chests
#for i in {1..20}
#do
#  buy_event_chests
#done
