#!/bin/bash

# The goal of this script is to join results from worker nodes into single data base
# Script directory

export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPT_DIR/init.env

if [ "$#" -lt 1 ]
then
    1>&2 echo "Expected format: $0 GIT_COMMIT [GIT_COMMIT...]"
    exit 1
fi

for GIT_COMMIT in "$@"
do
    LOG_DIR=$BASE/slurm/$GIT_COMMIT

    if [ ! -d "$LOG_DIR" ]
    then
        1>&2 echo "Commit $GIT_COMMIT is not found in $LOG_DIR"
        exit 1
    fi
done

OUT_DIR="../out/$(echo "$@" | sed "s/ /_/g")"
mkdir -p $OUT_DIR
OUT_LOGS=$OUT_DIR/experiment_logs.csv
OUT_PLAN=$OUT_DIR/experiment_plan.csv

# print header
DUMMY_PARAMETERS="--results-format csv-id  -r 1  --id STH  --coll phased_checked_corrected_lame_bcast"
echo "GIT_COMMIT,$($FLOGSIM $DUMMY_PARAMETERS | head -n 1)" > $OUT_LOGS
#get header for experiment plan
IN_LOG_DIR=$BASE/slurm/$1
IN_PLAN=$IN_LOG_DIR/experiment_plan.csv
head -n 1 $IN_PLAN > $OUT_PLAN

for GIT_COMMIT in "$@"
do
    IN_LOG_DIR=$BASE/slurm/$GIT_COMMIT
    IN_LOGS=$IN_LOG_DIR/experiment_logs.csv
    IN_PLAN=$IN_LOG_DIR/experiment_plan.csv

    tail -n +2 $IN_PLAN >> $OUT_PLAN
    RESULTS="$(ls $IN_LOG_DIR/results*)"

    for FILE in "$RESULTS"
    do
        cat $FILE | sed "s/^/$GIT_COMMIT,/g" >> $OUT_LOGS
    done
done
