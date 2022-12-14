#!/bin/bash

# vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
# This code/script/configuration example is provided on an "as is" basis,      *
# without warranty of any kind, to the fullest extent permitted by law.        *
#                                                                              *
# ForgeRock does not warrant or guarantee the individual success               *
# developers/operators may have in implementing the code/script/configuration  *
# on their platforms or in production configurations.                          *
#                                                                              *
# ForgeRock does not warrant, guarantee or make any representations regarding  *
# the use, results of use, accuracy, timeliness or completeness of any data    *
# or information relating to the release of unsupported code.                  *
#                                                                              *
# ForgeRock disclaims all warranties, expressed or implied, and in particular, *
# disclaims all warranties of merchantability, and warranties related to the   *
# code/script/configuration, or any service or software related thereto.       *
#                                                                              *
# ForgeRock shall not be liable for any direct, indirect or consequential      *
# damages or costs of any type arising out of any action taken by you or       *
# others related to the code.                                                  *
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

# Change to meet your environment
DSHOME="$HOME/opendj"
STARRATERUNNERHOME="$HOME/starrate"
DSBIN="$DSHOME/bin"
DSCONFIG="$DSHOME/config"
HOSTNAME="rmfdsrswu0 rmfdsrswu1"
HOSTNAME="rmfdsrseu0 rmfdsrsne0 rmfdsrsne1 rmfdsrssa0"
PORT=1636
BINDDN="uid=admin"
PASSWORD='password'
BASEDN="dc=example,dc=com"
BINDDN="uid=admin"
BINDPW="password"
DSHOST="rmfdsrswu0"
DSPORT=1636
################################
# Specific for bulk group MODIFY
GROUPDSHOST="rmfdsrseu0"
GROUPS=1
OBJECTS=200
MODGROUPTHREADS=1
MODGROUPDELAY=2

# addrate only attributes and values
DSADDTEMPLATE="$STARRATERUNNERHOME/addrate.template"

# modrate only attributes and values
# Setting to telephoneNumber and setting to a random string will generate errors as the string may only contain letters
ATTRIBUTE2MOD="description"

#############################
# Things to change per test #
RUNAUTHN=true
RUNADD=true
RUNMODIFY=true
RUNSEARCH=false
RUNSEARCHEXACT=true
RUNSEARCHWILDCARD=true
RUNMODGROUP=true

# If true only execute one *rate at a time
# If false execute *rate commands set to true above simultaneously
SERIAL=false
VERBOSE=true

# Scope of objects to use #
LOWRANGE=256
HIGHRANGE=500256

# Number of connections to open
NUMCONNECT=4

# Number of concurrent threads to use
NUMCONCUR=4

# How long to run the test in seconds
MAXDURATION=30

# How many times to rerun the test
MAXITERATIONS=2

# ADD rate target
addtarget=1
# How much to increment when rerunning
ADDINCREMENT=1

# Auth rate target
authntarget=90
# How much to increment when rerunning
AUTHNINCREMENT=4

# MODIFY rate target
modifytarget=1
# How much to increment when rerunning
MODIFYINCREMENT=1

# SEARCH rate target
searchtarget=200
searchexacttarget=200
searchwildcardtarget=100
# How much to increment when rerunning
SEARCHINCREMENT=100
SEARCHNUMCONNECT=4
SEARCHNUMCONCUR=4

SEARCHEXACTINCREMENT=100
SEARCHEXACTNUMCONNECT=4
SEARCHEXACTNUMCONCUR=4

SEARCHWILDCARDINCREMENT=100
SEARCHWILDCARDNUMCONNECT=4
SEARCHWILDCARDNUMCONCUR=4

# DELETEMODE="random"
DELETEMODE="fifo"
# DELETEMODE="off"
DELETESIZETHRESHOLD=100
DELETEAGETHRESHOLD=1000

