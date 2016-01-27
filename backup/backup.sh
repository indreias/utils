#!/bin/bash

#
# Arguments:
#
# $1 = do | pause | stop (mandatory)
# $2 = backup label (not mandatory, if empty is set to local)
#

#
# My backup tool
#
# ver 1.0 - Jun 2015, Ioan Indreias - initial release
# ver 1.1 - Jan 2016, Ioan Indreias - split configuration, pre and post phases from the main script
#                                   - add backup label (allow multiple jobs to be ran in paralel)
#                                   - check for another job (pre-sync)
#
# TO DO:
# - pause | stop all
#

if [ -n "${DEBUG}" ]
then
  set -x
fi

#
# local functions
#
display_help(){
  cat << EOF

Usage: $(basename "$0") action [label]

  action = start | pause | stop
  label  = label for this job (if not provided is set to 'local')

EOF
}
#
#################

LOCAL_DIR=$(dirname "$0")
MY_NAME=$(basename "$0" ".sh")

BACKUP_LABEL=$2
if [ -z "${BACKUP_LABEL}" ]
then
  BACKUP_LABEL=local
fi

check_file="${LOCAL_DIR}/${MY_NAME}.include"
if [ -f "${check_file}" ]
then
  source "${check_file}"
else
  echo "ERROR: include file '${check_file}' not found"
  exit 90
fi

test $# -ge 1 || { display_help; exit 91; }

load_config ${LOCAL_DIR}/${MY_NAME}.cfg print_error || exit 92
load_config ${LOCAL_DIR}/${BACKUP_LABEL}/${BACKUP_LABEL}.cfg

check_empty "${RSYNC_SOURCE}" "${RSYNC_DESTINATION}" || { echo "ERROR: ${BACKUP_LABEL} wrong configuration (empty values for SOURCE and/or DESTINATION)"; exit 93; }

INCREMENTAL_DEST=${RSYNC_DESTINATION}/${BKP_DEST}
LAST_BACKUP=${INCREMENTAL_DEST}/backup.${MAX_BACKUPS}
STAT_FILE=${INCREMENTAL_DEST}/backup.0/status.info

#
# Create the path for the status file
#
if [ "${RSYNC_DESTINATION_MOUNT}" != "yes" -o $(cat /proc/mounts | grep -c " ${RSYNC_DESTINATION} ") -eq 1 ]
then
  mkdir -p $(dirname ${STAT_FILE})
fi

#
# stop or pause a running rsync job
#
if [ "$1" == "pause" ] || [ "$1" == "stop" ]
then
  process_pid_info=$(process_pid_file $1 "${RSYNC_PID_FILE}")
  if [ $ret_code -eq 0 ]
  then
    echo "$(date) $info" >> ${STAT_FILE} 2>/dev/null
    touch ${INCREMENTAL_DEST}/backup.0
  fi
  to_log "${BACKUP_LABEL} backup ${process_pid_info}"
  # Nothing else to do - we should exit now
  exit $ret_code
fi

#
# Check if destination is on a mounted filesystem
#
if [ "${RSYNC_DESTINATION_MOUNT}" == "yes" ]
then
  blk_info=$(/sbin/blkid ${RSYNC_DESTINATION_DEVICE})
else
  blk_info=${RSYNC_DESTINATION}
fi
if [ ! -s "${RSYNC_PID_FILE}" -a "${RSYNC_DESTINATION_MOUNT}" == "yes" -a $(cat /proc/mounts | grep -c " ${RSYNC_DESTINATION} ") -ne 1 ]
then
  #
  # Check if we should partition and format the destination device
  #
  if [ "${RSYNC_DESTINATION_FORMAT}" == "yes" -a $(echo "$blk_info" | grep -c "TYPE=\"${FS_OLD_DESTINATION}\"") -eq 1 ]
  then
    part_info=$(${PART_CMD} 2>&1)
    ret_code=$?
    if [ $ret_code -gt 0 ]
    then
      to_log "Partition operation failed with code $ret_code - details below.\n${PART_CMD}\n${part_info}"
      exit $ret_code
    else
      to_log "Partition device ${RSYNC_DESTINATION_DEVICE} succesfully done"
    fi

    format_info=$(${FORMAT_CMD} 2>&1)
    ret_code=$?
    if [ $ret_code -gt 0 ]
    then
      to_log "Format operation failed with code $ret_code - details below.\n${FORMAT_CMD}\n${format_info}"
      exit $ret_code
    else
      to_log "Destination device ${RSYNC_DESTINATION_DEVICE} succesfully formated"
    fi
    blk_info=$(/sbin/blkid ${RSYNC_DESTINATION_DEVICE})
  fi

  mount_info=$(${MOUNT_CMD} 2>&1)
  ret_code=$?
  if [ $ret_code -gt 0 ]
  then
    to_log "Mount operation failed with code $ret_code - details below.\n${MOUNT_CMD}\n${mount_info}"
    exit $ret_code
  else
    to_log "Destination device ${RSYNC_DESTINATION_DEVICE} succesfully mounted on ${RSYNC_DESTINATION}"
  fi
fi

#
# try to continue a previously stopped rsync job
#
process_pid_info=$(process_pid_file continue "${RSYNC_PID_FILE}")
ret_code=$?

if [ $ret_code -eq 0 ]
then
  echo "$(date) $info on ${blk_info}" >> ${STAT_FILE} 2>/dev/null
  touch ${INCREMENTAL_DEST}/backup.0
  to_log "${BACKUP_LABEL} backup ${process_pid_info}"
  # We have signaled the process to continue - nothing else to do
  exit
else
  if [ $ret_code -gt 95 ]
  then
    # We encountered some abnormal conditions - last chance to abort
    to_log "${BACKUP_LABEL} backup ${process_pid_info}"
    exit $ret_code
  else
    to_log "${BACKUP_LABEL} backup ${process_pid_info} - switch to start mode"
  fi
fi

#
# start a new backup job
#
to_log "*** ${BACKUP_LABEL} backup started on ${blk_info}"

if [ -f ${LOCAL_DIR}/${BACKUP_LABEL}/${BACKUP_LABEL}.pre ]
then
  to_log "starting PRE script"
  job_status=$(${LOCAL_DIR}/${BACKUP_LABEL}/${BACKUP_LABEL}.pre ${RSYNC_SOURCE})
  ret_code=$?
else
  ret_code=0
fi

if [ $ret_code -gt 0 ]
then
  job_status="${job_status} failed (code: ${ret_code})"
else
  to_log "starting backup"
  job_status=$(server_backup)
  if [ -f ${LOCAL_DIR}/${BACKUP_LABEL}/${BACKUP_LABEL}.post ]
  then
    to_log "starting POST script"
    . ${LOCAL_DIR}/${BACKUP_LABEL}/${BACKUP_LABEL}.post ${RSYNC_SOURCE}
  fi
fi

to_log "*** ${BACKUP_LABEL} backup ${job_status} on ${blk_info}"
