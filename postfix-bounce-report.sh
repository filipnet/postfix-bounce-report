#!/bin/bash
#
# Script Name   : postfix-bounce-report.sh
# Description   : Analyzes the postfix logfile for bounced and rejected emails,
#                 optionaly validate/cross check FROM-value against submission list.
#                 Script also generates HTML report and send via sendmail.
# Author        : https://github.com/filipnet/postfix-bounce-report
# License       : BSD 3-Clause "New" or "Revised" License
# ======================================================================================

renice -n 10 $$ > /dev/null
export LC_ALL=de_DE.utf8

# Read XML configuration file and create variables set
CONFIGFILE="/root/postfix-bounce-report/config.xml"

# Function to read the XML data and assign to variables
read_xml_config() {
    MAILLOG=$(xmllint --xpath 'string(/config/maillog)' $CONFIGFILE)
    LOGMAILFROM=$(xmllint --xpath 'string(/config/logmail_from)' $CONFIGFILE)
    LOGMAILTO=$(xmllint --xpath 'string(/config/logmail_to)' $CONFIGFILE)
    LOGMAILSUBJECT=$(xmllint --xpath 'string(/config/logmail_subject)' $CONFIGFILE)
    PERIOD=$(xmllint --xpath 'string(/config/maillog_period)' $CONFIGFILE)
    PATTERN=$(xmllint --xpath 'string(/config/maillog_pattern)' $CONFIGFILE)
    BOUNCESEVERETY_THRESHOLD=$(xmllint --xpath 'string(/config/severety_threshold)' $CONFIGFILE)
    RECIPIENTS_CHECK=$(xmllint --xpath 'string(/config/recipients_check)' $CONFIGFILE)
    RECIPIENTS_LIST=$(xmllint --xpath 'string(/config/recipients_list)' $CONFIGFILE)
    DOMAINS=$(xmllint --xpath 'string(/config/domains)' $CONFIGFILE)
}

