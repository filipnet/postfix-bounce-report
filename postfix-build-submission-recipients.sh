#!/bin/bash
#
# Script Name   : build_submission_recipients.sh
# Description   : Analyzes the postfix maillog for outgoing e-mails and continuously 
#                 creates a list of recipients
# Author        : https://github.com/filipnet/postfix-bounce-report
# License       : BSD 3-Clause "New" or "Revised" License
# ======================================================================================

renice -n 10 $$ > /dev/null

# Load configuration file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/postfix-bounce-report.conf"
CONFIG_EXAMPLE="$CONFIG_FILE.example"

if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${GREEN}[INFO]${NC} Using config: $CONFIG_FILE"
    source "$CONFIG_FILE"
else
    echo -e "${RED}[CRITICAL]${NC} Config file missing: $CONFIG_FILE"
    echo -e "${YELLOW}[INFO]${NC} Please copy the example config:"
    echo -e "       cp \"$CONFIG_EXAMPLE\" \"$CONFIG_FILE\""
    exit 1
fi

if [ ! -e "$RECIPIENTS_LIST" ] ; then
    touch "$RECIPIENTS_LIST"
fi

NEW=$(grep sasl_username= $MAILLOG | cut -d " " -f 6 | perl -pe 's/://g' | xargs -I MSGID grep MSGID $MAILLOG | grep to=\< | grep -v cleanup | perl -pe 's/^.+to=\<(.+)\>,.+$/$1/g' | perl -ne 'print lc' | sort | uniq)

echo "$NEW" > submission_recipient_new.txt
cat $RECIPIENTS_LIST > submission_recipient_old.txt
sort submission_recipient_new.txt submission_recipient_old.txt | uniq > $RECIPIENTS_LIST
rm submission_recipient_new.txt submission_recipient_old.txt -f