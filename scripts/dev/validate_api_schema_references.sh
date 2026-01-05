#!/bin/bash

#set -x

API_SCHEMA_REFERENCES=$(find ${1:-.} -name *.xml -type f -exec egrep '<Item Key="(Request|Response)Schema">' {} \;)

for LINE in $API_SCHEMA_REFERENCES; do
   SCHEMA=$(echo $LINE | cut -d'>' -f2 | cut -d'<' -f1)

   if [ -z $SCHEMA ]; then
      continue
   fi

   SCHEMA_FILE=${2:-$1/doc/API/V1/schemas.src}/$SCHEMA.json

   if [ ! -e $SCHEMA_FILE ]; then
      echo schema file \"$SCHEMA\" not found!
   fi

   EXAMPLE_FILE=${2:-$1/doc/API/V1/examples}/$SCHEMA.json

   if [ ! -e $EXAMPLE_FILE ]; then
      echo example file \"$SCHEMA\" not found!
   fi
done