# Function to generate the HTML report
generate_html_report() {
    MAILINFO='<!DOCTYPE html><html lang="en"><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1.0"><title>Bounce Report</title>'
    MAILINFO+='<style>'
    MAILINFO+='* { margin: 0; padding: 0; box-sizing: border-box; }'
    MAILINFO+='body { font-family: Arial, sans-serif; background-color: #f4f4f4; color: #333; padding: 20px; }'
    MAILINFO+='h1 { font-size: 24px; color: #333; margin-bottom: 10px; }'
    MAILINFO+='table { width: 100%; max-width: 100%; margin: 20px 0; border-collapse: collapse; table-layout: fixed; }'

    MAILINFO+='th, td { padding: 12px; text-align: left; border: 1px solid #ddd; }'
    MAILINFO+='th { background-color: #4CAF50; color: white; }'
    MAILINFO+='tr:nth-child(even) { background-color: #f2f2f2; }'
    MAILINFO+='td { font-size: 14px; word-wrap: break-word; word-break: break-all; }'
    MAILINFO+='td span { font-weight: bold; }'
    MAILINFO+='tr:hover { background-color: #ddd; }'
    MAILINFO+='@media (max-width: 600px) {'
    MAILINFO+='    table, th, td { font-size: 12px; padding: 8px; }'
    MAILINFO+='    h1 { font-size: 20px; }'
    MAILINFO+='}'
    MAILINFO+='</style></head><body>'
    MAILINFO+="<h1>Bounce Report</h1>"
    MAILINFO+="<table><thead><tr><th>Date</th><th>Mail From</th><th>Mail To</th><th>Host Name</th><th>Host IP</th><th>Reason</th></tr></thead><tbody>"

    while IFS= read -r BOUNCE
    do
        BOUNCE="${BOUNCE//$'\n'/ }"
        DATETIME=$(perl -pe "s/^(\w+\s+\w+\s+\w+:\w+:\w+)\s.*/\1/g" <<< ${BOUNCE})

        if [[ "$RECIPIENTS_CHECK" = true ]]; then
            MAILFROM=$(perl -pe "s/.*?from=<(.*?)>.*/\1/gm" <<< ${BOUNCE})
            if [ -z "${MAILFROM}" ]; then
                MAILFROM="undefined"
            elif [[ "$MAILFROM" =~ $(echo ^\($(paste -sd'|' ${RECIPIENTS_LIST})\)$) ]]; then
                MAILFROM=$(perl -pe "s/.*?from=<(.*?)>.*/\1/gm" <<< ${BOUNCE})
                if [[ "${MAILFROM}" =~ ${DOMAINS} ]]; then
                    MAILFROM="<span style='color:#FFFFFF; background-color:#f44336'>SPOOFED: <b> ${MAILFROM} </b></span>"
                else
                    MAILFROM="<span style='color:#FFFFFF; background-color:#ff9800'>KNOWN: <b> ${MAILFROM} </b></span>"
                    BOUNCESEVERETY="[CRITICAL]"
                fi
            else
                MAILFROM=$(perl -pe "s/.*?from=<(.*?)>.*/\1/gm" <<< ${BOUNCE})
            fi
        else
            MAILFROM=$(perl -pe "s/.*?from=<(.*?)>.*/\1/gm" <<< ${BOUNCE})
        fi

        MAILTO=$(perl -pe "s/.*to=<(.*?)>.*/\1/g" <<< ${BOUNCE})
        HELO=$(perl -pe "s/.*helo=<(.*?)>.*/\1/g" <<< ${BOUNCE})
        HOSTIP=$(awk 'match($0, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/) {i[substr($0,RSTART,RLENGTH)]=1}END{for(ip in i){printf("%s\n", ip)}}' <<< ${BOUNCE})

        if [[ $BOUNCE == *"blocked using"* ]]; then
            REASON=$(perl -pe "s/.*blocked using (.*?);.*/\1/g" <<< ${BOUNCE})
        elif [[ $BOUNCE == *"rejected"* ]]; then
            REASON=$(perl -pe "s/.*rejected: */\1/g" <<< ${BOUNCE})
            REASON=$(echo $REASON |sed -r 's/[<>]+//g')
        elif [[ $BOUNCE == *"milter-reject"* ]]; then
            REASON=$(perl -pe "s/.*milter-reject: */\1/g" <<< ${BOUNCE})
            REASON=$(echo $REASON |sed -r 's/[<>!]+//g')
        elif [[ $BOUNCE == *"reject"* ]]; then
            REASON=$(perl -pe "s/.*reject: */\1/g" <<< ${BOUNCE})
            REASON=$(echo $REASON |sed -r 's/[<>]+//g')
        else
            REASON="undefined: $BOUNCE"
        fi

        MAILINFO+="<tr><td>${DATETIME}</td><td>${MAILFROM}</td><td>${MAILTO}</td><td>${HELO}</td><td>${HOSTIP}</td><td>${REASON}</td></tr>"
    done <<< "$ALLBOUNCES"

    MAILINFO+="</tbody></table>"
    # Time report
    TIME_DIFF=$(($(date +"%s")-${TIME_START}))
    MAILINFO+="Runtime: $((${TIME_DIFF} / 60)) Minutes $((${TIME_DIFF} % 60)) Seconds"
    MAILINFO+="</body></html>"
}

# Function to send the email
send_email() {
    if [ ! $BOUNCESEVERETY ]; then
        if [ ${COUNTBOUNCES} -gt "${BOUNCESEVERETY_THRESHOLD}" ]; then BOUNCESEVERETY="[WARNING]"; else BOUNCESEVERETY="[INFO]"; fi
    fi

    # E-Mail notification function
    (
    echo "From: ${LOGMAILFROM}"
    echo "To: ${LOGMAILTO}"
    echo "Subject: ${BOUNCESEVERETY} ${LOGMAILSUBJECT} for ${HOSTNAME}"
    echo "Mime-Version: 1.0"
    echo "Content-Type: text/html"
    echo ${MAILINFO}
    ) | sendmail -t
}

# Main Script Execution
read_xml_config

TIME_START=$(date +"%s")
ALLBOUNCES=`cat "${MAILLOG}" |grep "$(date -d '-'${PERIOD}' hour' '+%b %e')" |grep "${PATTERN}"`
COUNTBOUNCES=$( [ -n "$ALLBOUNCES" ] && echo "$ALLBOUNCES" | wc -l || echo 0 )

if [ ${COUNTBOUNCES} -gt 0 ]; then
    generate_html_report
    send_email
fi
