#!/bin/bash

############################################################
#
# Site pinger and logger.
#
# This script checks the health of a site every INTERVAL
# seconds. Must be run as root to enable tcpdump.
# 
# Recommended setup:
# Run this script in a screen session, and pipe the output
# to a log file somewhere you care about.
#
############################################################

##### CONFIG VARIABLES #####

if [ -e .env ]; then
  source ./.env
else
  echo "There is no environment file set. Copy .env.example to .env and edit to fit your needs."
  exit 1
fi

# Default intervals
DEFAULT_INTERVAL=60
DEFAULT_DOWN_INTERVAL=5

# Interval to check the site.
INTERVAL=${CHECKER_INTERVAL:-$DEFAULT_INTERVAL}

# The default host to check. To preserve integrity of the
# git configuration, this should generally be left alone.
# Instead, pass in CHECK_HOST to the bash call like so:
#
# HOST=127.0.0.1 ./test-server.sh
HOST="${HOST:-$CHECKER_HOST}"

# The URL to check. If passed in as an environmental var,
# CHECK_HOST will be used as the host. Otherwise, the
# DEFAULT_HOST from above will be used.
URL="${CHECKER_PROTO:-http}://$HOST$CHECKER_PATH"

# String to check to make sure socket is up
HEALTHY_STRING="$CHECKER_STRING"


##### HEADER PRINTING FUNCTION #####
# Simply prints out a header for the log file
header() {
  echo
  echo "=============================="
  echo " $1"
  echo "=============================="
}

##### REPORTING FUNCTION #####
# This function runs when the checker determines that the
# server is no longer reporting. This function returns
# one big string with the output of its commands
# concatenated. It is also run after the server returns
# from a failure state to have a baseline to compare
# against. For example, traceroute may always have
# a few failed nodes, so it's useful to know which were
# unique to the outage.
report() {
  TEXT_RECEIVED=$1
  RETURN_CODE=$2

  header 'return code of curl'
  echo $RETURN_CODE

  header 'diff of expected vs received'
  diff <(echo "$HEALTHY_STRING") <(echo "$TEXT_RECEIVED")

  header "tcpdump of traffic"
  IP=`dig +short $HOST | head -n 1`
  tcpdump -i any host $IP &
  sleep .5
  PID=$!
  check
  kill $PID
  sleep .5

  header "traceroute to $HOST"
  traceroute $HOST -m 20 -w 1

  header "PING to $HOST"
  ping $HOST -c 4
}

##### MAIN CHECKER #####
check() {
  OUT=`curl -f -s $URL 2>&1`
  RETURN=$?

  if [[ $HEALTHY_STRING == *$OUT* ]]; then
    echo $OUT
    return $RETURN
  else
    return $RETURN
  fi
}

##### MAIN PROCESS LOOP #####
RECENTLY_DOWN=false

# Make sure we're root
if [[ $EUID -ne 0 ]]; then
  echo "Because this script runs tcpdump, it will need to be run as root."
  echo "Quitting."
  exit 1
fi

echo "Beginning monitor script to $URL every $INTERVAL seconds"
echo "My PID: $$"
echo "You can test that this script is running by running \`kill -SIGUSR1 $$\`, then checking the file you're piping to."

# Listen to SIGUSR1
trap 'echo; echo "Still here!"; date; echo;' SIGUSR1

while :
do
  echo $INTERVAL
  OUT=`check`
  RETURN=$?
  if [ $RETURN != 0 ]; then
    if ! $RECENTLY_DOWN; then
      header 'DOWN DOWN DOWN'
      date
      report "$OUT" $RETURN
    else
      header 'STILL DOWN'
      date
    fi
    RECENTLY_DOWN=true
    INTERVAL=${CHECKER_DOWN_INTERVAL:-$DEFAULT_DOWN_INTERVAL}
  elif $RECENTLY_DOWN; then
    header 'BACK UP'
    date
    report "$OUT" $return
    RECENTLY_DOWN=false
    INTERVAL=${CHECKER_INTERVAL:-$DEFAULT_INTERVAL}
  fi

  sleep $INTERVAL
done


