# dragonslide

## requirements:

- bash 4+
- coreutils
- sed
- curl
- jq 1.4+
- pigz

## setup

```
cp config.json.example config.json
```

## usage

`./slide.sh -r` standalone refresh api-cache

`./source slide.sh` inside other scripts

inside other scripts while passing args to slide.sh
```
source_slide() {
  local OPTIND
  source ./slide.sh "$@"
}

source_slide "${slide_args[@]-}"
```

## config.json

format updated, now requires a "default" profile

```
{
  "default": {
    "force_play_server": "ps7", <- use this server, don't ask master for play server
    "ignore_switch_server_request": true, <- when true don't obey switch requests
    "LOG": true, <- console log (probably worth keeping on)
    "DEBUG": true, <- debug output (probably safe to disable)
    "SAVE_OUTPUT": true, <- save reponses to disk
    "SAVE_REQUEST": true, <- save requests to disk
  }
}
```

fyi some of the options are hard coded into the top of `slide.sh` but can be overridden (not tested)

## profile support

profile names are just keys in a json file:

`./slide.sh` uses the default profile from config.json - default is always read so you can set global settings there
`./slide.sh -p steam` reads and sets the default profile then overwrites with options from "steam" profile
`./slide.sh -p egs` default+egs profile

## included

`buy-patron-items.sh` - buys modron chests and timegate pieces from patron shop - does not check if they're available will just try to buy them anyway

`generate-challenge-set-2-mirt-dailies.sh` - generates a payload.json of mirt patron weekly challenges (use chores script instead)

`generate-challenge-set-8-dailies.sh` - generates a payload.json of season daily challenges (use chores script instead)

`generate-challenge-set-8-weekly-or-milestone.sh` - generates a payload.json of season weekly/milestone challenges (use chores script instead)

`generate-payload-chores.sh` - generates a payload for challenges, patron (weekly), season (daily, weekly, milestone) use -x to send at end of script - see script for other options

`get-alphachests.sh` - sends call for alphachests

`list-chests.sh` - list of chest_id's and amounts parsed from userdetails

`savedetails.sh` - send payload.json in the usersavedetails format (functionality now in slide.sh but kept for reference)

`send-payload-json-file.sh` - send file argument as a payload for savedetails

`slide.sh` - library

`update_cached_defs.sh` - update cached_defs in cached_defs/ folder with date naming

`update-data.sh` - generate files for data/ currently only chest_id to name mapping from cached_defs

## how to use

```
source ./slide.sh


# find_ checks the api-cache.json first

find_playserver_url


find_instance_id
# or
api_getuserdetails
# since api_getuserdetails will populate instance_id var you don't need both
# use find_instance_id when you just need the instance_id and you don't need to parse userdetails
```

see two examples:

`get-alphachests.sh` for using: `find_instance_id`
`list-chests.sh` for using: `api_getuserdetails`


## functions

```
generate_datestamp() - `%Y%m%d-%H%M%S%N` format
is_set() - checks a variable exists
save_output() - saves output to file via echo
save_request() - saves output to file via printf (preserves escaping)
log() - outputs to console
log_info() - not used
debug() - outputs to console if DEBUG=true
read_config() - reads config.json
find_playserver_url() - gets you a play server url either from config.json override or look up from master
api_getuserdetails() - parse userdetails
find_instance_id() - read instance_id from api-cache.json or updates via userdetails if outdated
check_json_success_true() - check the json response from server isn't garbage
api_call() - make an api call and handle retries/failures - response returned in $json_response
parse_url() - ensure urls are actually urls and split into vars for further use
send_savedetails_payload_file() - reads a file and sends it via api_saveuserdetails
check_userdetails_available() - safety check vars are set
generate_call_parameters() - generate random request_id and timestamp
api_saveuserdetails() - send a formatted payload to the saveuserdetails call
die() - exit with error message
needs_arg() exit if arg needs value
```
