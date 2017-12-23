#!/bin/bash

# Script directory
export SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

source $SCRIPT_DIR/get_server.env

echo 'SELECT 100*SUM(conducted)/SUM(total) AS "Progress (%)" FROM experiment_plan' | $MYSQL_REQUEST
