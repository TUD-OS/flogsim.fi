#!/bin/bash
#SBATCH -A p_ffmk
#SBATCH --time=70:00:00
#SBATCH --mem-per-cpu=1500
#SBATCH --ntasks=1
#SBATCH --output=slurm/out-%A.%a.out
#SBATCH --error=slurm/out-%A.%a.err

module add gcc/7.1.0 boost/1.65.1-gnu7.1 2>&1 > /dev/null

MYSQL_DIR=$BASE/faults/mariadb-10.2.10-linux-x86_64
MYSQL=$MYSQL_DIR/bin/mysql
MYSQL_REQUEST="$MYSQL --no-defaults -u user -h $DBSERVER -puser flogsim"

FLOGSIM_DIR=$BASE/flogsim_build
FLOGSIM=$FLOGSIM_DIR/flogsim

read -r -d '' REQUEST_EXPERIMENT_SQL << EOF
DELIMITER //

START TRANSACTION;
SELECT id
INTO @ID
FROM experiment_plan
WHERE conducted < total
ORDER BY RAND()
LIMIT 1
FOR UPDATE;
IF (SELECT COUNT(@ID)) > 0 THEN
  UPDATE experiment_plan
  SET conducted = conducted + $BATCH_SIZE
  WHERE id = @ID;
  SELECT *
  FROM experiment_plan
  WHERE id = @ID;
END IF;
COMMIT //

DELIMITER ;
EOF

while true
do
    EXPERIMENT=$(echo "$REQUEST_EXPERIMENT_SQL" | $MYSQL_REQUEST | tail -n 1)

    if [[ -z "$EXPERIMENT" ]]
    then
        # All experiments are done
        echo "Tell not to start new array jobs"
        scancel -u $USER --state=pending
        exit 0
    fi

    read ID GIT_COMMIT COLL k L o g P F PAR CONDUCTED TOTAL <<<$(echo $EXPERIMENT)

    F=$(($P * $F / 100))

    $FLOGSIM -L $L -o $o -g $g -P $P -k $k \
             --faults uniform -F $F --coll $COLL --parallelism $PAR \
             -r $BATCH_SIZE --results-format csv-id --id $GIT_COMMIT
done
