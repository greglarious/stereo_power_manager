#!/bin/bash

MUSIC_PLAYER_RECENT_MINUTES=5
SOUND_SESSION_OVER_MINUTES=1
SLEEP_SECONDS=2

#
# state variables
#
STEREO_POWER=false
SOUND_ACTIVE=1
MUSIC_PLAYER_ACTIVE=1
SOUND_OFF_TIME=0

#
# check commands
#
DEBUG_CMDS=true

if ${DEBUG_CMDS}; then
  echo "using debug commands"
  CHECK_MUSIC_PLAYER_ACTIVE_CMD="ls /tmp/m &> /dev/null"
  CHECK_SOUND_ACTIVE_CMD="ls /tmp/s &> /dev/null"
  STEREO_POWER_CMD="echo doing stereo power"
else
  CHECK_MUSIC_PLAYER_ACTIVE_CMD="find /var/log/mopidy -type f -mmin -${MUSIC_PLAYER_RECENT_MINUTES} | grep mopidy > /dev/null"
  CHECK_SOUND_ACTIVE_CMD="grep -i running /proc/asound/card*/pcm*/sub*/status > /dev/null"
  STEREO_POWER_CMD="~/stereo_power.sh"
fi

while [ true ]
do
  LAST_MUSIC_PLAYER_ACTIVE=${MUSIC_PLAYER_ACTIVE}
  eval $CHECK_MUSIC_PLAYER_ACTIVE_CMD
  MUSIC_PLAYER_ACTIVE=$?

  LAST_SOUND_ACTIVE=${SOUND_ACTIVE}
  eval $CHECK_SOUND_ACTIVE_CMD
  SOUND_ACTIVE=$?

  LAST_STEREO_POWER=${STEREO_POWER}

  #
  # initialize sound off time at least once if no sound on script startup
  #
  if [ "$SOUND_ACTIVE" != "0" ] && [ "$SOUND_OFF_TIME" == "0" ]; then
      SOUND_OFF_TIME=$(date +%s)
  fi

  if [ "$MUSIC_PLAYER_ACTIVE" != "$LAST_MUSIC_PLAYER_ACTIVE" ]; then
    echo "music player state changed to: ${MUSIC_PLAYER_ACTIVE}"
    #
    # when music player transitions to active, turn on power
    #
    if [ "$MUSIC_PLAYER_ACTIVE" == "0" ]; then
      STEREO_POWER=true
    fi
  fi

  if [ "$SOUND_ACTIVE" != "$LAST_SOUND_ACTIVE" ]; then
    echo "sound state changed to: ${SOUND_ACTIVE}"
    #
    # when sound output is active, turn on power
    # note: if the sound is output from an external DAC that is powered down
    #       then this condition can never be triggered
    #
    if [ "$SOUND_ACTIVE" == "0" ]; then
      STEREO_POWER=true
    else
      SOUND_OFF_TIME=$(date +%s)
    fi
  fi

  # 
  # if no active sound and no active music player and sound has been off for
  # minimum minutes then turn off power
  #
  if [ "$SOUND_ACTIVE" != "0" ] && [ "$MUSIC_PLAYER_ACTIVE" != "0" ]; then
    let SOUND_OFF_MINUTES=($(date +%s)-$SOUND_OFF_TIME)/60
    if [ "${SOUND_OFF_MINUTES}" -gt "${SOUND_SESSION_OVER_MINUTES}" ]; then
      if [ "$STEREO_POWER" != "false" ]; then
        echo "sound has been off for ${SOUND_OFF_MINUTES} minutes. turning off stereo."
        STEREO_POWER=false
      fi
    fi
  fi

  #
  # if any change to stereo power state, call power strip
  #
  if [ "$STEREO_POWER" != "$LAST_STEREO_POWER" ]; then
    echo "stereo power changed to: ${STEREO_POWER}"
    eval ${STEREO_POWER_CMD}  ${STEREO_POWER}
  fi

  sleep ${SLEEP_SECONDS}
done
