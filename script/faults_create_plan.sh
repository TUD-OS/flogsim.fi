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

module add gcc/7.1.0 boost/1.65.1-gnu7.1 2>&1 > /dev/null
pushd $BASE/flogsim_build
cmake $BASE/flogsim.fi/flogsim -DCMAKE_BUILD_TYPE=Release
make -j
popd

COMBINATIONS=$(eval echo "$COLL+$L+$o+$g+$P+$k+$F+$PAR")
for EXPERIMENT in $COMBINATIONS
do
    read COLL L o g P k F PAR <<<$(IFS="+"; echo $EXPERIMENT)

    CONDUCTED=0

    echo $GIT_COMMIT $COLL $L $o $g $P $k $F $PAR $TOTAL
    echo "INSERT INTO experiment_plan (GIT_COMMIT,COLL,k,L,o,g,P,F,PAR,conducted,total) VALUES (\"$GIT_COMMIT\",\"$COLL\",$k,$L,$o,$g,$P,$F,$PAR,$CONDUCTED,$TOTAL)" | $MYSQL_REQUEST
done
