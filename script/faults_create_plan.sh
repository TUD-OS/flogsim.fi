#!/bin/bash

# Create tables from scratch
if ! $MYSQL_REQUEST_ROOT < $SCRIPT_DIR/init.sql
then
    echo "Failed to create table: $exit_status"
    exit 1
fi

GIT_COMMIT=$(git rev-parse --short=7 HEAD)

if [[ ! -z $(git status -s | awk '{print $1}' | grep 'M') ]]
then
    echo "Require clean repository. Either stash or commit."
    exit 1
fi

# Ensure that we are actually running the latest revision

module add CMake/3.11.4-GCCcore-6.4.0 Boost/1.66.0-intel-2018a 2>&1 > /dev/null
module add GCCcore/7.3.0 2>&1 > /dev/null

pushd $BASE/flogsim_build
cmake $BASE/flogsim.fi/flogsim -DCMAKE_BUILD_TYPE=Release
make -j
popd

for EXPERIMENT in $COMBINATIONS
do
    read COLL L o g P k F PAR d <<<$(IFS="+"; echo $EXPERIMENT)

    CONDUCTED=0

    echo $GIT_COMMIT $COLL $L $o $g $P $k $F $PAR $d $TOTAL
    echo "INSERT INTO experiment_plan (GIT_COMMIT,COLL,k,L,o,g,P,F,PAR,d,conducted,total) VALUES (\"$GIT_COMMIT\",\"$COLL\",$k,$L,$o,$g,$P,$F,$PAR,$d,$CONDUCTED,$TOTAL)" | $MYSQL_REQUEST
done
