#!/usr/bin/bash

set -euo pipefail
IFS=$'\n\t'

config_file="config.json"
api_cache_file="api-cache.json"
LOG=true
DEBUG=true
SAVE_OUTPUT=true
SAVE_REQUEST=true

output_path="logs/"

generate_datestamp() {
  datestamp=$(date "+%Y%m%d-%H%M%S%N")
}

generate_datestamp

readonly standard_headers='-H "Accept-Encoding: gzip, identity" -H "Connection: Keep-Alive, TE" -H "TE: identity" -H "User-Agent: BestHTTP"'
readonly URI_REGEX='^(([^:/?#]+):)?(//((([^:/?#]+)@)?([^:/?#]+)(:([0-9]+))?))?((/|$)([^?#]*))(\?([^#]*))?(#(.*))?$'  

is_set() {
  [[ ${!1-x} == x ]] && return 1 || return 0
}

save_output() {
  [[ ${SAVE_OUTPUT:-false} == "true" ]] && echo "${1}" >>"${output_path}${2}"
  log "# saved output: ${output_path}${2}"
}

save_request() {
  [[ ${SAVE_REQUEST:-false} == "true" ]] && printf '%b' "${1}" >>"${output_path}${2}"
  log "# saved request: ${output_path}${2}"
}

log() {
  [[ ${LOG:-false} == "true" ]] && echo "${@}" || return 0
}

logf() {
  [[ ${LOG:-false} == "true" ]] && printf "${@}" || return 0
}

debug() {
  [[ ${DEBUG:-false} == "true" ]] && echo "# DEBUG:" && echo "${@}" || return 0
}

save_log_vars() {
  LOG_SAVED="${LOG}"
  SAVE_OUTPUT_SAVED="${SAVE_OUTPUT}"
  SAVE_REQUEST_SAVED="${SAVE_REQUEST}"
}

restore_log_vars() {
  LOG="${LOG_SAVED}"
  SAVE_OUTPUT="${SAVE_OUTPUT_SAVED}"
  SAVE_REQUEST="${SAVE_REQUEST_SAVED}"
}

disable_log_vars() {
  LOG="false"
  SAVE_OUTPUT="false"
  SAVE_REQUEST="false"
}

read_config() {
  if [ -f "$config_file" ]; then

    if ! jq type "${config_file}" 1>/dev/null; then
      die "# Config file invalid JSON: ${config_file} ... exiting"
    fi
    config_profile_default=$(jq -r ".default // empty" <${config_file})
    if [ -z "${config_profile_default}" ]; then
      die "# Config: ${config_file} missing default section ... exiting"
    fi

    if [ -n "${config_profile}" ]; then
      log "- Config: Use profile: ${config_profile}"
      config_profile_named=$(jq -r ".${config_profile} // empty" <${config_file})
      if [ -z "${config_profile_named}" ]; then
        die "# Config: ${config_file} missing named profile: ${config_profile} ... exiting"
      fi
    fi

    json_final_config=$(echo "${config_profile_default}${config_profile_named:-""}" | jq -s 'add')
    #echo "${json_final_config}"

    #log "- Config: Configuration parsed: ${config_file} (user_id and hash hidden)"
    #echo "${json_final_config}" | jq -r '. | del(.user_id,.hash) | to_entries | .[] | .key + "=" + (.value | @sh)'    
    eval "$(echo ${json_final_config} | jq -r '. | to_entries | .[] | .key + "=" + (.value | @sh)')"
  else
    die "# Config File: ${config_file} does not exist... exiting"
  fi
}

find_playserver_url() {
  if is_set force_play_server; then
    json_play_server="{\"play_server\": \"https://${force_play_server}.idlechampions.com/~idledragons/\"}"
    log "- Override play_server from ${config_file}: ${json_play_server}"
  else
    log "+ api:getPlayServerForDefinitions"
    api_call "http://master.idlechampions.com/~idledragons/post.php?call=getPlayServerForDefinitions&timestamp=0&request_id=0&network_id=${network_id}&mobile_client_version=${mobile_client_version}&localization_aware=true&"
    json_play_server="${json_response}"
    save_output "${json_play_server}" "response_getplayserverfordefinitions_${datestamp}.json"
    debug "${json_play_server}"
    check_json_success_true "${json_play_server}"
  fi

  play_server_url=$(echo "${json_play_server}" | jq -r '.play_server + "post.php"')
  #play_server_url="http://ps7.idlechampions.com/~idledragons/post.php"

  log "~ play_server_url: ${play_server_url}"
  play_server_host=$(echo "${play_server_url}" | cut -d'/' -f 3)
  log "~ play_server_host: ${play_server_host}"
}

