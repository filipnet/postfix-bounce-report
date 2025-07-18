#!/bin/bash
#
# Script Name   : postfix-bounce-report.sh
# Description   : Analyzes the postfix log for bounced and rejected emails,
#                 generates an HTML report and sends it via sendmail.
# Author        : https://github.com/filipnet/postfix-bounce-report
# License       : BSD 3-Clause

renice -n 10 $$ > /dev/null
export LC_ALL="${LC_ALL}"

# Load configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/postfix-bounce-report.conf"
CONFIG_EXAMPLE="$CONFIG_FILE.example"

if [[ -f "$CONFIG_FILE" ]]; then
    echo "[INFO] Using config: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo "[CRITICAL] Config file missing: $CONFIG_FILE"
    echo "[INFO] Please copy the example config:"
    echo "       cp \"$CONFIG_EXAMPLE\" \"$CONFIG_FILE\""
    exit 1
fi

# Load template
TEMPLATE_HTML="$SCRIPT_DIR/templates/${TEMPLATE_BASENAME}.html"
TEMPLATE_CSS="$SCRIPT_DIR/templates/${TEMPLATE_BASENAME}.css"

if [[ ! -f "$TEMPLATE_HTML" || ! -f "$TEMPLATE_CSS" ]]; then
    echo "[WARN] Custom template not found, using default."
    TEMPLATE_BASENAME="template.default"
    TEMPLATE_HTML="$SCRIPT_DIR/templates/${TEMPLATE_BASENAME}.html"
    TEMPLATE_CSS="$SCRIPT_DIR/templates/${TEMPLATE_BASENAME}.css"
fi

STYLE=$(< "$TEMPLATE_CSS")
TEMPLATE=$(< "$TEMPLATE_HTML")

# HTML escaping function
html_escape() {
    local input="$1"
    input="${input//&/&amp;}"
    input="${input//</&lt;}"
    input="${input//>/&gt;}"
    input="${input//\"/&quot;}"
    input="${input//\'/&apos;}"
    echo "$input"
}

