#!/bin/bash

# check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq first."
    exit 1
fi

if [ $# -eq 0 ]; then
    echo "Usage: $0 <config.json>"
    exit 1
fi

CONFIG_FILE="$1"

# fetch main params
UUID=$(jq -r '.outbounds[0].settings.vnext[0].users[0].id' "$CONFIG_FILE")
ADDRESS=$(jq -r '.outbounds[0].settings.vnext[0].address' "$CONFIG_FILE")
PORT=$(jq -r '.outbounds[0].settings.vnext[0].port' "$CONFIG_FILE")
FLOW=$(jq -r '.outbounds[0].settings.vnext[0].users[0].flow // ""' "$CONFIG_FILE")
SECURITY=$(jq -r '.outbounds[0].streamSettings.security // "none"' "$CONFIG_FILE")
NETWORK=$(jq -r '.outbounds[0].streamSettings.network // "tcp"' "$CONFIG_FILE")
REMARK=$(jq -r '.outbounds[0].settings.vnext[0].address // ""' "$CONFIG_FILE" | jq -sRr '@uri')

# Reality params
REALITY_PARAMS=""
if [ "$SECURITY" = "reality" ]; then
    PUBLIC_KEY=$(jq -r '.outbounds[0].streamSettings.realitySettings.publicKey' "$CONFIG_FILE")
    FINGERPRINT=$(jq -r '.outbounds[0].streamSettings.realitySettings.fingerprint' "$CONFIG_FILE")
    SERVER_NAME=$(jq -r '.outbounds[0].streamSettings.realitySettings.serverName' "$CONFIG_FILE")
    SHORT_ID=$(jq -r '.outbounds[0].streamSettings.realitySettings.shortId' "$CONFIG_FILE")
    SPIDER_X=$(jq -r '.outbounds[0].streamSettings.realitySettings.spiderX // ""' "$CONFIG_FILE")

    # check Reality required fields
    [ -z "$PUBLIC_KEY" ] && echo "Error: Reality publicKey missing" && exit 1
    [ -z "$FINGERPRINT" ] && echo "Error: Reality fingerprint missing" && exit 1
    [ -z "$SERVER_NAME" ] && echo "Error: Reality serverName missing" && exit 1
    [ -z "$SHORT_ID" ] && echo "Error: Reality shortId missing" && exit 1

    REALITY_PARAMS="pbk=$PUBLIC_KEY&fp=$FINGERPRINT&sni=$SERVER_NAME&sid=$SHORT_ID"
    [ -n "$SPIDER_X" ] && REALITY_PARAMS+="&spx=$SPIDER_X"
fi

# check required fields
[ -z "$UUID" ] || [ "$UUID" = "null" ] && echo "Error: UUID not found" && exit 1
[ -z "$ADDRESS" ] || [ "$ADDRESS" = "null" ] && echo "Error: Address not found" && exit 1
[ -z "$PORT" ] || [ "$PORT" = "null" ] && echo "Error: Port not found" && exit 1

# making request params
PARAMS=()
[ "$SECURITY" != "none" ] && PARAMS+=("security=$SECURITY")
[ -n "$NETWORK" ] && PARAMS+=("type=$NETWORK")
[ -n "$FLOW" ] && PARAMS+=("flow=$FLOW")

# adding Reality params if there is any
[ -n "$REALITY_PARAMS" ] && PARAMS+=("$REALITY_PARAMS")

# comdbining URL
QUERY_STRING=$(IFS="&"; echo "${PARAMS[*]}" | tr -s '&' '&' | sed 's/&$//')
REMARK=${REMARK:-$ADDRESS}

URL="vless://${UUID}@${ADDRESS}:${PORT}"
[ -n "$QUERY_STRING" ] && URL+="?${QUERY_STRING//&&/&}"
URL+="#${REMARK}"

echo "$URL"