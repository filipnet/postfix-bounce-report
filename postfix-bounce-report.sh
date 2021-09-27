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
MAILLOG=$(xmllint --xpath 'string(/config/maillog)' $CONFIGFILE)
LOGMAILFROM=$(xmllint --xpath 'string(/config/logmail_from)' $CONFIGFILE)
LOGMAILTO=$(xmllint --xpath 'string(/config/logmail_to)' $CONFIGFILE)
LOGMAILSUBJECT=$(xmllint --xpath 'string(/config/logmail_subject)' $CONFIGFILE)
PERIOD=$(xmllint --xpath 'string(/config/maillog_period)' $CONFIGFILE)
PATTERN=$(xmllint --xpath 'string(/config/maillog_pattern)' $CONFIGFILE)
BOUNCESEVERETY_THRESHOLD=$(xmllint --xpath 'string(/config/severety_threshold)' $CONFIGFILE)
RECIPIENTS_CHECK=$(xmllint --xpath 'string(/config/recipients_check)' $CONFIGFILE)
RECIPIENTS_LIST=$(xmllint --xpath 'string(/config/recipients_list)' $CONFIGFILE)

TIME_START=$(date +"%s")
ALLBOUNCES=`cat "${MAILLOG}" |grep "$(date -d '-'${PERIOD}' hour' '+%b %e')" |grep "${PATTERN}"`
COUNTBOUNCES=$( [ -n "$ALLBOUNCES" ] && echo "$ALLBOUNCES" | wc -l || echo 0 )

# Function for creating the HTML report
if [ ${COUNTBOUNCES} -gt 0 ]; then
        MAILINFO='<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01 Transitional//EN" "http://www.w3.org/TR/html4/loose.dtd"><html><head><title></title>'
        MAILINFO+='<style>'
        MAILINFO+='table.blueTable { border: 1px solid #1C6EA4; background-color: #EEEEEE; width: 100%; text-align: left; border-collapse: collapse; }
table.blueTable td, table.blueTable th { border: 1px solid #AAAAAA; padding: 3px 2px; }'
        MAILINFO+='table.blueTable tbody td { font-size: 10px; }'
        MAILINFO+='table.blueTable tr:nth-child(even) { background: #D0E4F5; }'
        MAILINFO+='table.blueTable thead { font-size: 10px; background: #1C6EA4; background: -moz-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%); background: -webkit-linear-gradient(top, #5592bb 0%, #327cad 66%, #1C6EA4 100%); background: linear-gradient(to bottom, #5592bb 0%, #327cad 66%, #1C6EA4 100%); border-bottom: 2px solid #444444; }'
        MAILINFO+='table.blueTable thead th { font-size: 10px; font-weight: bold; color: #FFFFFF; border-left: 2px solid #D0E4F5; }'
        MAILINFO+='table.blueTable thead th:first-child { border-left: none; }'


        MAILINFO+='</style>'
        MAILINFO+='</head><body><table class="blueTable">'
        MAILINFO+="<tr><th>DATE</th><th>MAIL FROM</th><th>MAIL TO</th><th>HOST NAME</th><th>HOST IP</th><th>REASON</th></tr>"

        while IFS= read -r BOUNCE
                do
                BOUNCE="${BOUNCE//$'\n'/ }"

                DATETIME=$(perl -pe "s/^(\w+\s+\w+\s+\w+:\w+:\w+)\s.*/\1/g" <<< ${BOUNCE})

                if [[ "$RECIPIENTS_CHECK" = true ]]; then
                        MAILFROM=$(perl -pe "s/.*?from=<(.*?)>.*/\1/gm" <<< ${BOUNCE})
                        if [ -z "${MAILFROM}" ]; then
                                MAILFROM="undefined"
                        elif [[ "$MAILFROM" =~ $(echo ^\($(paste -sd'|' ${RECIPIENTS_LIST})\)$) ]]; then
                                #echo "$MAILFROM is in the list"
                                MAILFROM=$(perl -pe "s/.*?from=<(.*?)>.*/\1/gm" <<< ${BOUNCE})
                                MAILFROM="<span style='color:#FFFFFF; background-color:#FF0000'><b> ${MAILFROM} </b></span>"
                                BOUNCESEVERETY="[CRITICAL]"
                        else
                                #echo "$MAILFROM is not in the list"
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
                        REASON="undefinied: $BOUNCE"
                fi
                MAILINFO+="<tr><td>${DATETIME}</td><td>${MAILFROM}</td><td>${MAILTO}</td><td>${HELO}</td><td>${HOSTIP}</td><td>${REASON}</td></tr>"

        done <<< "$ALLBOUNCES"

        MAILINFO+="</table>"
        MAILINFO+="<br/>"
        MAILINFO+="<table>"
        TIME_DIFF=$(($(date +"%s")-${TIME_START}))
        MAILINFO+="<tr><td><strong>Script runtime:</strong></td><td>$((${TIME_DIFF} / 60)) Minutes</td><td>$((${TIME_DIFF} % 60)) Seconds</td><td></td></tr>"
        MAILINFO+="</table></body></html>"

        # If the criticality is CRITICAL it will always remain
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

fi