api_getuserdetails() {
  log "- function: api_getuserdetails"
  api_call "${play_server_url}?call=getuserdetails&language_id=1&user_id=${user_id}&hash=${hash}&instance_key=1&include_free_play_objectives=true&timestamp=1&request_id=0&network_id=${network_id}&mobile_client_version=${mobile_client_version}&localization_aware=true&"
  json_getuserdetails="${json_response}"
  #debug "${json_getuserdetails}"

  instance_id=$(echo "${json_getuserdetails}" | jq -r .details.instance_id)
  active_game_instance_id=$(echo "${json_getuserdetails}" | jq -r .details.active_game_instance_id)
  log "~ instance_id: ${instance_id}"
  log "~ active_game_instance_id: ${active_game_instance_id}"
  log "+ Updating cache: ${api_cache_file}"
  if [ -n "${config_profile}" ]; then
    cache_profile="${config_profile}"
  else  
    cache_profile="default"
  fi
  log "- using cache_profile: ${cache_profile}"
  cache_update_json=$(jq -n \
    --arg instance_id "${instance_id}" \
    --arg active_game_instance_id "${active_game_instance_id}" \
    --arg last_play_server_url "${play_server_url}" \
    --arg timestamp "$(date +%s)" \
    --arg humandate "$(date -R)" \
    --arg cache_profile "${cache_profile}" \
    '{($cache_profile):{"timestamp": $timestamp, "datestamp": $humandate, "instance_id": $instance_id, "active_game_instance_id": $active_game_instance_id,"last_play_server_url": $last_play_server_url}}')
  #echo "${cache_update_json}"
  if [ ! -f "${api_cache_file}" ]; then
    log "- api-cache warning file not found: ${api_cache_file} ... file will be created"
    touch "${api_cache_file}"
  fi
  echo "${cache_update_json}" | cat ${api_cache_file} - | jq -s 'add' >${api_cache_file}
  log "- api-cache updated with profile: ${cache_profile}"
}

find_instance_id() {
  if [ -f "${api_cache_file}" ]; then
    if ! jq type "${api_cache_file}" 1>/dev/null; then
      die "# api-cache file invalid JSON: ${api_cache_file} ... exiting"
    fi

    if [ -n "${config_profile}" ]; then
      cache_profile=".${config_profile}"
    else  
      cache_profile=".default"
    fi

    instance_id=$(jq -r "${cache_profile}.instance_id // empty" <${api_cache_file})
    if [ -z "${instance_id}" ]; then
      die "# api-cache: ${api_cache_file} missing instance_id ... exiting"
    fi
    log "$ api-cache: instance_id: ${instance_id}"
  else
    log "# No ${api_cache_file} found, api:getuserdetails to get instance_id"
    api_getuserdetails
  fi
}

check_json_success_true() {
  #echo "${1}"
  json_raw_response="${1}"
  api_response_success=0
  json_valid_check=$(echo "${json_raw_response}" | jq -r '.success')
  log "- Parsing response api_call: [${2:-}] success: ${json_valid_check}"
  if [ "${json_valid_check}" == "null" ]; then
    log " - check_json_success_true: null response detected"
    return
  fi
  if [ "${json_valid_check}" == "true" ]; then
    api_response_success=1
  elif [ "${json_valid_check}" == "false" ]; then
    log "- Response success=failure: ${2:-}"
    debug "${json_raw_response}"
    failure_reason=$(echo "${json_raw_response}" | jq -r '.failure_reason')
    log "- Response failure reason: ${failure_reason}"
    # {"success":false,"failure_reason":"Outdated instance id","error_code":-1,"recovery_options":"","processing_time":"0.00863","memory_usage":"2 mb","apc_stats":{"gets":0,"gets_time":"0.00000","sets":0,"sets_time":"0.00000"},"db_stats":{"10":false,"1":false,"15":false}}
    if [ "${failure_reason}" == "Outdated instance id" ]; then
      outdated_url="${url}"
      log "- outdated_instance_id detected - refresh instance_id via api:getuserdetails"
      api_getuserdetails
      updated_url=$(echo "${outdated_url}" | sed "s,instance_id=[[:digit:]]\+,instance_id=${instance_id},")
      log "- Resend api_call: ${2} with updated instance_id: ${instance_id}"
      api_call "${updated_url}"
    else
      die "# FATAL api_call: ${2} unknown failure reason: ${failure_reason} ... exiting"
    fi
  fi
}

