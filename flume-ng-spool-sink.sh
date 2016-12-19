#!/bin/bash
#
# Author Simone Roselli <simoneroselli78@gmail.com>
#
# Check for the presence of files in the failover directory, in that case,
# check if the main sink is up and then move the events in the spool directory
# to be sent to the Kafka sink

DATA_DIR=/opt/flume-ng/failover/Events
SPOOL_DIR=/opt/flume-ng/failover/spool
ARCHIVE_DIR=/opt/flume-ng/failover/archive
SINK_PORT=9092
SINK_HOST='broker.domain.com'
EVENTS=$(ls -A $DATA_DIR)
EVENTS_NR=$(ls -A $DATA_DIR | wc -l)
MAX_OLDER_DATA=4

# Check for netcat
if [ ! -f /bin/nc ]; then
    echo "No Netcat found on this host. Script aborted .."
    echo "Please install NetCat (apt-get install netcat-traditional)"
    exit 1
fi

# If the sink is up, move events to the spool dir
if [ "$EVENTS" ]; then
    if ! /bin/nc -z $SINK_HOST $SINK_PORT; then
        echo "Flume-ng sink ${SINK_HOST}:${SINK_PORT} not available"
        exit 2
    else
        # Archive events older than n days
        [ ! -d $ARCHIVE_DIR ] &&  mkdir $ARCHIVE_DIR && chown -R flume-ng:flume-ng $ARCHIVE_DIR
        /usr/bin/find $DATA_DIR -type f -mtime +${MAX_OLDER_DATA} -exec mv '{}' $ARCHIVE_DIR \;

        # Send the events remain in ../Events to Kafka
        EVENTS=$(ls -A $DATA_DIR)
        if [ "$EVENTS" ]; then
            for event in $EVENTS; do
                mv $DATA_DIR/$event ${SPOOL_DIR}/
                [ "$?" -ne 0 ] && echo "Error moving event \"$event\" to \"$SPOOL_DIR\"" && exit 1
            done
            echo "Nr $EVENTS_NR events moved on \"$SPOOL_DIR\""
        fi
    fi
else
    echo "No events to sink."
    exit 0
fi

