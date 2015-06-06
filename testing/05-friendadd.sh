#!/usr/bin/env bash
set -o errexit
set -o nounset

TEST=FRIENDADD
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

CNDB=../cndb
if [[ ! -x $CNDB ]]; then
  echo "P5IMS ERROR $TEST: database canonical-izer $CNDB not found" >&2
  exit 1
fi
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
DBC=db-testc.txt;   dieifthere $DBC;  junk $DBC
DB1=db-test1.txt;   dieifthere $DB1;  junk $DB1
DB1C=db-test1c.txt; dieifthere $DB1C; junk $DB1C
DB2=db-test2.txt;   dieifthere $DB2;  junk $DB2
DB2C=db-test2c.txt; dieifthere $DB2C; junk $DB2C
CINA=inA.txt; dieifthere $CINA; junk $CINA
CINB=inB.txt; dieifthere $CINB; junk $CINB
CINC=inC.txt; dieifthere $CINC; junk $CINC
CIND=inD.txt; dieifthere $CIND; junk $CIND
COUTA=outA.txt; dieifthere $COUTA; junk $COUTA
COUTB=outB.txt; dieifthere $COUTB; junk $COUTB
COUTC=outC.txt; dieifthere $COUTC; junk $COUTC
COUTD=outD.txt; dieifthere $COUTD; junk $COUTD
WANTA=wantA.txt; dieifthere $WANTA; junk $WANTA
WANTB=wantB.txt; dieifthere $WANTB; junk $WANTB
WANTC=wantC.txt; dieifthere $WANTC; junk $WANTC
WANTD=wantD.txt; dieifthere $WANTD; junk $WANTD
GOTA=gotA.txt; dieifthere $GOTA; junk $GOTA
GOTB=gotB.txt; dieifthere $GOTB; junk $GOTB
GOTC=gotC.txt; dieifthere $GOTC; junk $GOTC
GOTD=gotD.txt; dieifthere $GOTD; junk $GOTD
LOG=log.txt; dieifthere $LOG; junk $LOG

UA=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UB=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UC=UU_$(printf %06u $[ $RANDOM % 1000000 ])
UD=UU_$(printf %06u $[ $RANDOM % 1000000 ])

cat > $DB1 <<EOF
4 users:
$UA
.
$UB
.
$UC
.
$UD
.
EOF

cat > $DB2 <<EOF
4 users:
$UA
- $UB requested
.
$UB
- $UA toanswer
- $UC
.
$UC
- $UB
- $UD requested
.
$UD
- $UC toanswer
.
EOF

$CNDB $DB1 > $DB1C
$CNDB $DB2 > $DB2C

# (stitching together the commands here with the expected results in WANTA)
# Time: command        --> expected result
#                          (explanation)
#    0: login $UA
#    1: req $UB        --> *** $UB: FRIEND_REQUESTED ***
#    7: logout
cat > $CINA <<EOF
login $UA
  sleep 1
req $UB
  sleep 6
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTB)
# Time: command        --> expected result
#                          (explanation)
#    0: login $UB
#    1:                --> *** $UA: FRIEND_TOANSWER ***
#                          (just got friend request from $UA)
#    2: req $UC        --> *** $UC: FRIEND_REQUESTED ***
#    4:                --> *** friend $UC: ACTIVE_YES ***
#                           ($UC just did "req $UB")
#    6: logout
cat > $CINB <<EOF
login $UB
  sleep 2
req $UC
  sleep 4
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTC)
# Time: command        --> expected result
#                          (explanation)
#    3: login $UC      --> *** $UB: FRIEND_TOANSWER ***
#                          (friend request from $UB)
#    4: req $UB        --> *** friend $UB: ACTIVE_YES ***
#                          (now friends with $UB, we learn $UB is logged in)
#    5: req $UD        --> *** $UD: FRIEND_REQUESTED ***
#    6:                --> *** friend $UB: ACTIVE_NOT ***
#                          ($UB just logged out)
#    7: logout
cat > $CINC <<EOF
  sleep 3
login $UC
  sleep 1
