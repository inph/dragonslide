#!/usr/bin/bash

source ./slide.sh

find_playserver_url
find_instance_id

buy_patron_shop_item() {
  generate_call_parameters
  api_call "${play_server_url}?call=purchasepatronshopitem&language_id=1&user_id=${user_id}&hash=${hash}&\
patron_id=${patron_id}&shop_item_id=${shop_item_id}&\
timestamp=${timestamp}&request_id=${request_id}&network_id=${network_id}&mobile_client_version=${mobile_client_version}&localization_aware=true&instance_id=${instance_id}&"
  echo "${json_response}" | jq 'select(.success == true) | .results[0]'
  sleep 0.3
}

patron1=(8 67)
patron2=(30 68)
patron3=(52 69)
patron4=(87 101)

patron_id=1
for shop_item_id in "${patron1[@]}"; do
  echo "- Buying patron_id: ${patron_id} shop_item_id: ${shop_item_id}"
  buy_patron_shop_item
done

patron_id=2
for shop_item_id in "${patron2[@]}"; do
  echo "- Buying patron_id: ${patron_id} shop_item_id: ${shop_item_id}"
  buy_patron_shop_item
done

patron_id=3
for shop_item_id in "${patron3[@]}"; do
  echo "- Buying patron_id: ${patron_id} shop_item_id: ${shop_item_id}"
  buy_patron_shop_item
done

patron_id=4
for shop_item_id in "${patron4[@]}"; do
  echo "- Buying patron_id: ${patron_id} shop_item_id: ${shop_item_id}"
  buy_patron_shop_item
done
