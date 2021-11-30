#!/bin/bash

BACKUP_SNAPSHOT_NAME="backupkvm"
# Locking
LOCKFILE=/tmp/$(basename $0).pid
function lock {
  if [[ -f $LOCKFILE ]]; then
    pid=$(cat $LOCKFILE)
    if [[ `kill -0 $pid >/dev/null 2>&1` ]]; then
      exit 1
    else
      echo "Stale lock.  Removing"
    fi
   fi

   echo $$ >$LOCKFILE
   local rc=$?
   if [[ $rc -ne 0 ]]; then
    exit 1
   fi
}

function unlock {
  rm -f $LOCKFILE
}

VMNAME=""

usage() {
  echo "Usage: $0 [-c|-s] [ -n VMNAME ]" 1>&2
  echo "    -n Virtual Machine name" 1>&2
  echo "    -c Commin existing snapshot" 1>&2
  echo "    -s Create snapshot of running VM" 1>&2
}

while getopts ":n:sc" options; do
  case "${options}" in
    n)
      VMNAME=${OPTARG}
      ;;
    s)
      SNAPSHOT=true
      ;;
    c)
      COMMIT=true
      ;;
    :)
      echo "Error: -${OPTARG} requires an argument."
      usage
      exit 1
      ;;
    *)
      usage
      exit 1
      ;;
  esac
done

# VMWANE can't be empty
if [[ "$VMNAME" == "" ]]; then
  usage
  exit 1
fi

# There must be one of -c or -s
if [[ -z $COMMIT && -z $SNAPSHOT ]] || [[ -n $COMMIT && -n $SNAPSHOT ]]; then
  usage
  exit 1
fi

lock

action() {
  local filename=$1
}

commit() {
  disk_list=`virsh domblklist ${VMNAME} | grep ${BACKUP_SNAPSHOT_NAME} | awk '{print $1}'`
  for disk in $disk_list; do
    snapshot=`virsh domblklist ${VMNAME} | grep ${BACKUP_SNAPSHOT_NAME} | grep $disk | awk '{print $2}'`
    if [[ ! -z ${snapshot} ]]; then
      virsh blockcommit ${VMNAME} $disk --active --verbose --pivot
      rc=$?
      if [[ $rc -eq 0 ]]; then
        rm $snapshot
      else
        exit 1
      fi
    fi
  done
}

# Check if vm exists and get vm id
VMID=$(virsh list --all | grep " ${VMNAME} " | awk '{print $1}')

if [[ -z ${VMID} ]]; then # No such VM
  echo "No such VM"
  exit 1
elif [[ "${VMID}" == "-" ]]; then # VM exists, but sutted down
  echo "VM exists, but sutted down"
  exit 0
else # VM running or paused
  if [[ $COMMIT ]]; then
    commit
  fi

  if [[ $SNAPSHOT ]]; then
    # If snapshot already exists - commit it
    commit
    # Get qcow images paths before making a snapshot
    disk_path=`virsh domblklist ${VMNAME} | grep qcow2 | awk '{print $2}'`

    # Check if guest-agent is connected
    virsh domtime ${VMNAME} >/dev/null 2>&1
    agent=$?

    # Try to make a snapshot if guest-agent is connected
    if [[ $agent == 0 ]]; then
      virsh snapshot-create-as --domain ${VMNAME} --name ${BACKUP_SNAPSHOT_NAME} --disk-only --atomic --quiesce --no-metadata
      rc=$?
      if [[ $rc -ne 0 ]]; then
        echo "Snapshot creation failed. ${VMNAME}"
        exit 1
      fi
    fi
  fi
fi

unlock
exit 0
