#!/bin/bash
#
# Script Name   : build_submission_recipients.sh
# Description   : Analyzes the postfix maillog for outgoing e-mails and continuously 
#                 creates a list of recipients
# Author        : https://github.com/filipnet/postfix-bounce-report
# License       : BSD 3-Clause "New" or "Revised" License
# ======================================================================================

renice -n 10 $$ > /dev/null

CONFIGFILE="/root/postfix-bounce-report/config.xml"
MAILLOG=$(xmllint --xpath 'string(/config/maillog)' $CONFIGFILE)
RECIPIENTS_LIST=$(xmllint --xpath 'string(/config/recipients_list)' $CONFIGFILE)

if [ ! -e "$RECIPIENTS_LIST" ] ; then
    touch "$RECIPIENTS_LIST"
fi

NEW=$(grep sasl_username= $MAILLOG | cut -d " " -f 6 | perl -pe 's/://g' | xargs -I MSGID grep MSGID $MAILLOG | grep to=\< | grep -v cleanup | perl -pe 's/^.+to=\<(.+)\>,.+$/$1/g' | perl -ne 'print lc' | sort | uniq)

echo "$NEW" > submission_recipient_new.txt
cat $RECIPIENTS_LIST > submission_recipient_old.txt
sort submission_recipient_new.txt submission_recipient_old.txt | uniq > $RECIPIENTS_LIST

rm submission_recipient_new.txt submission_recipient_old.txt -f
