#!/bin/bash

#requirements: curl, telnet. procmail, python3

set -x

MAIL_USER=pupkin
MAIL_PASS=pupkinpass
POP3_SERVER_HOST=127.0.0.1
POP3_SERVER_PORT=1110
PAUSE_BETWEEN_CHECKS=1m
TELEGRAM_CHAT_ID=-1234567890123
TELEGRAM_CHAT_ID_FOR_SPAM=-1234567890123
TELEGRAM_BOT_TOKEN=1234567890:ABCdefghiJKLMnoPQrsTYvwXuzaBcd-JPAY


RUN_DIR=`readlink -f "$(dirname "$0")"`
NUMBERS_OF_MAIL_CACHE="$RUN_DIR/.mail_checker_numbers_cache"
[ -f "$RUN_DIR/mail_checker_env" ] && source "$RUN_DIR/.mail_checker_env"


get_new_messages()
{
    {
        sleep 10; echo "USER $MAIL_USER"
        sleep 10; echo "PASS $MAIL_PASS"
        sleep 10; echo 'LIST'
        sleep 10; echo 'QUIT'
    } | telnet $POP3_SERVER_HOST $POP3_SERVER_PORT 2>/dev/null | grep '+OK' | grep 'messages' | awk '{print $2}'
}


mail_headers_parsing() { cat - | python3 -c "from email.header import Header, decode_header, make_header; import sys; h = make_header(decode_header(sys.stdin.read())); print(h)" | sed -E 's#(<|>)##g; s#"#“#g' | sed /^$/d; }


while true
do
    NEW_NUMBERS_OF_MAIL_GET_1="`get_new_messages`"
    NEW_NUMBERS_OF_MAIL_GET_2="`get_new_messages`"
    NEW_NUMBERS_OF_MAIL=$(echo -e "$NEW_NUMBERS_OF_MAIL_GET_1\n$NEW_NUMBERS_OF_MAIL_GET_2" | grep -E '[0-9]' | sort -V | tail -n 1)
    [ ! -f "$NUMBERS_OF_MAIL_CACHE" ] && echo $NEW_NUMBERS_OF_MAIL > $NUMBERS_OF_MAIL_CACHE
    OLD_NUMBERS_OF_MAIL="`cat $NUMBERS_OF_MAIL_CACHE`"

    if [ -n "`echo $NEW_NUMBERS_OF_MAIL | grep -E '[0-9]'`" ]
    then
        while (( "$NEW_NUMBERS_OF_MAIL" > "$OLD_NUMBERS_OF_MAIL" ))
        do
            (( OLD_NUMBERS_OF_MAIL++ ))
            MAIL_MESSAGE=$(
                {
                    sleep 10; echo "USER $MAIL_USER"
                    sleep 10; echo "PASS $MAIL_PASS"
                    sleep 10; echo "retr $OLD_NUMBERS_OF_MAIL"
                    sleep 10; echo 'QUIT'
                } | telnet $POP3_SERVER_HOST $POP3_SERVER_PORT 2>/dev/null | tail -n +8
            )

            FROM_CONTENT=$(echo "<b>From:</b>" $(echo "$MAIL_MESSAGE" | formail -cx from | mail_headers_parsing | awk 'NF{NF--};1'))
            SUBJECT_CONTENT=$(echo "<b>Subject:</b>" $(echo "$MAIL_MESSAGE" | formail -cx subject | mail_headers_parsing))

            if [[ "$SUBJECT_CONTENT" =~ 'ППР на стороне' ]]
            then
                curl -X POST -H 'Content-Type: application/json' -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"parse_mode\": \"html\", \"text\": \"$FROM_CONTENT\n$SUBJECT_CONTENT\", \"disable_notification\": false}" \
                https://api.telegram.org/bot$TELEGRAM_CHAT_ID_FOR_SPAM/sendMessage
            else
                curl -X POST -H 'Content-Type: application/json' -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"parse_mode\": \"html\", \"text\": \"$FROM_CONTENT\n$SUBJECT_CONTENT\", \"disable_notification\": false}" \
                https://api.telegram.org/bot$TELEGRAM_CHAT_ID/sendMessage
            fi
        done

        echo $NEW_NUMBERS_OF_MAIL > $NUMBERS_OF_MAIL_CACHE
    else
        curl -X POST -H 'Content-Type: application/json' -d "{\"chat_id\": \"$TELEGRAM_CHAT_ID\", \"parse_mode\": \"html\", \"text\": \"SERVER CONNECTION ERROR!\", \"disable_notification\": false}" \
        https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage
    fi

    [ -n "$PAUSE_BETWEEN_CHECKS" ] && sleep $PAUSE_BETWEEN_CHECKS || break
done
