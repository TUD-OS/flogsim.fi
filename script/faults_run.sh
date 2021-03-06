#!/bin/bash
#SBATCH -A p_ffmk
#SBATCH --time=70:00:00
#SBATCH --mem-per-cpu=2400
#SBATCH --ntasks=1
#SBATCH --output=results-%A.%a.out
#SBATCH --error=out-%A.%a.err

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
        1>&2 echo "Tell not to start new array jobs"
        scancel -u $USER --state=pending
        exit 0
    fi

    read ID GIT_COMMIT COLL k L o g P F PAR d CONDUCTED TOTAL <<<$(echo $EXPERIMENT)

    # F=$(($P * $F / 10000))

    $FLOGSIM -L $L -o $o -g $g -P $P -k $k -d $d \
             --faults uniform -F $F --coll $COLL --parallelism $PAR \
             -r $BATCH_SIZE --results-format csv-id --id $ID --no-header
done
