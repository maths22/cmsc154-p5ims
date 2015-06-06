#!/usr/bin/env bash
set -o errexit
set -o nounset

TEST=ERRORS
IMSPID=0
JUNK=""
function junk {
  JUNK="$JUNK $@"
}
function cleanup {
  rm -rf $JUNK
  if [[ $IMSPID > 0 ]]; then
    kill -9 $IMSPID &> /dev/null
  fi
}
trap cleanup err exit int term
function dieifthere {
  if [[ -e $1 ]]; then
    echo "P5IMS ERROR $TEST: $1 exists already; \"rm $1\" to proceed with testing" >&2
    exit 1
 fi
}

IMS=../ims
TXTIMC=../txtimc
if [[ ! -x $IMS ]]; then
  echo "P5IMS ERROR $TEST: don't see $IMS executable" >&2
  exit 1
fi
if [[ ! -x $TXTIMC ]]; then
  echo "P5IMS ERROR $TEST: don't see $TXTIMC executable" >&2
  exit 1
fi

DB=db-test.txt;     dieifthere $DB;   junk $DB
CINA=inA.txt; dieifthere $CINA; junk $CINA
CINB=inB.txt; dieifthere $CINB; junk $CINB
COUTA=outA.txt; dieifthere $COUTA; junk $COUTA
COUTB=outB.txt; dieifthere $COUTB; junk $COUTB
WANTA=wantA.txt; dieifthere $WANTA; junk $WANTA
WANTB=wantB.txt; dieifthere $WANTB; junk $WANTB
GOTA=gotA.txt; dieifthere $GOTA; junk $GOTA
GOTB=gotB.txt; dieifthere $GOTB; junk $GOTB
LOG=log.txt; dieifthere $LOG; junk $LOG

UA=UU_$(printf %04u $[ $RANDOM % 10000 ])
UB=UU_$(printf %04u $[ $RANDOM % 10000 ])
UC=UU_$(printf %04u $[ $RANDOM % 10000 ])  # not a registered user

echo "0 users:" > $DB

badU=$(cat /dev/urandom | tr -dc [:graph:] | head -c40) # too long

# (stitching together the commands here with the expected results in WANTA)
# Time: command        --> expected result
#                          (explanation)
#    0: raw XXXX$badU  --> !!! ERROR BAD_COMMAND !!!
#                          (because its garbage)
#    1: register $UA   --> "2 1 $UA" (ACK REGISTER $UA)
#                          (all's well)
#    2: register $UB   --> !!! ERROR USER_EXISTS $UB !!!
#                          ($UB already in database)
#    3: register $badU --> !!! ERROR BAD_COMMAND !!!
#                          (because that username is too long)
#    4: login $UC      --> !!! ERROR USER_DOES_NOT_EXIST !!!
#                          (because that $UC is not in database)
#    5: login $UB      --> !!! ERROR USER_ALREADY_ACTIVE $UB !!!
#                          (because $UB has logged in on clientB)
#    6: login $UA      --> "2 2 $UA" (ACK LOGIN $UA)
#                          (all's well)
#    7: rm $UB         --> !!! ERROR NOT_FRIEND $UB !!!
#                          (because $UA and $UB aren't friends)
#    8: req $UB        --> *** $UB: FRIEND_REQUESTED ***
#                          (all's well)
#    9: req $UB        --> !!! ERROR REQUESTED_ALREADY $UB !!!
#                          (because of previous friend request)
#   11:                --> *** friend $UB: ACTIVE_YES ***
#                          (because $UB on 2nd client just responded
#                           to our friend request)
#   13: logout         --> "2 3" (ACK LOGOUT)
#                          (all's well)
cat > $CINA <<EOF
raw XXXX$badU
  sleep 1
register $UA
  sleep 1
register $UB
  sleep 1
register $badU
  sleep 1
login $UC
  sleep 1
login $UB
  sleep 1
login $UA
  sleep 1
rm $UB
  sleep 1
req $UB
  sleep 1
