#!/usr/bin/env bash
set -o nounset

CNDB=../cndb
if [[ ! -x $CNDB ]]; then
  echo "$0: database canonical-izer $CNDB not found" >&2
  exit 1
fi
IMS=../ims
if [[ ! -x $IMS ]]; then
  echo "$0: don't see $IMS executable" >&2
  exit 1
fi
TXTIMC=../txtimc
if [[ ! -x $TXTIMC ]]; then
  echo "$0: don't see $TXTIMC executable" >&2
  exit 1
fi

export scoreFile=grade-score.txt
summaryFile=grade-summary.txt

if [ -f $scoreFile ]; then
    echo "$0: Initializing existing score file $scoreFile"
    rm -f $scoreFile
fi
touch $scoreFile

if [ -f $summaryFile ]; then
    echo "$0: Initializing existing summary file $summaryFile"
    rm -f $summaryFile
fi
touch $summaryFile

declare -a tests=("DB-01.sh" "DB-02.sh" "DB-03.sh"
    "REG-01.sh" "REG-02.sh" "REG-03.sh" "REG-04.sh" "REG-05.sh" "REG-06.sh" "REG-07.sh"
    "LOGIN-01.sh" "LOGIN-02.sh" "LOGIN-03.sh" "LOGIN-04.sh" "LOGIN-05.sh"
    "LOGOUT-01.sh" "LOGOUT-02.sh" "LOGOUT-03.sh" "LOGOUT-04.sh" "LOGOUT-05.sh"
    "ADD_RM_FRIENDS-01.sh" "ADD_RM_FRIENDS-02.sh" "ADD_RM_FRIENDS-03.sh" "ADD_RM_FRIENDS-04.sh" "ADD_RM_FRIENDS-05.sh" "ADD_RM_FRIENDS-06.sh"
    "ADD_RM_FRIENDS-07.sh" "ADD_RM_FRIENDS-08.sh" "ADD_RM_FRIENDS-09.sh" "ADD_RM_FRIENDS-10.sh" "ADD_RM_FRIENDS-11.sh"
    "FRIEND_STATUS-01.sh" "FRIEND_STATUS-02.sh" "FRIEND_STATUS-03.sh" "FRIEND_STATUS-04.sh" "FRIEND_STATUS-05.sh"
    "FRIEND_STATUS-06.sh" "FRIEND_STATUS-07.sh" "FRIEND_STATUS-08.sh" "FRIEND_STATUS-09.sh" "FRIEND_STATUS-10.sh"
    "FRIEND_IM-01.sh" "FRIEND_IM-02.sh" "FRIEND_IM-03.sh" "FRIEND_IM-04.sh" "FRIEND_IM-05.sh" "FRIEND_IM-06.sh" "FRIEND_IM-07.sh"
    "QUIT.sh")

declare -a categories=("Persistent Database" "Register" "Login" "Logout" "Adding/Removing friends" "Friend status messages" "Sending IMs" "Error messages" "Clean+Prompt Quit")
numCategories=9
declare -a totalPoints=(20 10 10 10 10 10 10 15 5)
declare -a studentPoints=(0 0 0 0 0 0 0 0 0)
declare -a cat0=("DB-01.sh" "DB-02.sh" "DB-03.sh")
declare -a cat1=("REG-01.sh" "REG-03.sh" "REG-05.sh" "REG-06.sh")
declare -a cat2=("LOGIN-01.sh" "LOGIN-05.sh")
declare -a cat3=("LOGOUT-01.sh" "LOGOUT-04.sh" "LOGOUT-05.sh")
declare -a cat4=("ADD_RM_FRIENDS-05.sh" "ADD_RM_FRIENDS-06.sh" "ADD_RM_FRIENDS-07.sh" "ADD_RM_FRIENDS-08.sh"
        "ADD_RM_FRIENDS-09.sh" "ADD_RM_FRIENDS-10.sh" "ADD_RM_FRIENDS-11.sh")
declare -a cat5=("FRIEND_STATUS-01.sh" "FRIEND_STATUS-02.sh" "FRIEND_STATUS-03.sh" "FRIEND_STATUS-04.sh" "FRIEND_STATUS-05.sh"
    "FRIEND_STATUS-06.sh" "FRIEND_STATUS-07.sh" "FRIEND_STATUS-08.sh" "FRIEND_STATUS-09.sh" "FRIEND_STATUS-10.sh")
