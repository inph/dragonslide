#!/usr/bin/bash

payload_file="payload.json"

echo "- Verify is valid JSON: ${payload_file}"

if ! jq type "${payload_file}" 1>/dev/null; then
  echo "# Invalid JSON: ${payload_file} ... exiting"
  exit 1
fi

source slide.sh
# -p steam

find_playserver_url
api_getuserdetails

# public const int MaxValue = 2147483647;

# 6EC08F00
# 32AB3E00
hashcode=$(head -c512 < /dev/urandom | base64 | tr -dc '0-9A-F' | fold -w6 | head -1 | sed 's/$/00/')

http_boundary="BestHTTP_HTTPMultiPartForm_${hashcode}"

request_id=$(shuf -i 0-2147483647 -n 1)
timestamp=$(shuf -i 1-3000 -n 1)

payload_json_compressed=$(jq -c -M -j '.' "${payload_file}")
checksum=$(echo -n "${payload_json_compressed}somethingpoliticallycorrect" | md5sum | cut -c1-32)
payload=$(echo -n "${payload_json_compressed}" | pigz -z -c -9 | base64 -w0)

debug "${payload_json_compressed}"
debug "${checksum}"
debug "${payload}"
debug "request_id: $request_id timestamp: $timestamp"
#exit 0

response=$(curl -s --compressed -X POST -H "Host: ${play_server_host}" -H "Accept-Encoding: gzip, identity" \
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

save_output "${response}" "response_saveuserdetails_${datestamp}.json"
debug "${response}"
echo "----"
echo "${response}" | jq