req $UB
  sleep 4
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTB)
# Time: command        --> expected result
#                          (explanation)
#    0: logout         --> !!! ERROR CLIENT_NOT_BOUND !!!
#                          (because no one is logged in)
#    1: register $UB   --> "2 1 $UB" (ACK REGISTER $UB)
#                          (all's well)
#    2: login $UB      --> "2 2 $UB" (ACK LOGIN $UB)
#                          *** $UA: FRIEND_TOANSWER ***
#                          (we receive the friend request from $UA upon logging in)
#   10: req $UB        --> !!! ERROR BAD_COMMAND !!!
#                          (because we're logged in as $UB!)
#   11: req $UA        --> *** friend $UA: ACTIVE_YES ***
#                          (because new friend $UA is on clientA)
#   12: req $UA        --> !!! ERROR FRIEND_ALREADY $UA !!!
#                          (because we're already friends with $UA)
#   13:                --> *** friend $UA: ACTIVE_NOT ***
#                          (because $UA just logged out)
#   14: logout         --> "2 3" (ACK LOGOUT)
cat > $CINB <<EOF
logout
  sleep 1
register $UB
  sleep 1
login $UB
  sleep 8
req $UB
  sleep 1
req $UA
  sleep 1
req $UA
  sleep 2
logout
  sleep 1
EOF

PORT=$[ 5000 + ($RANDOM % 3000)]
(tail -f /dev/null) | $IMS -p $PORT -d $DB &> $LOG &
IMSPID=$!
sleep 1

echo "vvvvvvvvvvvvvvvvvvvvv txtimc inputs:"
cat $CINA
echo "====================="
cat $CINB
echo "^^^^^^^^^^^^^^^^^^^^^"

$TXTIMC -s localhost -p $PORT < $CINA &> $COUTA &
CLIAPID=$!
$TXTIMC -s localhost -p $PORT < $CINB &> $COUTB &
CLIBPID=$!
wait $CLIAPID
wait $CLIBPID

cat > $WANTA <<EOF
"2 8" (ACK CONNECT)
 !!! ERROR BAD_COMMAND !!!
"2 1 $UA" (ACK REGISTER $UA)
 !!! ERROR USER_EXISTS $UB !!!
 !!! ERROR BAD_COMMAND !!!
 !!! ERROR USER_DOES_NOT_EXIST !!!
 !!! ERROR USER_ALREADY_ACTIVE $UB !!!
"2 2 $UA" (ACK LOGIN $UA)
 !!! ERROR NOT_FRIEND $UB !!!
 *** $UB: FRIEND_REQUESTED ***
 !!! ERROR REQUESTED_ALREADY $UB !!!
 *** friend $UB: ACTIVE_YES ***
"2 3" (ACK LOGOUT)
EOF

cat > $WANTB <<EOF
"2 8" (ACK CONNECT)
 !!! ERROR CLIENT_NOT_BOUND !!!
"2 1 $UB" (ACK REGISTER $UB)
"2 2 $UB" (ACK LOGIN $UB)
 *** $UA: FRIEND_TOANSWER ***
 !!! ERROR BAD_COMMAND !!!
 *** friend $UA: ACTIVE_YES ***
 !!! ERROR FRIEND_ALREADY $UA !!!
 *** friend $UA: ACTIVE_NOT ***
"2 3" (ACK LOGOUT)
EOF

(grep "[\*\!A][\*\!C][\*\!K] " $COUTA | sed s/server\ response\ [0-9]:\ //g > $GOTA ||:)
(grep "[\*\!A][\*\!C][\*\!K] " $COUTB | sed s/server\ response\ [0-9]:\ //g > $GOTB ||:)

echo "vvvvvvvvvvvvvvvvvvvvv wanted status+error messages:"
cat $WANTA
echo "====================="
cat $WANTB
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "vvvvvvvvvvvvvvvvvvvvv got status+error messages:"
cat $GOTA
echo "====================="
cat $GOTB
echo "^^^^^^^^^^^^^^^^^^^^^"

! diff $WANTA $GOTA > /dev/null
okayA=$?
! diff $WANTB $GOTB > /dev/null
okayB=$?

echo P5IMS TEST $TEST: A $okayA
echo P5IMS TEST $TEST: B $okayB
