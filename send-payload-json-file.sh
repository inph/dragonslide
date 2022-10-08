#!/usr/bin/bash

if [ -z "${1}" ]; then
  echo "# ERROR: syntax is $0 filename.json"
  echo "# Where filename.json should be a valid json payload"
  exit 1
fi

if [ ! -f "${1}" ]; then
  echo "# ERROR: Can't find file: ${1}"
  exit 1
fi

source ./slide.sh

find_playserver_url
find_instance_id
#api_getuserdetails

log "# send_savedetails_payload_file: ${1}"
send_savedetails_payload_file "$1"
#echo "${json_response}"
