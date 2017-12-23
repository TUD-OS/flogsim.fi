#!/bin/bash
#SBATCH -A p_ffmk
#SBATCH --time=144:00:00
#SBATCH --mem-per-cpu=2500
#SBATCH --ntasks=1
#SBATCH --output=slurm/out-%A.%a.out
#SBATCH --error=slurm/out-%A.%a.err

set -euo pipefail

# ./scripts/mysql_install_db --basedir=. --user $USER --no-defaults --datadir=data
#  ./bin/mysqld --no-defaults --datadir=./data -L ./share/
# ./bin/mysqladmin -u root password aoeuaoeu

# See init.sql

cd $MYSQL_DIR
./bin/mysqld --no-defaults --datadir=./data -L ./share/ -P $DBSERVER_PORT
