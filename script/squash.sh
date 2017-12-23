#!/bin/bash

# The goal of this script is to join results from worker nodes into single data base
# Script directory

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPT_DIR/init.env

if [ "$#" -ne 1 ]
then
    1>&2 echo "Expected format: $0 GIT_COMMIT"
    exit 1
fi

GIT_COMMIT=$1

LOG_DIR=$BASE/slurm/$GIT_COMMIT
LOGS=$LOG_DIR/experiment_logs.csv

if [ ! -d "$LOG_DIR" ]
then
    1>&2 echo "Commit $GIT_COMMIT is not found in $LOG_DIR"
    # exit 1
fi

# print header
DUMMY_PARAMETERS="--results-format csv-id  -r 0  --id STH  --coll optimal_bcast"
$FLOGSIM $DUMMY_PARAMETERS > $LOGS

RESULTS="$(ls $LOG_DIR/results*)"

for FILE in "$RESULTS"
do
    cat $FILE >> $LOGS
done