declare -a cat6=("FRIEND_IM-06.sh" "FRIEND_IM-07.sh" "FRIEND_IM-03.sh" "FRIEND_IM-04.sh")
declare -a cat7=("REG-02.sh" "REG-04.sh" "REG-07.sh" "LOGIN-02.sh" "LOGIN-03.sh" "LOGIN-04.sh" "LOGOUT-02.sh" "LOGOUT-03.sh" "ADD_RM_FRIENDS-01.sh"
        "ADD_RM_FRIENDS-02.sh" "ADD_RM_FRIENDS-03.sh" "ADD_RM_FRIENDS-04.sh" "FRIEND_IM-01.sh" "FRIEND_IM-02.sh" "FRIEND_IM-05.sh")
declare -a cat8=("QUIT.sh")
declare -A testByCategory
declare -a numTestsPerCategory=(3 4 2 3 7 10 4 15 1)
totalScore=100
testNum=0

for ((j=0; j<${numTestsPerCategory[0]}; j++)); do
    testByCategory[0,$j]=${cat0[$j]}
    ((testNum++))
done
for ((j=0; j<${numTestsPerCategory[1]}; j++)); do
    testByCategory[1,$j]=${cat1[$j]}
    ((testNum++))
done
for ((j=0; j<${numTestsPerCategory[2]}; j++)); do
    testByCategory[2,$j]=${cat2[$j]}
    ((testNum++))
done
for ((j=0; j<${numTestsPerCategory[3]}; j++)); do
    testByCategory[3,$j]=${cat3[$j]}
    ((testNum++))
done
for ((j=0; j<${numTestsPerCategory[4]}; j++)); do
    testByCategory[4,$j]=${cat4[$j]}
    ((testNum++))
done
for ((j=0; j<${numTestsPerCategory[5]}; j++)); do
    testByCategory[5,$j]=${cat5[$j]}
    ((testNum++))
done
for ((j=0; j<${numTestsPerCategory[6]}; j++)); do
    testByCategory[6,$j]=${cat6[$j]}
    ((testNum++))
done
for ((j=0; j<${numTestsPerCategory[7]}; j++)); do
    testByCategory[7,$j]=${cat7[$j]}
    ((testNum++))
done
for ((j=0; j<${numTestsPerCategory[8]}; j++)); do
    testByCategory[8,$j]=${cat8[$j]}
    ((testNum++))
done

ti=0
echo "########################################"
echo "Will run tests:"
for test in "${tests[@]}"; do
    echo "######### $(printf "%  30s" "$test") $ti/$testNum"
    ti=$[$ti+1]
done
echo "########################################"

echo ""
echo "Running tests ..."

ti=0
for test in "${tests[@]}"; do
    echo "########################################"
    echo -n "DATETIME="; date +"%Y/%M/%d-%T"
    echo "######### $(printf "%  30s" "$test") $ti/$testNum"
    echo "########################################"
    # all of these will append to $scoreFile
    ./$test
    ti=$[$ti+1]
done

# computing the student's final score
echo "p5ims scores per category:" >> $summaryFile
studentScore=0
for ((i=0; i<$numCategories; i++)); do
    echo "${categories[i]} ... " >> $summaryFile
    score=0
    for ((j=0; j<${numTestsPerCategory[i]}; j++)); do
      tname=${testByCategory[$i,$j]}
      rsltfrac=$(grep $tname $scoreFile | cut -d' ' -f 2)
      if [ $j -eq 0 ]; then
        echo -n "      " >> $summaryFile
      else
        echo -n "    + " >> $summaryFile
      fi
      echo "$rsltfrac: $tname" >> $summaryFile
      score=$(echo "scale=2; $score + ($rsltfrac)" | bc -l)
    done
    echo "    ----------------------" >> $summaryFile
    echo "    = $score: summary fractional score for ${categories[i]}" >> $summaryFile
    echo "    / ${numTestsPerCategory[i]}: number of ${categories[i]} tests" >> $summaryFile
    score=$(echo "scale=2; $score/${numTestsPerCategory[i]}" | bc -l)
    echo "    = $score: normalized fractional score for ${categories[i]}" >> $summaryFile
    echo "    * ${totalPoints[i]}: possible points for ${categories[i]}" >> $summaryFile
    echo "    ----------------------" >> $summaryFile
    score=$(echo "scale=2; $score * ${totalPoints[i]}" | bc -l)
    echo "... = $score/${totalPoints[i]} points for ${categories[i]}" >> $summaryFile
    studentScore=$(echo "scale=2; $studentScore+$score" | bc -l)
done
echo "" >> $summaryFile
echo "Total number of points: ${studentScore}/${totalScore}" >> $summaryFile
echo "" >> $summaryFile
echo "10 Points for compiling cleanly with -Wall -Werror will be assessed manually." >> $summaryFile
