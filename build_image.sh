#! /bin/bash

#REPO_NAME = "119933218031.dkr.ecr.us-east-1.amazonaws.com/airflow"

docker build -t 119933218031.dkr.ecr.us-east-1.amazonaws.com/airflow --no-cache=true .
eval $(aws ecr get-login --no-include-email --region us-east-1)
docker push 119933218031.dkr.ecr.us-east-1.amazonaws.com/airflow 