api_call() {
  url="${1}"
  api_response_success=0
  local counter=0
  if [ "${url:0-1}" != "&" ]; then
    die "# FATAL: api_call url string should terminate in &: \"...${url:0-30}\" ... exiting"
  fi
  parse_url "${url}"

  while [ "${api_response_success}" -eq 0 ]; do
    log "+ api_call: ${parse_call} [${counter}]"
    generate_datestamp
    save_request "curl --compressed -s \"${url}\" -H \"Host: ${parse_host}\" ${standard_headers} " "request_${parse_call}_${datestamp}.json"
    json_response=$(
      curl --compressed -s "${url}" -H "Host: ${parse_host}" "${standard_headers}"
    )

    save_output "${json_response}" "response_${parse_call}_${datestamp}.json"
    check_json_success_true "${json_response}" "${parse_call}"
    
    #debug "${json_getuserdetails}"

    #json_response=$(cat logs/response_getuserdetails_20220923-025439.json)
    switch_play_server=$(echo "${json_response}" | jq -r '.switch_play_server')
    if [ "${switch_play_server}" == "null" ]; then    
      # assume details if no switch play server
      api_response_success=1
      break
    else
      if [ "${ignore_switch_server_request}" == "true" ]; then
        log "- ignoring ${parse_call} switch server to: ${switch_play_server}"
      else
        # $switch_play_server = "http://ps15.idlechampions.com/~idledragons/"
        log "- api_getuserdetails requested switch server to: ${switch_play_server}"
        play_server_url="${switch_play_server}post.php"
        log "- Switched play_server_url from api:getuserdetails: ${play_server_url}"
        play_server_host=$(echo "${play_server_url}" | cut -d'/' -f 3)
        log "- Switched play_server_host: ${play_server_host}"
      fi
      api_response_success=0
    fi

    let counter+=1
    if [ "${counter}" -ge "3" ]; then
      die "# FATAL: Failed after 3 attempts: ${parse_call} ... exiting"
    fi
  done
}

parse_url() {  
  if [[ "${1}" =~ ${URI_REGEX} ]]; then
    parse_scheme="${BASH_REMATCH[2]}"
    #parse_authority="${BASH_REMATCH[4]}"
    #parse_user="${BASH_REMATCH[6]}"
    parse_host="${BASH_REMATCH[7]}"
    #parse_port="${BASH_REMATCH[9]}"
    parse_path="${BASH_REMATCH[10]}"
    #parse_rpath="${BASH_REMATCH[11]}"
    parse_query="${BASH_REMATCH[13]}"
    #parse_fragment="${BASH_REMATCH[15]}"
    parse_call="${BASH_REMATCH[14]#*=}"
    parse_call="${parse_call%%&*}"
    #echo "parse_scheme: ${parse_scheme}"
    #echo "parse_authority: ${parse_authority}"
    #echo "parse_user: ${parse_user}"
    #echo "parse_host: ${parse_host}"
    #echo "parse_port: ${parse_port}"
    #echo "parse_path: ${parse_path}"
    #echo "parse_rpath: ${parse_rpath}"
    #echo "parse_query: ${parse_query}"
    #echo "parse_fragment: ${parse_fragment}"
    #echo "parse_call: ${parse_call}"
  else
    die "# FATAL: URL did not match pattern: ${1} ... exiting"
  fi
}

#find_playserver_url
#find_instance_id
#api_getuserdetails

send_savedetails_payload_file() {
  payload_file="$1"
  log "- Verify payload.json is valid JSON: ${payload_file}"

  if ! jq type "${payload_file}" 1>/dev/null; then
    die "# FATAL: Invalid JSON: ${payload_file} ... exiting"
  fi
  payload_json_from_file=$(cat ${payload_file})

  api_saveuserdetails "${payload_json_from_file}"
}

check_userdetails_available() {
  is_set user_id || die "# FATAL: user_id is not set - call: api_getuserdetails ... exiting"
  is_set hash || die "# FATAL: hash is not set - call: api_getuserdetails ... exiting"
  is_set instance_id || die "# FATAL: instance_id is not set - call: find_instance_id or api_getuserdetails ... exiting"
  is_set play_server_url || die "# FATAL: play_server_url is not set - call: find_playserver_url or api_getuserdetails ... exiting"
  is_set play_server_host || die "# FATAL: play_server_host is not set - call: find_playserver_url or api_getuserdetails ... exiting"
}

generate_call_parameters() {
  request_id=$(shuf -i 0-2147483647 -n 1)
  timestamp=$(shuf -i 1-3000 -n 1)
}

