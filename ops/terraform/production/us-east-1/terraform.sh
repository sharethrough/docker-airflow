#!/usr/bin/env bash

PROJECT_ROOT=$(git rev-parse --show-toplevel)
OPS_VARS="$PROJECT_ROOT/ops/shared/ops.vars"
export $(cat $OPS_VARS | xargs)

function usage {
    echo "Invalid parameters"
    echo "Usage $0 [environment] [region] [command]"
    exit 1
}

ENV=$1
REGION=$2
shift
shift
CMD=$*

ROOT_DIR="$( cd "$(dirname "$0")" ; pwd -P )"

case "$ENV" in
    production|staging|experimental)
        ;;
    *)
        usage
esac

terraform get -update=true $ROOT_DIR

terraform $CMD \
    -var "key_file=$AWS_PRIVATE_KEY" \
    -var "environment=$ENV" \
    -state=$ROOT_DIR/$REGION.tfstate \
    $ROOT_DIR

terraform output -json -state=$ROOT_DIR/$REGION.tfstate > $ROOT_DIR/exports/variables.json

echo "export outputs"
ruby "$PROJECT_ROOT/bin/create_outputs.rb" "$ROOT_DIR/exports"
