#!/usr/bin/env bash

echo "Entering entrypoint script"

IP_ADDR=$(curl -s http://169.254.170.2/v2/metadata | jq -r .Containers[0].Networks[0].IPv4Addresses[0])
IP_ADDR_DASH="${IP_ADDR//./-}"

export celery_worker="celery@ip-${IP_ADDR_DASH}.${REGION}.compute.internal"
export broker_url="redis://${REDIS_HOST}:${REDIS_PORT}/1"
export queue_name="default"

#Parse aws secrets
for var in "${!AWS_SECRET_@}"; do
    echo "Processing ${var}"
    ENV_NAME=$( echo ${var} | cut -d '_' -f3- )
    ENV_VALUE=$( echo ${!var} | jq -r .SECRET_VALUE )
    echo "Setting ${ENV_NAME}"
    eval export $ENV_NAME=\$ENV_VALUE
done


TRY_LOOP="20"

wait_for_port() {
  local name="$1" host="$2" port="$3"
  local j=0
  while ! nc -z "$host" "$port" >/dev/null 2>&1 < /dev/null; do
    j=$((j+1))
    if [ $j -ge $TRY_LOOP ]; then
      echo >&2 "$(date) - $host:$port still not reachable, giving up"
      exit 1
    fi
    echo "$(date) - waiting for $name... $j/$TRY_LOOP"
    sleep 5
  done
}

wait_for_port "Mysql" "$MYSQL_HOST" "$MYSQL_PORT"

wait_for_port "Redis" "$REDIS_HOST" "$REDIS_PORT"

handle_worker_term_signal() {
  echo "Worker termination signal received"
  echo "Broker url: ${broker_url}"
  echo "Celery url: ${celery_worker}"
  echo "Queue name: ${queue_name}"

  celery -b $broker_url -d $celery_worker control cancel_consumer $queue_name

  while (( $(celery -b $broker_url inspect active --json | python -c "import sys, json; print (len(json.load(sys.stdin)['$celery_worker']))") > 0 )); do
    echo "Sleeping..."
    sleep 60
  done

  echo "Killing worker..."
  kill $pid
  exit 0
}

case "$1" in
  webserver)
    airflow initdb
    exec airflow "$@"
    ;;
  worker)
    # To give the webserver time to run initdb.
    sleep 10
    trap handle_worker_term_signal SIGTERM

    exec airflow worker & pid="$!"

    wait $pid
    ;;
  scheduler)
    sleep 10
    exec airflow "$@"
    ;;
  flower)
    sleep 10
    exec airflow "$@"
    ;;
  version)
    exec airflow "$@"
    ;;
  *)
    # The command is something like bash, not an airflow subcommand. Just run it in the right environment.
    exec "$@"
    ;;
esac