USECOMMA=true
######################################
# Things that should not be changed  #
# unless you know what you are doing #
MIT=$(date | tr -cd '[:alnum:]')
OUTPUTHOME=$STARRATERUNNERHOME/run-$MIT
mkdir $OUTPUTHOME
OUTPUTTMP=$OUTPUTHOME/tmp
mkdir $OUTPUTTMP
OPTYPES="add authn mod searchexact searchwildcard search"
LABEL="NET"
STATINTERVAL=1
SLEEP=$STATINTERVAL
######################################
# Not presently used                 #
# MAXCONNECT=1
# MAXCONCUR=1
# DELETETARGETTHROUGHPUT=20
# TARGETTHROUGHPUT=10
# --control TransactionId:false:"$(hostname -f)-xyz123-$(date +%s)"
######################################
# End of configurable settings
######################################

# Start of pinger
pinger() {
  counter=1
  while true; do
    if [ "$USECOMMA" = true ]; then
      if (($counter == 1)); then
        echo -n "$(hostname)," >>$OUTPUTHOME/ping.csv
        for host in $HOSTNAME; do
          echo -n "$host-ping," >>$OUTPUTHOME/ping.csv
        done
        echo "" >>$OUTPUTHOME/ping.csv
      fi
      echo -n "$((counter * SLEEP))," >>$OUTPUTHOME/ping.csv
      for host in $HOSTNAME; do
        p="$(ping -c 1 $host | grep "time=" | cut -d "=" -f 4 | cut -d " " -f 1)"
        echo -n "$p," >>$OUTPUTHOME/ping.csv
      done
      echo "" >>$OUTPUTHOME/ping.csv
      ((counter++))
      sleep $SLEEP
    else
      if ! (($counter % 20)); then
        echo "Generated by $(hostname -f)" >>$OUTPUTHOME/ping.txt
        for host in $HOSTNAME; do
          sl=${#host}
          printf "%$(echo $sl)s" "$host | " >>$OUTPUTHOME/ping.txt
        done
        echo "" >>$OUTPUTHOME/ping.txt
      fi
      for host in $HOSTNAME; do
        p="$(ping -c 1 $host | grep "time=" | cut -d "=" -f 4)"
        sl=${#host}
        printf "%$(echo $((sl + 3)))s" "$p | " >>$OUTPUTHOME/ping.txt
      done
      ((counter++))
      sleep $SLEEP
      echo "" >>$OUTPUTHOME/ping.txt
    fi
  done
}
# end of pinger

# start of bulkmodgroup
bulkmodgroup() {
  group=$1
  thread=$2
  object=0
  newdate="$(date --utc +%FT%T.%3NZ)"
  newepoch=$(date +%s%3N)
  ~/opendj/bin/ldapmodify --hostname ${GROUPDSHOST} --port ${DSPORT} \
    --bindDN ${BINDDN} --bindPassword ${BINDPW} \
    --useSsl --trustAll <<EOF
dn: cn=group-${LABEL}-${iteration}-${thread}-${group},ou=Groups,dc=example,dc=com
cn: group-${LABEL}-${iteration}-${thread}-${group}
objectClass: groupOfNames
objectClass: top
ou: Groups
EOF
  echo "dn: cn=group-${LABEL}-${iteration}-${thread}-${group},ou=Groups,dc=example,dc=com" >${OUTPUTTMP}/group-${LABEL}-${iteration}-${thread}-${group}.ldif
  echo "changetype: modify" >>${OUTPUTTMP}/group-${LABEL}-${iteration}-${thread}-${group}.ldif
  echo "add: member" >>${OUTPUTTMP}/group-${LABEL}-${iteration}-${thread}-${group}.ldif
  while [[ ${object} -le ${OBJECTS} ]]; do
    echo "member: uid=user.${object},ou=People,dc=example,dc=com" >>${OUTPUTTMP}/group-${LABEL}-${iteration}-${thread}-${group}.ldif
    ((object++))
  done
  echo "" >>${OUTPUTTMP}/group-${LABEL}-${iteration}-${thread}-${group}.ldif
  sleep ${MODGROUPDELAY}
  ~/opendj/bin/ldapmodify --hostname ${GROUPDSHOST} --port ${DSPORT} \
    --bindDN ${BINDDN} --bindPassword ${BINDPW} \
    --useSsl --trustAll \
    ${OUTPUTTMP}/group-${LABEL}-${iteration}-${thread}-${group}.ldif
}
# end of bulkmodgroup

# Start of main script
iteration=0
pinger &
pingerpid=$!
echo "Pinger spawned with $pingerpid"

while [ "${iteration}" -le "${MAXITERATIONS}" ]; do
  i=0
  OUTFILE="$LABEL-$iteration"
  if $RUNADD; then
    for host in $HOSTNAME; do
      command="$DSBIN/addrate \
--hostname $host --port $PORT \
--bindDN \"$BINDDN\" --bindPassword \"$PASSWORD\" \
--useSsl --trustAll  \
--statInterval $STATINTERVAL \
--targetThroughput $addtarget \
--scriptFriendly \
--numConnections $NUMCONNECT \
--numConcurrentRequests $NUMCONCUR \
--keepConnectionsOpen \
--noRebind \
--maxDuration $MAXDURATION \
--deleteMode $DELETEMODE \
--deleteSizeThreshold $DELETESIZETHRESHOLD \
$DSADDTEMPLATE"

      if $VERBOSE; then
        echo "Command = $command"
      fi
      if $SERIAL; then
        eval $command >$OUTPUTHOME/add-$OUTFILE-$host.csv.tmp
      else
        eval $command >$OUTPUTHOME/add-$OUTFILE-$host.csv.tmp &
        pids[${i}]=$!
        ((i++))
      fi
    done
  fi

  if $RUNAUTHN; then
    for host in $HOSTNAME; do
      command="$DSBIN/authrate \
--hostname $host --port $PORT \
--bindDN \"uid=user.{},ou=people,dc=example,dc=com\" --bindPassword \"$PASSWORD\" \
--useSsl --trustAll  \
--statInterval $STATINTERVAL \
--targetThroughput $authntarget \
--scriptFriendly \
--baseDn \"$BASEDN\" \
--keepConnectionsOpen \
--numConnections $NUMCONNECT \
--maxDuration $MAXDURATION \
--argument \"rand($LOWRANGE,$HIGHRANGE)\""

      if $VERBOSE; then
        echo "Command = $command"
      fi
      if $SERIAL; then
        eval $command >$OUTPUTHOME/authn-$OUTFILE-$host.csv
      else
        eval $command >$OUTPUTHOME/authn-$OUTFILE-$host.csv &
        pids[${i}]=$!
        ((i++))
      fi
    done
  fi

  if $RUNMODIFY; then
    for host in $HOSTNAME; do
      command="$DSBIN/modrate \
--hostname $host --port $PORT \
--bindDN \"$BINDDN\" --bindPassword \"$PASSWORD\" \
--useSsl --trustAll  \
--statInterval $STATINTERVAL \
--targetThroughput $modifytarget \
--scriptFriendly \
--noRebind \
--numConnections $NUMCONNECT \
--numConcurrentRequests $NUMCONCUR \
--maxDuration $MAXDURATION \
--argument \"rand($LOWRANGE,$HIGHRANGE)\" --targetDn \"uid=user.{1},ou=people,dc=example,dc=com\" \
--argument \"randstr(16)\" 'description:{2}'"

      if $VERBOSE; then
        echo "Command = $command"
      fi
      if $SERIAL; then
        eval $command >$OUTPUTHOME/mod-$OUTFILE-$host.csv
      else
        eval $command >$OUTPUTHOME/mod-$OUTFILE-$host.csv &
        pids[${i}]=$!
        ((i++))
      fi
    done
  fi

  if $RUNSEARCHEXACT; then
    for host in $HOSTNAME; do
      command="$DSBIN/searchrate \
--hostname $host --port $PORT \
--bindDN \"$BINDDN\" --bindPassword \"$PASSWORD\" \
--useSsl --trustAll \
--statInterval $STATINTERVAL \
--targetThroughput $searchexacttarget \
--scriptFriendly \
--baseDn \"$BASEDN\" \
--noRebind \
--numConnections $SEARCHEXACTNUMCONNECT \
--numConcurrentRequests $SEARCHEXACTNUMCONCUR \
--maxDuration $MAXDURATION \
--argument \"rand($LOWRANGE,$HIGHRANGE)\" \"(uid=user.{1})\""

      if $VERBOSE; then
        echo "Command = $command"
      fi
      if $SERIAL; then
        eval $command >$OUTPUTHOME/searchexact-$OUTFILE-$host.csv
      else
        eval $command >$OUTPUTHOME/searchexact-$OUTFILE-$host.csv &
        pids[${i}]=$!
        ((i++))
      fi
    done
  fi

  if $RUNSEARCHWILDCARD; then
    for host in $HOSTNAME; do
      command="$DSBIN/searchrate \
--hostname $host --port $PORT \
--bindDN \"$BINDDN\" --bindPassword \"$PASSWORD\" \
--useSsl --trustAll \
--statInterval $STATINTERVAL \
--targetThroughput $searchwildcardtarget \
--scriptFriendly \
--baseDn \"$BASEDN\" \
--noRebind \
--numConnections $SEARCHWILDCARDNUMCONNECT \
--numConcurrentRequests $SEARCHWILDCARDNUMCONCUR \
--maxDuration $MAXDURATION \
--argument \"rand($LOWRANGE,$HIGHRANGE)\" \"(uid=user.{1}*)\""

      if $VERBOSE; then
        echo "Command = $command"
      fi
      if $SERIAL; then
        eval $command >$OUTPUTHOME/searchwildcard-$OUTFILE-$host.csv
      else
        eval $command >$OUTPUTHOME/searchwildcard-$OUTFILE-$host.csv &
        pids[${i}]=$!
        ((i++))
      fi
    done
  fi


  if $RUNSEARCH; then
    for host in $HOSTNAME; do
      command="$DSBIN/searchrate \
--hostname $host --port $PORT \
--bindDN \"$BINDDN\" --bindPassword \"$PASSWORD\" \
--useSsl --trustAll \
--statInterval $STATINTERVAL \
--targetThroughput $searchtarget \
--scriptFriendly \
--baseDn \"$BASEDN\" \
--noRebind \
--numConnections $SEARCHNUMCONNECT \
--numConcurrentRequests $SEARCHNUMCONCUR \
--maxDuration $MAXDURATION \
--argument \"rand($LOWRANGE,$HIGHRANGE)\" \"(uid=user.{1})\""

      if $VERBOSE; then
        echo "Command = $command"
      fi
      if $SERIAL; then
        eval $command >$OUTPUTHOME/search-$OUTFILE-$host.csv
      else
        eval $command >$OUTPUTHOME/search-$OUTFILE-$host.csv &
        pids[${i}]=$!
        ((i++))
      fi
    done
  fi

  if $RUNADD; then
    echo "ADD target = $addtarget"
  fi
  if $RUNAUTHN; then
    echo "Authentication target = $authntarget"
  fi
  if $RUNMODIFY; then
    echo "MODIFY target = $modifytarget"
  fi
  if $RUNSEARCHEXACT; then
    echo "SEARCH exact target = $searchexacttarget"
  fi
  if $RUNSEARCHWILDCARD; then
    echo "SEARCH wildcard target = $searchwildcardtarget"
  fi
  if $RUNSEARCH; then
    echo "SEARCH target = $searchtarget"
  fi

  if $RUNMODGROUP; then
    group=0
    thread=0
    echo -n >${OUTPUTTMP}/deletegroup-${LABEL}-${iteration}.sh
    while [[ ${group} -le ${groups} ]]; do
      while [[ ${thread} -le ${threads} ]]; do
        bulkmodgroup ${group} ${thread} &
        pids[${i}]=$!
        ((i++))
        echo "~/opendj/bin/ldapdelete --hostname ${GROUPDSHOST} --port ${DSPORT} \
        --bindDN ${BINDDN} --bindPassword ${BINDPW} --useSsl --trustAll \
         \"cn=group-${LABEL}-${iteration}-${thread}-${group},ou=Groups,dc=example,dc=com\" & " >>${OUTPUTTMP}/deletegroup-${LABEL}-${iteration}.sh
        ((thread++))
      done
      echo "wait" >>${OUTPUTTMP}/deletegroup-${LABEL}-${iteration}.sh
      thread=0
      ((group++))
    done
    echo "Running MODIFY Group(s)"
  fi

  echo "Waiting for operations to complete..."
  for pid in ${pids[*]}; do
    wait $pid
    echo -n "."
  done
  echo "...completed."
  addtarget=$((addtarget + $ADDINCREMENT))
  authntarget=$((authntarget + $AUTHNINCREMENT))
  modifytarget=$((modifytarget + $MODIFYINCREMENT))
  searchexacttarget=$((searchexacttarget + $SEARCHEXACTINCREMENT))
  searchwildcardtarget=$((searchwildcardtarget + $SEARCHWILDCARDINCREMENT))
  searchtarget=$((searchtarget + $SEARCHINCREMENT))
  ((iteration++))
done
kill $pingerpid

# ./ldapsearch --hostname rmfdsrswu0 --port 1636 --bindDn "uid=admin" --bindPassword password --trustAll --useSsl --baseDn "ou=Groups,dc=example,dc=com" "(objectclass=*)" "*"
# ./bin/ldapsearch --hostname $(hostname) --port 1636 --bindDn "uid=admin" --bindPassword password --trustAll --useSsl --baseDn "dc=example,dc=com" "(uid=user.77*)" | grep -c "^dn: "
if $RUNADD; then
  for host in $HOSTNAME; do
    iteration=0
    while [ "${iteration}" -le "${MAXITERATIONS}" ]; do
      OUTFILE="$LABEL-$iteration"
      cat $OUTPUTHOME/add-$OUTFILE-$host.csv.tmp | grep -vi purge >$OUTPUTHOME/add-$OUTFILE-$host.csv
      ((iteration++))
    done
  done
  rm $OUTPUTHOME/add-*.csv.tmp
fi

echo -n "Processing csv files..."
for host in $HOSTNAME; do
  for optype in $OPTYPES; do
    firstrun=true
    for file in $(ls $OUTPUTHOME/$optype-*-$host.csv 2>/dev/null); do
      if $firstrun; then
        echo "$host-$optype-ops,$host-$optype-time" >$OUTPUTHOME/$host-$optype-all.csv.tmp
        echo "$(tail -n +2 $file | cut -d "," -f 3,5)" >>$OUTPUTHOME/$host-$optype-all.csv.tmp
        firstrun=false
      else
        echo "$(tail -n +2 $file | cut -d "," -f 3,5)" >>$OUTPUTHOME/$host-$optype-all.csv.tmp
      fi
    done
    cat $OUTPUTHOME/$host-$optype-all.csv.tmp 2>/dev/null | sed 's/$/,/' >$OUTPUTHOME/$host-$optype-all.csv
    rm $OUTPUTHOME/$host-$optype-all.csv.tmp 2>/dev/null
    echo -n "."
  done
done

files=$(ls $OUTPUTHOME/*-all.csv)
i=1
while read line; do
  echo -n $line >>$OUTPUTHOME/results.csv
  for file in $files; do
    echo -n $(head -n $i $file | tail -n+$i) >>$OUTPUTHOME/results.csv
  done
  echo "" >>$OUTPUTHOME/results.csv
  ((i++))
  echo -n "."
done <$OUTPUTHOME/ping.csv
echo "...completed."
