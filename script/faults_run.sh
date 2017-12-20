#!/bin/bash
#SBATCH -A p_ffmk
#SBATCH --time=12:00:00
#SBATCH --mem-per-cpu=1500
#SBATCH --ntasks=1
#SBATCH --output=slurm/out-%j.out
#SBATCH --error=slurm/out-%j.err

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
LIMIT 1;
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

    read ID GIT_COMMIT COLL k L o g P F CONDUCTED TOTAL <<<$(echo $EXPERIMENT)

    F=$(($P * $F / 100))

    echo $COLL $L $o "g=$g" "P=$P" $k $F $CONDUCTED $TOTAL

    if [[ $F == 0 ]]
    then
        COMMAND="$FLOGSIM --k $k --P $P --o $o --g $g --L $L --faults none --coll $COLL"
    else
        COMMAND="$FLOGSIM --k $k --P $P --o $o --g $g --L $L --faults uniform --F $F --coll $COLL"
    fi

    for ((i=1;i<=$BATCH_SIZE;i++))
    do
        OUT="$($COMMAND)"
        echo "$OUT"
        read RUNTIME FAILED FINISHED UNREACHED MSGTASK SEED REST <<<$(echo "$OUT" | sed -e 's/^[^,]*,//g')

        read -r -d '' INSERT_RESULT_SQL << EOF
INSERT INTO experiment_log
VALUES ($ID,
  $RUNTIME,$FAILED,$FINISHED,$UNREACHED,$MSGTASK,$SEED)
EOF

        echo "$INSERT_RESULT_SQL" | $MYSQL_REQUEST
    done
done
