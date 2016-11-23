#!/bin/bash
source ddzgamedb.env

IN_FILE=create_ddzgame.sql
OUT_FILE=/tmp/create_ddzgame.sql.out
echo -n "start "
for dbname in $DBNAMES; do
	echo -n "do $dbname task "
	mysql -h$DBIP -u$DBUSER -p$DBPASS -e "set names utf8;"
	cat $IN_FILE|sed "s/\#DB\#/$dbname/g" >$OUT_FILE
	mysql -h$DBIP -u$DBUSER -p$DBPASS -e "source $OUT_FILE;"
	echo -n "do $dbname success "
done
echo -n "end"