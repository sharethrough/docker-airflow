#! /usr/bin/env bash

curl --request POST \
  --header "Content-Type: application/json" \
  --header "X-SF-TOKEN: $SFX_TOKEN" \
  --data \
  "[ {
        \"category\": \"USER_DEFINED\",
        \"dimensions\": {
          \"environment\": \"production\",
          \"project\": \"docker-airflow\",
          \"service\": \"API\"
        },
        \"eventType\": \"docker-airflow code push\",
        \"properties\": {
          \"sha1\": \"$TRAVIS_COMMIT\"
        }
  } ]" \
  https://ingest.us1.signalfx.com/v2/event
