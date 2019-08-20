#! /usr/bin/env bash

set -e

eval $(aws ecr get-login --no-include-email --region us-east-1)
docker build -t local-airflow .

docker run local-airflow
