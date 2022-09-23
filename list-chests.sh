#!/usr/bin/bash

source slide.sh

echo "${json_getuserdetails}" | jq '.details.chests | del(..|select(. == 0))'
