#!/usr/bin/env bash

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

reportFile=CummulativeTestReport.txt 

if [ -f $reportFile ]; then
    echo "$0: Initializing existing $reportFile"
    rm -f $reportFile
    touch $reportFile  # needed if all tests fail
fi

declare -a tests=("DB-01.sh" "DB-02.sh" "DB-03.sh"
    "REG-01.sh" "REG-02.sh" "REG-03.sh" "REG-04.sh" "REG-05.sh" "REG-06.sh" "REG-07.sh"
    "LOGIN-01.sh" "LOGIN-02.sh" "LOGIN-03.sh" "LOGIN-04.sh" "LOGIN-05.sh"
    "LOGOUT-01.sh" "LOGOUT-02.sh" "LOGOUT-03.sh" "LOGOUT-04.sh" "LOGOUT-05.sh"
    "ADD_RM_FRIENDS-01.sh" "ADD_RM_FRIENDS-02.sh" "ADD_RM_FRIENDS-03.sh" "ADD_RM_FRIENDS-04.sh" "ADD_RM_FRIENDS-05.sh" "ADD_RM_FRIENDS-06.sh"
    "ADD_RM_FRIENDS-07.sh" "ADD_RM_FRIENDS-08.sh" "ADD_RM_FRIENDS-09.sh" "ADD_RM_FRIENDS-10.sh" "ADD_RM_FRIENDS-11.sh"
    "FRIEND_STATUS-01.sh" "FRIEND_STATUS-02.sh" "FRIEND_STATUS-03.sh" "FRIEND_STATUS-04.sh" "FRIEND_STATUS-05.sh"
    "FRIEND_STATUS-06.sh" "FRIEND_STATUS-07.sh" "FRIEND_STATUS-08.sh" "FRIEND_STATUS-09.sh" "FRIEND_STATUS-10.sh"
    "FRIEND_IM-01.sh" "FRIEND_IM-02.sh" "FRIEND_IM-03.sh" "FRIEND_IM-04.sh" "FRIEND_IM-05.sh" "FRIEND_IM-06.sh" "FRIEND_IM-07.sh")

declare -a categories=("Persistent Database" "Register" "Login" "Logout" "Adding/Removing friends" "Friend status messages" "Sending IMs" "Error messages")
numCategories=8
declare -a totalPoints=(20 10 10 10 10 10 10 15)
declare -a studentPoints=(0 0 0 0 0 0 0 0)
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
declare -A testsPerCategory
declare -a numTestsPerCategory=(3 4 2 3 7 10 4 15) 
declare -a numTestsPerCategoryPassed=(0 0 0 0 0 0 0 0) 
totalScore=95
studentScore=0

for ((j=0; j<${numTestsPerCategory[0]}; j++))
do
    testsPerCategory[0,$j]=${cat0[$j]}
done
for ((j=0; j<${numTestsPerCategory[1]}; j++))
do
    testsPerCategory[1,$j]=${cat1[$j]}
done
for ((j=0; j<${numTestsPerCategory[2]}; j++))
do
    testsPerCategory[2,$j]=${cat2[$j]}
done
for ((j=0; j<${numTestsPerCategory[3]}; j++))
do
    testsPerCategory[3,$j]=${cat3[$j]}
done
for ((j=0; j<${numTestsPerCategory[4]}; j++))
do
    testsPerCategory[4,$j]=${cat4[$j]}
done
for ((j=0; j<${numTestsPerCategory[5]}; j++))
do
    testsPerCategory[5,$j]=${cat5[$j]}
done
for ((j=0; j<${numTestsPerCategory[6]}; j++))
do
    testsPerCategory[6,$j]=${cat6[$j]}
done
for ((j=0; j<${numTestsPerCategory[7]}; j++))
do
    testsPerCategory[7,$j]=${cat7[$j]}
done

#running all tests and put passed test in CummulativeTestReport.txt
echo "########################################"
echo "Will run tests:"
for test in "${tests[@]}"; do
    echo "######### $(printf "%  30s" "$test")"
done
echo "########################################"

echo ""
echo "Running tests ..."
#running all tests and put passed test in CummulativeTestReport.txt
for test in "${tests[@]}"
do
    echo "########################################"
    echo "######### $(printf "%  30s" "$test")"
    echo "########################################"
    ./$test
done

# traversing CummulativeTestReport.txt to find number
# of tests passed per category
while read passedTest; do
    for ((i=0; i<$numCategories; i++))
    do
	numTestsForCategory=${numTestsPerCategory[i]}
	for ((j=0; j<$numTestsForCategory; j++))
	do
	    testToCompareAgainst=${testsPerCategory[$i,$j]}
	    if [[ "$testToCompareAgainst" == "$passedTest" ]]; then
		numTestsPerCategoryPassed[i]=$((numTestsPerCategoryPassed[i]+1))
	    fi
	done
    done
done <$reportFile

# computing the student's final score
echo ""
echo "----------------------------------------"
echo "Scores per category:"
echo ""
for ((i=0; i<$numCategories; i++))
do
    scorePerCategory=`echo "scale=1; ${numTestsPerCategoryPassed[i]}/${numTestsPerCategory[i]}*${totalPoints[i]}" | bc -l`
    echo "${categories[i]}: passed ${numTestsPerCategoryPassed[i]}/${numTestsPerCategory[i]} = $scorePerCategory points"
    studentScore=`echo "scale=1; $studentScore+$scorePerCategory" | bc -l`
done
echo ""
echo "Total number of points: ${studentScore}/${totalScore}"
echo ""
echo "10 Points for compiling cleanly with -Wall -Werror will be assessed manually."
echo "5 Points for quitting promptly and cleanly will be assessed with a different script."
echo "----------------------------------------"
echo ""