generate_html_report() {
    echo "[INFO] Generating HTML report ..."

    MAILINFO="${TEMPLATE//\{\{STYLE\}\}/$STYLE}"
    ROWS=""

    if [[ "$ONELINE" == "true" ]]; then
        CLASS_ONELINE="oneline"
    else
        CLASS_ONELINE=""
    fi
    MAILINFO="${MAILINFO//\{\{CLASS_ONELINE\}\}/$CLASS_ONELINE}"

    if [[ "$RECIPIENTS_CHECK" == "true" && -f "$RECIPIENTS_LIST" ]]; then
        mapfile -t RECIPIENTS < "$RECIPIENTS_LIST"
    fi

    is_known_sender() {
        local sender="$1"
        for recipient in "${RECIPIENTS[@]}"; do
            [[ "$sender" == "$recipient" ]] && return 0
        done
        return 1
    }

    process_line() {
        local line="$1"
        [[ -z "$line" ]] && return

        local datetime mailfrom mailto helo hostip reason cssclass=""
        datetime=$(echo "$line" | awk '{print $1" "$2" "$3}')
        mailfrom=$(perl -pe "s/.*?from=<(.*?)>.*/\1/g" <<< "$line")
        mailto=$(perl -pe "s/.*?to=<(.*?)>.*/\1/g" <<< "$line")
        helo=$(perl -pe "s/.*?helo=<(.*?)>.*/\1/g" <<< "$line")
        hostip=$(awk 'match($0, /[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+/) {print substr($0,RSTART,RLENGTH)}' <<< "$line")

        if [[ "$line" == *"blocked using"* ]]; then
            reason=$(perl -pe "s/.*blocked using (.*?);.*/\1/g" <<< "$line")
        elif [[ "$line" == *"milter-reject"* ]]; then
            reason=$(perl -pe "s/.*milter-reject: *//g" <<< "$line" | sed -r 's/[<>!]+//g')
        elif [[ "$line" == *"rejected"* ]]; then
            reason=$(perl -pe "s/.*rejected: *//g" <<< "$line" | sed -r 's/[<>]+//g')
        elif [[ "$line" == *"reject"* ]]; then
            reason=$(perl -pe "s/.*reject: *//g" <<< "$line" | sed -r 's/[<>]+//g')
        else
            reason="undefined"
        fi

        # extract domain from mailfrom
#        mailfrom_domain="${mailfrom#*@}"

#        if [[ "$RECIPIENTS_CHECK" == "true" && -n "$mailfrom" ]]; then
#            if is_known_sender "$mailfrom"; then
#                # only mark if domain NOT in DOMAINS variable
#                if ! [[ "$mailfrom_domain" =~ ^($DOMAINS)$ ]]; then
#                    cssclass="resent"
#                fi
#            fi
#        fi


# TEST SECTION



mailfrom_domain="${mailfrom#*@}"
base_domain=$(echo "$mailfrom_domain" | awk -F. '{print $(NF-1)"."$NF}')

if [[ -n "$mailfrom" ]]; then
    if is_known_sender "$mailfrom"; then
        if [[ "$RECIPIENTS_CHECK" == "true" ]]; then
            if ! [[ "$base_domain" =~ ^($DOMAINS)$ ]]; then
                cssclass="resent"
                echo "[DEBUG] Marking as 'resent': mailfrom='$mailfrom', base_domain='$base_domain'"
            fi
        fi
    fi

    if [[ "$SPOOFING_CHECK" == "true" ]]; then
        if [[ "$base_domain" =~ ^($DOMAINS)$ ]]; then
            cssclass="spoofing"
            echo "[DEBUG] Marking as 'spoofing': mailfrom='$mailfrom', base_domain='$base_domain'"
        fi
    fi
fi


###


        ROWS+=$'\n<tr class="'"$cssclass"'"><td>'"$(html_escape "$datetime")"'</td>'
        ROWS+='<td>'"$(html_escape "$mailfrom")"'</td>'
        ROWS+='<td>'"$(html_escape "$mailto")"'</td>'
        ROWS+='<td>'"$(html_escape "$helo")"'</td>'
        ROWS+='<td>'"$(html_escape "$hostip")"'</td>'
        ROWS+='<td>'"$(html_escape "$reason")"'</td></tr>'
    }

    if [[ "$GROUP_BY_FROM" == "true" ]]; then
        declare -A grouped_lines
        declare -A bounce_counts

        while IFS= read -r line; do
            matched=""
            for pattern in ${MAILLOG_PATTERN//|/ }; do
                if echo "$line" | grep -q -E "$pattern"; then
                    matched=1
                    break
                fi
            done
            [[ -z "$matched" ]] && continue

            mailfrom=$(perl -pe "s/.*?from=<(.*?)>.*/\1/g" <<< "$line")
            [[ -z "$mailfrom" || "$mailfrom" == "$line" ]] && continue

            grouped_lines["$mailfrom"]+=$line$'\n'
            ((bounce_counts["$mailfrom"]++))
        done <<< "$ALLBOUNCES"

        for sender in "${!grouped_lines[@]}"; do
            escaped_sender=$(html_escape "$sender")
            ROWS+=$'\n<tr class="grouphead"><td colspan="6"><strong>'"$escaped_sender"' ('"${bounce_counts[$sender]}"' bounces)</strong></td></tr>'
            while IFS= read -r line; do
                process_line "$line"
            done <<< "${grouped_lines[$sender]}"
        done
    else
        while IFS= read -r line; do
            matched=""
            for pattern in ${MAILLOG_PATTERN//|/ }; do
                if echo "$line" | grep -q -E "$pattern"; then
                    matched=1
                    break
                fi
            done
            [[ -z "$matched" ]] && continue
            process_line "$line"
        done <<< "$ALLBOUNCES"
    fi

    MAILINFO="${MAILINFO//\{\{BODY\}\}/$ROWS}"

    local run_time=$(( $(date +%s) - TIME_START ))
    local run_min=$((run_time / 60))
    local run_sec=$((run_time % 60))

    MAILINFO="${MAILINFO//\{\{RUNTIME_MIN\}\}/$run_min}"
    MAILINFO="${MAILINFO//\{\{RUNTIME_SEC\}\}/$run_sec}"
}

send_email() {
    echo "[INFO] Sending report mail to $LOGMAIL_TO"
    if [ -z "$BOUNCESEVERITY" ]; then
        if [ "$COUNTBOUNCES" -gt "$SEVERETY_THRESHOLD" ]; then
            BOUNCESEVERITY="[WARNING]"
        else
            BOUNCESEVERITY="[INFO]"
        fi
    fi

    (
        echo "From: ${LOGMAIL_FROM}"
        echo "To: ${LOGMAIL_TO}"
        echo "Subject: ${BOUNCESEVERITY} ${LOGMAIL_SUBJECT} for ${HOSTNAME}"
        echo "Mime-Version: 1.0"
        echo "Content-Type: text/html"
        echo "$MAILINFO"
    ) | sendmail -t
}

# Start
echo "[INFO] Starting postfix bounce report ..."
TIME_START=$(date +%s)

START_EPOCH=$(date -d "-${MAILLOG_PERIOD} hour" '+%s')

#ALLBOUNCES=$(awk -v threshold="$START_EPOCH" '
#{
#  log_date = $1 " " $2 " " $3;
#  cmd = "date -d \"" log_date "\" +%s";
#  cmd | getline log_epoch;
#  close(cmd);
#  if (log_epoch >= threshold) print;
#}' "$MAILLOG")

ALLBOUNCES=$(perl -ne '
  use Time::Piece;
  my $threshold = '"$START_EPOCH"';
  my $year = (localtime)[5] + 1900;
  my ($mon, $day, $time) = /^(\w+)\s+(\d+)\s+(\d+:\d+:\d+)/ or next;
  my $logtime = Time::Piece->strptime("$mon $day $year $time", "%b %d %Y %T")->epoch;
  print if $logtime >= $threshold;
' "$MAILLOG")

COUNTBOUNCES=$(echo "$ALLBOUNCES" | grep -E "${MAILLOG_PATTERN}" | wc -l)

echo "[INFO] Found $COUNTBOUNCES bounce/reject entries"

if [ "$COUNTBOUNCES" -gt 0 ]; then
    generate_html_report
    send_email
    echo "[INFO] Report sent"
else
    echo "[INFO] No relevant entries found. No mail sent."
fi

echo "[INFO] Script completed in $(( $(date +%s) - TIME_START )) sec"
