#!/usr/bin/env bash
set -o errexit
set -o nounset

TEST=FRIENDRM
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
WANTB0=wantB0.txt; dieifthere $WANTB0; junk $WANTB0
WANTB1=wantB1.txt; dieifthere $WANTB1; junk $WANTB1
WANTC0=wantC0.txt; dieifthere $WANTC0; junk $WANTC0
WANTC1=wantC1.txt; dieifthere $WANTC1; junk $WANTC1
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

cat > $DB2 <<EOF
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


$CNDB $DB1 > $DB1C
$CNDB $DB2 > $DB2C

# (stitching together the commands here with the expected results in WANTA)
# Time: command        --> expected result
#                          (explanation)
#    0: login $UA      --> *** $UB: FRIEND_REQUESTED ***
#                          (a reminder of our friend request to $UB)
#    3: rm $UB         --> *** $UB: FRIEND_NOT ***
#                          (we cancel friend request to $UB)
#    7: logout
cat > $CINA <<EOF
login $UA
  sleep 3
rm $UB
  sleep 4
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTB)
# Time: command        --> expected result
#                          (explanation)
#    1: login $UB      --> *** $UA: FRIEND_TOANSWER ***
#                          ($UA has friend requested us)
#                      --> *** friend $UC: ACTIVE_NOT ***
#                          (friend $UC isn't logged in)
#                          (previous two lines can be in either order)
#    2:                --> *** friend $UC: ACTIVE_YES ***
#                          (friend $UC has logged in)
#    3:                --> *** $UA: FRIEND_NOT ***
#                          ($UA cancelled friend request to us)
#    4: rm $UC         --> *** $UC: FRIEND_NOT ***
#                          (we defriend $UC)
#    6: logout
cat > $CINB <<EOF
  sleep 1
login $UB
  sleep 3
rm $UC
  sleep 2
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTC)
# Time: command        --> expected result
#                          (explanation)
#    2: login $UC      --> *** friend $UB: ACTIVE_YES ***
#                          (friend $UB is logged in)
#                      --> *** $UD: FRIEND_REQUESTED ***
#                          (reminder of friend request to $UD)
#                          (previous two lines can be in either order)
#    4:                --> *** $UB: FRIEND_NOT ***
#                          ($UB defriended us)
#    5:                --> *** $UD: FRIEND_NOT ***
#                          ($UD rejected our friend request)
#    7: logout
cat > $CINC <<EOF
  sleep 2
login $UC
  sleep 5
logout
  sleep 1
EOF

# (stitching together the commands here with the expected results in WANTD)
# Time: command        --> expected result
#                          (explanation)
#    4: login $UD      --> *** $UC: FRIEND_TOANSWER ***
#                          (have friend request from $UC)
#    5: rm $UC         --> *** $UC: FRIEND_NOT ***
#                          (we reject the friend request)
#    6: logout
cat > $CIND <<EOF
  sleep 4
login $UD
  sleep 1
rm $UC
  sleep 1
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

$TXTIMC -s localhost -p $PORT < $CINA &> $COUTA &
CLIAPID=$!
$TXTIMC -s localhost -p $PORT < $CINB &> $COUTB &
CLIBPID=$!
$TXTIMC -s localhost -p $PORT < $CINC &> $COUTC &
CLICPID=$!
$TXTIMC -s localhost -p $PORT < $CIND &> $COUTD &
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
 *** $UB: FRIEND_NOT ***
EOF

cat > $WANTB0<<EOF
 *** $UA: FRIEND_TOANSWER ***
 *** friend $UC: ACTIVE_NOT ***
 *** friend $UC: ACTIVE_YES ***
 *** $UA: FRIEND_NOT ***
 *** $UC: FRIEND_NOT ***
EOF

# different ordering of friend status messages upon login
cat > $WANTB1<<EOF
 *** friend $UC: ACTIVE_NOT ***
 *** $UA: FRIEND_TOANSWER ***
 *** friend $UC: ACTIVE_YES ***
 *** $UA: FRIEND_NOT ***
 *** $UC: FRIEND_NOT ***
EOF

cat > $WANTC0<<EOF
 *** friend $UB: ACTIVE_YES ***
 *** $UD: FRIEND_REQUESTED ***
 *** $UB: FRIEND_NOT ***
 *** $UD: FRIEND_NOT ***
EOF

# different ordering of friend status messages upon login
cat > $WANTC1<<EOF
 *** $UD: FRIEND_REQUESTED ***
 *** friend $UB: ACTIVE_YES ***
 *** $UB: FRIEND_NOT ***
 *** $UD: FRIEND_NOT ***
EOF

cat > $WANTD<<EOF
 *** $UC: FRIEND_TOANSWER ***
 *** $UC: FRIEND_NOT ***
EOF

echo "vvvvvvvvvvvvvvvvvvvvv wanted status+error messages:"
cat $WANTA
echo "====================="
cat $WANTB0
echo "====================="
cat $WANTC0
echo "====================="
cat $WANTD
echo "^^^^^^^^^^^^^^^^^^^^^"

echo "==== done waiting on clients, now sleep $[$PAUSE+2] to make sure $DB is updated"
sleep $[$PAUSE+2]

echo "vvvvvvvvvvvvvvvvvvvvv new database $DB"
cat $DB
echo "====================="

$CNDB $DB > $DBC

! diff $DBC $DB2C > /dev/null
dbokay=$?

! diff $WANTA $GOTA > /dev/null
okayA=$?
! diff $WANTB0 $GOTB > /dev/null
okayB0=$?
! diff $WANTB1 $GOTB > /dev/null
okayB1=$?
okayB=$[ $okayB0 + $okayB1 ]
! diff $WANTC0 $GOTC > /dev/null
okayC0=$?
! diff $WANTC1 $GOTC > /dev/null
okayC1=$?
okayC=$[ $okayC0 + $okayC1 ]
! diff $WANTD $GOTD > /dev/null
okayD=$?

echo P5IMS TEST $TEST: DB $dbokay
echo P5IMS TEST $TEST: STATA $okayA
echo P5IMS TEST $TEST: STATB $okayB
echo P5IMS TEST $TEST: STATC $okayC
echo P5IMS TEST $TEST: STATD $okayD
