#!/bin/bash

set -euo pipefail
IFS=$'\n\t'
config_file="config.json"
LOG=true
DEBUG=true
SAVE_OUTPUT=true

output_path="logs/"

datestamp=$(date "+%Y%m%d-%H%M%S")

standard_headers='-H "Accept-Encoding: gzip, identity" -H "Connection: Keep-Alive, TE" -H "TE: identity" -H "User-Agent: BestHTTP"'

is_set() {
  [[ ${!1-x} == x ]] && return 1 || return 0
}

save_output() {
  [[ ${SAVE_OUTPUT:-false} == "true" ]] && echo "${1}" >>"${output_path}${2}"
  log "# saved output: ${output_path}${2}"
}

log() {
  [[ ${LOG:-false} == "true" ]] && echo "${@}"
}

debug() {
  [[ ${DEBUG:-false} == "true" ]] && echo "# DEBUG:" && echo "${@}"
}

read_config() {
  if [ -f "$config_file" ]; then
    if ! jq type "${config_file}" 1>/dev/null; then
      echo "# config invalid JSON: ${config_file} ... exiting"
      exit 1
    fi
    log "- Configuration: ${config_file} (user_id and hash hidden)"
    jq -r '. | to_entries | .[] | .key + "=" + (.value | @sh)' <${config_file} | grep -vE '(user_id|hash)'
    log "- eval: ${config_file}..."
    eval "$(jq -r '. | to_entries | .[] | .key + "=" + (.value | @sh)' <${config_file})"
  else
    log "${config_file} does not exist."
    exit 1
  fi
}

read_config

is_set instance_id || echo "instance_id is not set"

find_playserver_url() {
  #unset override_play_server_url
  #use_override_play_server_url=true

  #is_set use_override_play_server_url || { log "* use_override_play_server_url set but override_play_server_url not set, exiting"; exit 1; }

  if [ "${use_override_play_server_url:-false}" == "true" ]; then

    is_set override_play_server_url || {
      log "* use_override_play_server_url set but override_play_server_url not set, exiting"
      exit 1
    }
    play_server_url="${override_play_server_url}"
    log "- Set play_server_url using override: ${play_server_url}"
  else
    log "+ api:getPlayServerForDefinitions"
    play_server_json=$(
      curl --compressed -s \
        "http://master.idlechampions.com/~idledragons/post.php?call=getPlayServerForDefinitions&timestamp=0&request_id=0&network_id=${network_id}&mobile_client_version=${mobile_client_version}&localization_aware=true&" \
        -H "Host: master.idlechampions.com" \
        -H "Host: master.idlechampions.com" "${standard_headers}"
    )
    save_output "${play_server_json}" "response_getplayserverfordefinitions_${datestamp}.json"
    debug "${play_server_json}"

    play_server_url=$(echo "${play_server_json}" | jq -r '.play_server + "post.php"')

    #play_server_url=$(cat getPlayServerForDefinitions.json | jq -r '.play_server + "post.php"')
    #play_server_url="http://ps7.idlechampions.com/~idledragons/post.php"
    log "~ play_server_url: ${play_server_url}"

    play_server_host=$(echo "${play_server_url}" | cut -d'/' -f 3)
    log "~ play_server_host: ${play_server_host}"
    log "- Set play_server_url from api:getPlayServerForDefinitions: ${play_server_url}"
  fi
}

api_getuserdetails() {
  local counter=0
  local details_found=0

  while [ "${details_found}" -eq 0 ]; do
    log "+ api:getuserdetails [${counter}]"
    json_getuserdetails=$(
      curl --compressed -s \
        "${play_server_url}?call=getuserdetails&language_id=1&user_id=${user_id}&hash=${hash}&instance_key=1&include_free_play_objectives=true&timestamp=1&request_id=0&network_id=${network_id}&mobile_client_version=${mobile_client_version}&localization_aware=true&" \
        -H "Host: ${play_server_host}" "${standard_headers}"
    )
    # json_getuserdetails=$(cat logs/response_getuserdetails_20220923-024353.json)
    save_output "${json_getuserdetails}" "response_getuserdetails_${datestamp}-${counter}.json"
    #debug "${json_getuserdetails}"

    #echo "-----"
    switch_play_server=$(echo "${json_getuserdetails}" | jq -r '.switch_play_server')

    if [[ $switch_play_server == null ]]; then
      instance_id=$(echo "${json_getuserdetails}" | jq -r .details.instance_id)
      active_game_instance_id=$(echo "${json_getuserdetails}" | jq -r .details.active_game_instance_id)
      log "~ instance_id: ${instance_id}"
      log "~ active_game_instance_id: ${active_game_instance_id}"
      details_found=1
    else
      # $switch_play_server = "http://ps15.idlechampions.com/~idledragons/"
      log "- api_getuserdetails requested switch server to: ${switch_play_server}"
      play_server_url="${switch_play_server}post.php"
      log "- Switched play_server_url from api:getuserdetails: ${play_server_url}"
      play_server_host=$(echo "${play_server_url}" | cut -d'/' -f 3)
      log "- Switched play_server_host: ${play_server_host}"
      details_found=0
    fi
    let counter+=1
  done
}

find_playserver_url
api_getuserdetails
