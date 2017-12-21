#!/bin/bash

set -euo pipefail

# Should we reset job array
export DBSERVER_PORT=3306

# Configure number of jobs
# Format jobid_start-jobid_end%maximum_concurrency
export JOB_ARRAY="1-48%48"

# Allocate sql server
export BASE=/scratch/s9951545/flogsim
export MYSQL_DIR=$BASE/faults/mariadb-10.2.10-linux-x86_64

# Script directory
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPT_DIR/parameters_debug.env

sbatch $SCRIPT_DIR/faults_server.sh

# Wait until sql server gets the allocation
SERVER_JOB_ID=$(squeue -u $USER -o "%A %j" |
                    grep faults_server.sh |
                    cut -d' ' -f1)
while true
do
    # Give a second to start the job
    sleep 1

    DBSERVER=$(squeue -j $SERVER_JOB_ID -o %N | tail -n 1)

    # Next line checks if the job didn't get resources yet
    if [[ -z "$DBSERVER" ]]
    then
        continue
    fi
    break
done

# Now check if the SQL server is really started

while ! nc -z $DBSERVER $DBSERVER_PORT
do
    # Give a second to start the server
    sleep 0.5
done

echo "Started dbserver at: $DBSERVER"

# Export data base server name
export DBSERVER

if [ $RESET_DB -eq 1 ]
then
    if ! $SCRIPT_DIR/faults_create_plan.sh
    then
        echo "Failed to initialize database"
        scancel $SERVER_JOB_ID
    fi
fi

mkdir -p slurm

sbatch -a$JOB_ARRAY $SCRIPT_DIR/faults_run.sh
