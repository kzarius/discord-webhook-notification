#!/bin/bash

#### SCRIP USAGE FUNCTION ####

# Usage function.
usage() {
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -m, --message <json-content>  The Discord webhook message JSON to be checked."
    echo "  -d, --debug                   Turns on console output"
    echo "  -h, --help                    Show this help message and exit."
    echo ""
    echo "This script will check a Discord webhook message JSON string against content"
    echo "limits set by Discord. The message data must be within the limits in order"
    echo "to be successfully sent. The script will return an exit number based on the"
    echo "results of the check."
    echo ""
    echo " 0) The message data is within the limimts."
    echo " 1) The message data is outside limits, but can be sent in multiple messages."
    echo " 2) The message data is outside limits and cannot be sent."
    echo ""
    echo "Refer to Discord Webook documentation for more details on the webhook limits:"
    echo ""
    echo "  https://birdie0.github.io/discord-webhooks-guide/other/field_limits.html"
    echo ""
}

#### PARSE ARGUMENTS ####

# Parsed from command line arguments.
while [[ $# -gt 0 ]]; do
    case "$1" in
        -m|--message)
            json_msg="$2"
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
            exit 2
            ;;
    esac
done

# Check if JSON is provided and not empty
if [ -z "${json_msg}" ]; then
    echo "Error: The --message option is mandatory." >&2
    usage
    exit 2
fi

#### INITIALIZATION & PARAMETERS ####

# Character lenght limits & object count limits (the order is important!)
limits=(
    'Username       .username                   80      char    1'
    'Content        .content                    2000    char    1'
    'Embeds         .embeds                     10      obj     0'
    'Author         .embeds[].author.name       256     char    1'
    'Title          .embeds[].title             256     char    1'
    'Description    .embeds[].description       1024    char    1'
    'Fields         .embeds[].fields            25      obj     1'
    'Name           .embeds[].fields[].name     256     char    1'
    'Value          .embeds[].fields[].value    1024    char    1'
    'Footer         .embeds[].footer.text       2048    char    1'
    'Totals         na                          6000    char    1'
    'Total          na                          6000    char    0'
)

# Set limit parameter names
limit_params="name section value type critical count"

# Initialize result variables
critical_result=false
outside_limits=false
results=""
total_characters_all_embeds=0

#### LIMIT CHECK & RESULTS FUNCTION ####

# Get count, check against limit and update results
function update_results() {

    local indexed_section="$1"

    # Get the object/character count if section is an object
    [ "${indexed_section}" != "na" ] && count=$(jq "$indexed_section | length" <<< "${json_msg}")

    # Output info if debug enabled
    [ ${debug} ] && echo "${name}: ${count} / ${value}" >&2

    # Compare count with limit value
    if [[ ${count} -gt ${value} ]]; then

        # Set 'outside limit' flag
        outside_limits=true

        # Check if limit is a critical one
        if [ "${critical}" == "1" ]; then

            # Set 'critical limit' flag
            critical_result=true

        fi

        # Append to result if outside limit
        results+="${name} ${indexed_section} ${value} ${type} ${critical} ${count}\n"

    fi

}

#### CHECK CONTENT ####

# Check content agains each limit
for limit in "${limits[@]}"; do

    # Read parameters from limit
    IFS=' ' read -r $limit_params <<< "$limit"

    # Check if limit relates to the embeds section
    if [[ "${section}" == *"embeds[]"* ]]; then

        # Check each embed section individually for applicable limits
        for (( i=0; i<$(jq ".embeds | length" <<< "${json_msg}"); i++ )); do

            # Inject array index in embeds element for correct parsing
            embed_section="${section/embeds[]/embeds[${i}]}"

            # Check if section is a field section as this is an array
            if [[ "${section}" == *"fields[]"* ]]; then

                # Check each field section individually for applicable limits
                for (( j=0; j<$(jq ".embeds[$i].fields | length" <<< "${json_msg}"); j++ )); do

                    # Inject array index in fields element for correct parsing
                    field_section="${embed_section/fields[]/fields[${j}]}"

                    # Check limits and update results
                    update_results "${field_section}"

                    # Add to total characters if character type
                    [ "${type}" == "char" ] && ((embed_totals[$i]+=count))

                done

            else

                # Check limits and update results
                update_results "${embed_section}"

                # Add to total characters if character type
                [ "${type}" == "char" ] && ((embed_totals[$i]+=count))

            fi

        done

    elif [[ "${name}" == "Totals" ]]; then

        # Read the total character count for each embed section
        for count in "${embed_totals[@]}"; do

            # Check agains limit and update result
            update_results "${section}" ${count}

            # Add to the overall total character count
            ((total_characters_all_embeds+=count))

        done

    elif [[ "${name}" == "Total" ]]; then

        # Get the total character count for all embeds
        count=${total_characters_all_embeds}

        # Check agains limit and update result
        update_results "${section}" ${count}

    else

        # Check agains limit and update result
        update_results "${section}"

    fi


done

#### RETURN RESULTS ####

# Output results
[ ${debug} ] && [ -n "${results}" ] && echo -e "${results%??}" >&2

# Exit with appropriate status
if ${critical_result}; then

    exit 2

elif ${outside_limits}; then

    exit 1

else

    exit 0

fi