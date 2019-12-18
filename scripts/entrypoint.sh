#!/usr/bin/env bash

echo "Beginning entrypoint script"

if [[ $ENVIRONMENT = "production" ]]; then
        echo "Production environment, use ecs/ec2 endpoints"
        IP_ADDR=$(curl -s http://169.254.170.2/v2/metadata | jq -r .Containers[0].Networks[0].IPv4Addresses[0])
        LOCAL_HOSTNAME=$(curl http://169.254.169.254/latest/meta-data/local-hostname)
        IP_ADDR_DASH="${IP_ADDR//./-}"
fi

export local_hostname=${LOCAL_HOSTNAME}
export celery_worker="celery@ip-${IP_ADDR_DASH}.ec2.internal"
export broker_url="redis://${REDIS_HOST}:${REDIS_PORT}/0"
export queue_name="default"

echo "Host IP: ${local_hostname}"
echo "Broker url: ${broker_url}"
echo "Celery url: ${celery_worker}"
echo "Queue name: ${queue_name}"

#Retrieve and parse aws secrets
AIRFLOW_SECRET_VALUES=$( aws secretsmanager get-secret-value --region us-east-1 --secret-id production/airflow --version-stage AWSCURRENT | jq '.SecretString | fromjson' )
SNOWFLAKE_SECRET_VALUES=$( aws secretsmanager get-secret-value --region us-east-1 --secret-id production/snowflake_users --version-stage AWSCURRENT | jq '.SecretString | fromjson' )

for s in $(echo $AIRFLOW_SECRET_VALUES | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ); do
    export $s
done

for s in $(echo $SNOWFLAKE_SECRET_VALUES | jq -r "to_entries|map(\"\(.key)=\(.value|tostring)\")|.[]" ); do
    export $s
done

TRY_LOOP="20"

wait_for_port() {
        local name="$1" host="$2" port="$3"
        local j=0

        echo "Attempting to connect to $host with port $port" 

        while ! nc -z "$host" "$port" >/dev/null 2>&1 < /dev/null; do
                j=$((j+1))
                if [ $j -ge $TRY_LOOP ]; then
                        echo >&2 "$(date) - $host:$port still not reachable, giving up"
                        exit 1
                fi
                echo "$(date) - waiting for $name... $j/$TRY_LOOP"
                sleep 5
        done

        echo "Successfully connected to $host with port $port" 
}

if [[ $EXECUTOR_TYPE = "CeleryExecutor" ]]; then
        wait_for_port "Mysql" "$MYSQL_HOST" "$MYSQL_PORT"
        wait_for_port "Redis" "$REDIS_HOST" "$REDIS_PORT"
fi

if [[ $EXECUTOR_TYPE = "LocalExecutor" ]]; then
        wait_for_port "Mysql" "$MYSQL_HOST" "$MYSQL_PORT"
fi

echo "All ports checked successfully"

check_worker_queue() {
        local active_tasks=$(celery -b $broker_url inspect active --json) 
        local tasks_current_worker=$(echo $active_tasks | jq --arg celery_worker "$celery_worker" '.[$celery_worker]')
        current_worker_task_number=$(echo $tasks_current_worker | jq '. | length')

        echo "Found $current_worker_task_number active tasks"
}

handle_worker_term_signal() {
        echo "Worker termination signal received"
        echo "Broker url: ${broker_url}"
        echo "Celery url: ${celery_worker}"
        echo "Queue name: ${queue_name}"

        echo "Cancelling queue consumer"
        # Try to cancel consuming from queue
        celery -b $broker_url -d $celery_worker control cancel_consumer $queue_name
        CANCEL_CONSUMER_RET=$?
        if [[ $CANCEL_CONSUMER_RET -ne 0 ]]; then
            echo "Consumer response failed"
            echo "Sleeping for backup wait time of 30 minutes"
            sleep 1800
        else
            # Loop to check queue until empty
            while
                check_worker_queue
                (($current_worker_task_number > 0))
            do
                echo "Sleeping..."            
                sleep 60
            done
        fi

        echo "Killing worker..."
        kill $pid
        exit 0
}

handle_general_term_signal() {
        echo "Killing non worker process..."
        kill $pid
        exit 0
}

case "$1" in
        webserver)
                airflow initdb
                echo "Setting airflow connections and variables"
                python3 -u /airflow_config_environment.py
                
                echo "Setting airflow pools"
                if [ ! -f pools.yml ]; then
                  echo "pools.yml file not found"
                else
                  echo "pools.yml file found, setting pools"
                  cat pools.yml | yq . > pools.json
                  airflow pool        --import pools.json
                fi

                trap handle_general_term_signal SIGTERM
                exec airflow "$@" & pid="$!"
                wait $pid
                ;;
        worker)
                # To give the webserver time to run initdb.
                sleep 10
                trap handle_worker_term_signal SIGTERM
                exec airflow worker & pid="$!"
                wait $pid
                ;;
        scheduler|flower|version)
                sleep 10
                trap handle_general_term_signal SIGTERM
                exec airflow "$@" & pid="$!"
                wait $pid
                ;;
        *)
                # The command is something like bash, not an airflow subcommand. Just run it in the right environment.
                exec "$@"
                ;;
esac