api_saveuserdetails() {
  # $1 should be a valid json savedetails payload
  payload_json="${1}"

  if jq . >/dev/null 2>&1 <<<"${payload_json}"; then
    log "- api_saveuserdetails: payload_json successfully parsed as json";
  else
    die "- api_saveuserdetails: Failed to parse payload_json";
  fi

  check_userdetails_available
  #api_getuserdetails

  hashcode=$(head -c512 < /dev/urandom | base64 | tr -dc '0-9A-F' | fold -w6 | head -1 | sed 's/$/00/')
  http_boundary="BestHTTP_HTTPMultiPartForm_${hashcode}"
  
  generate_call_parameters
  generate_datestamp

  payload_json_compressed=$(echo -n "${payload_json}" | jq -c -M -j '.')
  checksum=$(echo -n "${payload_json_compressed}somethingpoliticallycorrect" | md5sum | cut -c1-32)
  payload=$(echo -n "${payload_json_compressed}" | pigz -z -c -9 | base64 -w0)

  debug "${payload_json_compressed}"
  debug "${checksum}"
  debug "${payload}"
  debug "request_id: $request_id timestamp: $timestamp"

  json_response=$(curl -s --compressed -X POST -H "Host: ${play_server_host}" -H "Accept-Encoding: gzip, identity" \
    -H "Connection: Keep-Alive, TE" -H "TE: identity" \
    -H "User-Agent: BestHTTP" \
    -H "Content-Type: multipart/form-data; boundary=\"${http_boundary}\"" \
-d "
--${http_boundary}
Content-Disposition: form-data; name=\"call\"
Content-Type: text/plain; charset=utf-8
Content-Length: 15

saveuserdetails
--${http_boundary}
Content-Disposition: form-data; name=\"language_id\"
Content-Type: text/plain; charset=utf-8
Content-Length: 1

1
--${http_boundary}
Content-Disposition: form-data; name=\"user_id\"
Content-Type: text/plain; charset=utf-8
Content-Length: ${#user_id}

${user_id}
--${http_boundary}
Content-Disposition: form-data; name=\"hash\"
Content-Type: text/plain; charset=utf-8
Content-Length: 32

${hash}
--${http_boundary}
Content-Disposition: form-data; name=\"details_compressed\"
Content-Type: text/plain; charset=utf-8
Content-Length: ${#payload}

${payload}
--${http_boundary}
Content-Disposition: form-data; name=\"checksum\"
Content-Type: text/plain; charset=utf-8
Content-Length: 32

${checksum}
--${http_boundary}
Content-Disposition: form-data; name=\"timestamp\"
Content-Type: text/plain; charset=utf-8
Content-Length: ${#timestamp}

${timestamp}
--${http_boundary}
Content-Disposition: form-data; name=\"request_id\"
Content-Type: text/plain; charset=utf-8
Content-Length: ${#request_id}

${request_id}
--${http_boundary}
Content-Disposition: form-data; name=\"network_id\"
Content-Type: text/plain; charset=utf-8
Content-Length: ${#network_id}

${network_id}
--${http_boundary}
Content-Disposition: form-data; name=\"mobile_client_version\"
Content-Type: text/plain; charset=utf-8
Content-Length: ${#mobile_client_version}

${mobile_client_version}
--${http_boundary}
Content-Disposition: form-data; name=\"localization_aware\"
Content-Type: text/plain; charset=utf-8
Content-Length: 4

true
--${http_boundary}
Content-Disposition: form-data; name=\"instance_id\"
Content-Type: text/plain; charset=utf-8
Content-Length: ${#instance_id}

${instance_id}
--${http_boundary}--" "${play_server_url}?call=saveuserdetails&"
  )

  save_output "${json_response}" "response_saveuserdetails_${datestamp}.json"
  #debug "${json_response}"
  echo "---"
  echo "${json_response}" | jq
}

log "# [slide.sh] ""${@}"

config_profile=""
die() { echo "$*" >&2; exit 2; }
needs_arg() { if [ -z "$OPTARG" ]; then die "No arg for --$OPT option"; fi; }
while getopts "p:vswrd" OPT; do
  case "$OPT" in
    p ) needs_arg; config_profile="${OPTARG## }" ;;
    v ) log "$ VERBOSE=true"; VERBOSE=true ;;
    s ) log "$ arg_update_play_server=true"; arg_update_play_server=true ;; # placeholder
    w ) log "$ arg_output_payload=true"; arg_output_payload=true ;; # placeholder
    r ) log "$ arg_refresh_api_cache=true"; arg_refresh_api_cache=true ;; # previous default mode of operation
    d ) log "$ arg_disable_cache=true"; arg_disable_cache=true ;; # placeholder
    ? ) exit 2 ;;
  esac
done
shift $((OPTIND - 1))

read_config

is_set user_id || die "# user_id is not set - assume config failure... exiting"
is_set hash || die "# hash is not set - assume config failure... exiting"

if is_set arg_refresh_api_cache; then
  log "# Refreshing api-cache from flag: arg_refresh_api_cache"; 
  find_playserver_url
  api_getuserdetails
fi

# end of slide.sh
