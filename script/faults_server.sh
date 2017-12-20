#!/bin/bash
#SBATCH -A p_ffmk
#SBATCH --time=144:00:00
#SBATCH --mem-per-cpu=2500
#SBATCH --ntasks=1

set -euo pipefail

# ./scripts/mysql_install_db --basedir=. --user $USER --no-defaults --datadir=data
#  ./bin/mysqld --no-defaults --datadir=./data -L ./share/
# ./bin/mysqladmin -u root password aoeuaoeu

# See init.sql

cd $BASE/faults/mariadb-10.2.10-linux-x86_64
./bin/mysqld --no-defaults --datadir=./data -L ./share/ -P $DBSERVER_PORT
