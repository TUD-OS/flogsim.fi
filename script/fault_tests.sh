#!/bin/bash

set -euo pipefail

# Script directory
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPT_DIR/init.env

source $SCRIPT_DIR/parameters_inorder.env

sbatch $SCRIPT_DIR/faults_server.sh

# Useful variables
export GIT_COMMIT=$(git rev-parse --short=7 HEAD)

source $SCRIPT_DIR/get_server.env

echo "Started dbserver at: $DBSERVER"

if [ $RESET_DB -eq 1 ]
then
    if ! $SCRIPT_DIR/faults_create_plan.sh
    then
        echo "Failed to initialize database"
        scancel $SERVER_JOB_ID
    fi
fi

mkdir -p ../slurm/$GIT_COMMIT
cd ../slurm/$GIT_COMMIT

echo 'SELECT * FROM experiment_plan' | $MYSQL_REQUEST | sed 's/\t/,/g' > experiment_plan.csv

sbatch -a$JOB_ARRAY $SCRIPT_DIR/faults_run.sh