req $UB
  sleep 1
req $UD
  sleep 2
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTD)
# Time: command        --> expected result
#                          (explanation)
#    0: login $UD
#    5:                --> *** $UC: FRIEND_TOANSWER ***
#                          (friend request from $UC)
#    6: logout
cat > $CIND <<EOF
login $UD
  sleep 6
logout
  sleep 1
EOF

PAUSE=2
cp $DB1 $DB
PORT=$[ 5000 + ($RANDOM % 3000)]
(sleep 10; echo quit) | $IMS -p $PORT -d $DB -i $PAUSE &> $LOG &
IMSPID=$!
sleep 1


echo "vvvvvvvvvvvvvvvvvvvvv txtimc inputs:"
cat $CINA
echo "====================="
cat $CINB
echo "====================="
cat $CINC
echo "====================="
cat $CIND
echo "^^^^^^^^^^^^^^^^^^^^^"

$TXTIMC -s localhost -p $PORT -q < $CINA &> $COUTA &
CLIAPID=$!
$TXTIMC -s localhost -p $PORT -q < $CINB &> $COUTB &
CLIBPID=$!
$TXTIMC -s localhost -p $PORT -q < $CINC &> $COUTC &
CLICPID=$!
$TXTIMC -s localhost -p $PORT -q < $CIND &> $COUTD &
CLIDPID=$!
wait $CLIAPID
wait $CLIBPID
wait $CLICPID
wait $CLIDPID

(grep "^ \*\*\* " $COUTA > $GOTA ||:)
(grep "^ \*\*\* " $COUTB > $GOTB ||:)
(grep "^ \*\*\* " $COUTC > $GOTC ||:)
(grep "^ \*\*\* " $COUTD > $GOTD ||:)


echo "vvvvvvvvvvvvvvvvvvvvv got status+error messages:"
cat $GOTA
echo "====================="
cat $GOTB
echo "====================="
cat $GOTC
echo "====================="
cat $GOTD
echo "^^^^^^^^^^^^^^^^^^^^^"

cat > $WANTA<<EOF
 *** $UB: FRIEND_REQUESTED ***
EOF

cat > $WANTB<<EOF
 *** $UA: FRIEND_TOANSWER ***
 *** $UC: FRIEND_REQUESTED ***
 *** friend $UC: ACTIVE_YES ***
EOF

cat > $WANTC<<EOF
 *** $UB: FRIEND_TOANSWER ***
 *** friend $UB: ACTIVE_YES ***
 *** $UD: FRIEND_REQUESTED ***
 *** friend $UB: ACTIVE_NOT ***
EOF

cat > $WANTD<<EOF
 *** $UC: FRIEND_TOANSWER ***
EOF


echo "vvvvvvvvvvvvvvvvvvvvv wanted status+error messages:"
cat $WANTA
echo "====================="
cat $WANTB
echo "====================="
cat $WANTC
echo "====================="
cat $WANTD
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "==== done waiting on clients, now sleep $[$PAUSE+2] to make sure $DB is updated"
sleep $[$PAUSE+2]

echo "vvvvvvvvvvvvvvvvvvvvv new database $DB"
cat $DB
echo "====================="

$CNDB $DB > $DBC

echo "vvvvvvvvvvvvvvvvvvvvv database difference (should be nothing)"
$CNDB $DBC $DB2C | sed 's/^.*\///'
echo "^^^^^^^^^^^^^^^^^^^^^"
! $CNDB $DBC $DB2C > /dev/null
dbokay=$?

! diff $WANTA $GOTA > /dev/null
okayA=$?
! diff $WANTB $GOTB > /dev/null
okayB=$?
! diff $WANTC $GOTC > /dev/null
okayC=$?
! diff $WANTD $GOTD > /dev/null
okayD=$?

echo P5IMS TEST $TEST: DB $dbokay
echo P5IMS TEST $TEST: STATA $okayA
echo P5IMS TEST $TEST: STATB $okayB
echo P5IMS TEST $TEST: STATC $okayC
echo P5IMS TEST $TEST: STATD $okayD
