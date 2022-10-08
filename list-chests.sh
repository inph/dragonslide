#!/usr/bin/bash

source ./slide.sh

find_playserver_url
api_getuserdetails

echo "${json_getuserdetails}" | jq '.details.chests | del(..|select(. == 0))'
