#!/usr/bin/bash

#### SET PATHS ####

# Get path to where script is located.
script_path=$(echo "${0%/*}")

# Set other paths.
limit_check_script=${script_path}/scripts/data-limit-check.sh
last_message_file=${script_path}/.last-message.json

#### SCRIP USAGE FUNCTION ####

# Usage function.
usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -c, --content <content>   Set the content of the Discord message."
    echo "  -e, --embeds <embeds>     Set the embeds of the Discord message."
    echo "  -f, --file <file-path>    Set the file attachment path (optional)."
    echo "  -d, --debug               Turns on console output"
    echo "  -h, --help                Show this help message and exit."
    echo ""
    echo "Refer to the Discord documentation for more information on Webhooks"
    echo ""
    echo "  https://support.discord.com/hc/en-us/articles/228383668-Intro-to-Webhooks"
    echo ""
}

### SEND WEBHOOK FUNCTION ###

# Send Discord notification with or without payloaad.
sendWebhook() {

    local discord_json_data="$1"
    local include_attachment="$2"

    # Write last message that was attmepted to be sent to file
    echo "${discord_json_data}" > ${last_message_file}

    # Check if attachment pathe exits and if is should be included in the message
    if [ -z "${discord_attachment_path}" ] || [ "${include_attachment}" = "false" ]; then

        # Send message without attachment
        reponse=$(curl -s -H "Content-Type: application/json" -d "$discord_json_data" ${discord_webhook_base}"/"${discord_id}"/"${discord_token})

    else

        # Send message with attachment
        response=$(curl -s -F payload_json="${discord_json_data}" -F "file1=@${discord_attachment_path}" ${discord_webhook_base}"/"${discord_id}"/"${discord_token})

    fi

    # Check if curl was successful
    if [ $? -ne 0 ]; then
        echo "Error: Failed to send webhook message." >&2
        exit 1
    fi

    # Output curl reposnse if debug enabled
    [ ${debug} ] && echo "${response}" >&2

}

#### PARSE ARGUMENTS ####

# Parsed from command line arguments.
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--content)
            discord_msg_content="$2"
            shift 2
            ;;
        -e|--embeds)
            discord_msg_embeds="$2"
            shift 2
            ;;
        -f|--file)
            discord_attachment_path="$2"
            shift 2
            ;;
        -d|--debug)
            debug=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            echo "Invalid option: $1" >&2
            usage
            exit 1
            ;;
    esac
done

# Check if JSON is provided and not empty
if [ -z "${discord_msg_content}" ] && [ -z "${discord_msg_embeds}" ]; then
    echo "Error: Either a message 'content' or message 'embed' is required." >&2
    usage
    exit 1
fi

#### DISCORD VARIABLES ####

# Discord webhook address base.
discord_webhook_base="https://discord.com/api/webhooks"

# Import secret variables.
source ${script_path}/.env

# Discord secret variables.
discord_token=${DISCORD_TOKEN}
discord_id=${DISCORD_ID}
discord_usernam=${DISCORD_USER}
discord_avatar_url=${DISCORD_AVATAR_URL}
discord_role_id=${DISCORD_ROLE_ID}

#### REPLACE ROLES ####

# Replace @admin mention with correct ID.
discord_msg_embeds=$(echo "${discord_msg_embeds}" | sed 's/\@admin/\<\@\&'${discord_role_id}'/g')

#### BUILD DISCORD MESSAGE ####

# Complete the Discord JSON string.
discord_json='{ "username":"'"${discord_usernam}"'",
               "content":"'"${discord_msg_content}"'",
               "avatar_url":"'"${discord_avatar_url}"'",
               "allowed_mentions": {
                 "roles": [ "'"${discord_role_id}"'" ]
               },
               "embeds": [ '${discord_msg_embeds%?}' ]
             }'

#### MESSAGE LIMIT CHECK & SEND ####

# Call script to perform limit checks (pass on debug argument if debug enabled)
${limit_check_script} -m "${discord_json}" ${debug:+-d}

# Send full, split or drop message based in limit check
case ${?} in

    # Send full message
    0)
        # Output info if debug enabled
        [ ${debug} ] && echo "Content within limits. Sending full webhook message." >&2

        # Send full Json
        sendWebhook "${discord_json}" true
        ;;

    # Split message in multiple webhooks
    1)
        # Output info if debug enabled
        [ ${debug} ] && echo "Content to large, but within manageable limits. Splitting webhook message" >&2

        # Remove embeds section
        discord_json_minus_embeds=$(jq "del(.embeds)" <<< "${discord_json}")

        # Send message without embeds
        sendWebhook "${discord_json_minus_embeds}" true

        # Get number of embeds in original message
        embeds_count=$(jq ".embeds | length" <<< "${discord_json}")

        # Send each embed as a separate message
        for (( index=0; index<$embeds_count; index++ )); do

            # Get current embed in embeds section
            embed=$(jq ".embeds[$index]" <<< "${discord_json}")

            # Replace embeds in orignal message with current single embed and remove content section
            discord_json_single_embeds=$(jq ".embeds=[$embed] | del(.content)" <<< "${discord_json}")

            # Send message with single embed and without the rest of the data
            sendWebhook "${discord_json_single_embeds}" false

        done
        ;;

    # Drop message and exit with error
    *)
        echo "Error: Limit check failed or content outside manageable limits. Unable to send webhook." >&2
        exit 1
        ;;

esac