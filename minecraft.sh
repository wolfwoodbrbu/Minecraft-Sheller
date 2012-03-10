#!/bin/bash
# original author : Relliktsohg
# continued contributions: Maine, endofzero
# dopeghoti, demonspork, robbiet480
#
# With a major overhaul done for the mc.brbuninstalling.com server
# by VeraLapsa aka wolfwoodbrbu on github
#
# https://github.com/wolfwoodbrbu/Minecraft-Sheller

#  ## Configuration ## #

# Main
MC_PATH=/home/minecraft/craftbukkit
SCREEN_NAME="bukkit"   # Name of the screen
MEMMAX=1600            # Max Memory allowed
MEMALOC=1024           # Initial Memory Allocation
DISPLAY_ON_LAUNCH=1    # Display the console screen upon startup
USERNAME='minecraft'   # The username of the *unix user allowed to run the commands so the script can run them
SERVER_OPTIONS='nogui' # Any other options for the java command to start the server other then the ones in cb_start_server already.
CPU_COUNT=2

# Server Download URL's
REC_BLD_URL=http://dl.bukkit.org/latest-rb/craftbukkit.jar
BETA_BLD_URL=http://dl.bukkit.org/latest-beta/craftbukkit.jar
DEV_BLD_URL=http://dl.bukkit.org/latest-dev/craftbukkit.jar

# Only this if we have a major craftbukkit break or want to play vanilla for a bit. This whole script will likely change when Mojang's Mod API comes out
JAR_NAME="craftbukkit.jar" # The downloaded builds of the server get renamed to this after it's downloaded
#JAR_NAME="minecraft_server.jar"

# Enable cb_check_up to restart the server if down. Use if you don't want to change the cronjob.
DO_CHECK=1 # Add a cronjob to run "[path to minecraft.sh] checkup]". I check every 10 min on my server.

# Restarting
TRIES=0     # Don't change
INCRIMENT=1 # Don't change
MAX_TRIES=3 # How many retrys of shutting down ther server before a force stop
# Kick command for restart use "say" if to don't have the kick all command
KICK_COMMAND="kick -o *"

# Backups
WORLD_NAME_LIST () # A list of the worlds you want backuped, has to have a space between worlds. Example: echo "World World_nether World_the_end"
{
    echo "World World_nether World_the_end"
}
BKUP_PATH=$MC_PATH/backup  # Where you want backups stored
BKUP_DAYS_INCR=2           # Number of days to keep the incrimental backups
BKUP_DAYS_FULL=5           # Number of days to keep the full backups
WORLD_PATH=$MC_PATH/Worlds # Path to where you store your worlds

# Logs
LOG_PATH=/home/minecraft/craftbukkit/logs
LOGS_DAYS=14

# Dynmap web chat fix. For when the web chat is spewing out the same line over and over
DYNMAP_WEBCHAT_PATH=/home/minecraft/www/map/web/standalone/ # The path to the folder that holds the dynmap_webchat.json file on your server
                                                            # Does Dynmap's internal web server use the same file for webchat just in the /plugins/dynmap/web/* folder?

#   ## End of configuration ##   #

#   ## Functions ##   #

# Check if Craftbukkit is online
check_online() {
    if [[ -e $MC_PATH/server.log.lck ]]; then
        ONLINE=1
    else
        ONLINE=0
    fi
}
check_online

# Get the PID of our Java process for later use.  Better
# than just killing the lowest PID java process like the
# original verison did, but still non-optimal.
#
# Explanation:
#
# Find the PID of our screen that's running Minecraft.
# Then, use PS to find children of that screen whose
# command is 'java'.

SCREEN_PID=$(screen -ls | grep $SCREEN_NAME | grep -iv "No sockets found" | head -n1 | sed "s/^\s//;s/\.$SCREEN_NAME.*$//")

if [[ -z $SCREEN_PID ]]; then
    # Our server seems offline, because there's no screen running.
    # Set MC_PID to a null value.
    MC_PID=''
else
    MC_PID=$(ps --ppid $SCREEN_PID -F -C java | tail -1 | awk '{print $2}')
fi

#Sends the commands to the server
cb_command() {
  if [ "$1" ]; then
    command="$1";
    if [[ 1 -eq $ONLINE ]]; then
      screen -S $SCREEN_NAME -p 0 -X stuff "$(printf "\r$command\r")"
    fi
    else
      echo "Must specify server command"
  fi
}

#Pulls up the Server's Console
display () {
    screen -x $SCREEN_NAME
}

#Start's the server cleanly
cb_start_server (){
    echo "Launching Minecraft server."
    echo $JAR_NAME
    cd $MC_PATH
    screen -dmS $SCREEN_NAME java -Xmx${MEMMAX}M -Xms${MEMALOC}M -Djava.net.preferIPv4Stack=true -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT -XX:+AggressiveOpts -jar $JAR_NAME $SERVER_OPTIONS
    sleep 1
    if [[ 1 -eq $DISPLAY_ON_LAUNCH ]]; then
        display
    fi
}

#Stops the server cleanly
cb_stop_server () {
    if [[ 1 -eq $ONLINE ]]; then
        echo "Stopping Minecraft server."
        screen -S $SCREEN_NAME -p 0 -X stuff "$(printf "stop\r")"
        sleep 5
    else
        echo "Server seems to be offline already."
    fi
}

#Kills the server, frozen or not
cb_force_kill () {
    # TODO:
    # Still needs work, but at least we try
    # to use the PID we grabbed earlier.
    # The fallback is still to blindly
    # kill the lowest-PID Java process running
    # on the server.  This is very bad form.
    if [[ -z $MC_PID ]]; then
        kill $(ps -e | grep java | cut -d " " -f 1)
    else
        kill -9 $MC_PID
    fi
    rm -fr $MC_PATH/*.log.lck 2> /dev/null
}

#Starts the server after a force kill
cb_force_start (){
    cb_force_kill
    sleep 2
    cb_start_server
}

#Check if the server's up, if not it starts it if allowed
cb_check_up (){
    if [[ 1 -eq $DO_CHECK ]]; then
        if [[ 0 -eq $ONLINE ]]; then
            echo "Server offline Starting in 10sec."
            sleep 10
            cb_start_server
        else
            echo "Server Online"
        fi
    else
        echo "DO_CHECK disabled in minecraft.sh"
    fi
}

#My nice way of warning players of an unscheduled restart
cb_restart_warn (){
    echo "Warning players of the restart"
    cb_command "say Server will restart in 30s !\r"
    sleep 20
    cb_command "say Server will restart in 10s !\r"
    sleep 5
    cb_command "say See you in 1 min!\r"
    sleep 1
    cb_command "$KICK_COMMAND  Unscheduled Restart, Rejoin in 1 min.\r"
    sleep 4
}

# My nice way of warning players of a scheduled restart.
cb_sched_restart_warn (){
    echo "Warning players of the scheduled restart"
    cb_command "say Server is about to run a scheduled restart.\r"
    cb_command "say Server will restart in 2 minutes.\r"
    sleep 60
    cb_command "say Server is about to run a scheduled restart.\r"
    cb_command "say Server will restart in 1 minute.\r"
    sleep 30
    cb_command "say Server is about to run a scheduled restart.\r"
    cb_command "say Server will restart in 30 seconds.\r"
    sleep 20
    cb_command "say Server is about to run a scheduled restart.\r"
    cb_command "say Server will restart in 10 seconds!\r"
    sleep 5
    cb_command "say See you in 2 min!\r"
    sleep 1
    cb_command "$KICK_COMMAND Scheduled Restart, Rejoin in 2 min.\r"
    sleep 4
}

#Restarts the server
cb_restart (){
    #Actual function that restarts the server.
    restart () {
        echo "Restarting server now."
        cb_command "say Restarting server now!\r"
        if [[ $TRIES -lt $MAX_TRIES ]]; then
            cb_stop_server
        else
            cb_force_kill
        fi
        echo "Stop command sent, sleeping for $1 seconds"
        sleep $1
        TRIES=$TRIES+$INCRIMENT;
        check_online
        if [[ $ONLINE -eq 1 ]]; then
            restart 30
        else
            cb_start_server
        fi
    }
    #But first, what kind of restart do we want?
    if [ "$1" ]; then
        whichwarn="$1";
        case $whichwarn in
        "sched") # For a Full Backup add "[path to minecraft.sh] backup full" as a cronjob
            cb_sched_restart_warn
            restart 20
            ;;
        "warn") # For a Incrimental Backup add "[path to minecraft.sh] backup" as a cronjob
            cb_restart_warn
            restart 15
            ;;
        *)
            echo "Error: $1 not an option for restart"
            echo "Valid options are none at all, warn, or sched."
            echo "Using warn restart."
            cb_restart_warn
            restart 15
            ;;
        esac
    else
        cb_command "$KICK_COMMAND Unscheduled Restart, Rejoin in 1 min."
        sleep 1
        restart 15
    fi
}

#Parse the log and seperate it for easy reading (sometimes(needs worked on to support non default chat))
cb_logs (){
    mkdir -p $LOG_PATH
    cd $LOG_PATH

    if [ "$1" == "clean" ]; then
        #Move all old log folders into the backup directory based on $LOGS_DAYS
        mkdir -p $BKUP_PATH/logs
        find $LOG_PATH -type d -mtime +$LOGS_DAYS -print | xargs -I xxx mv xxx $BKUP_PATH/logs/
    fi

    DATE=$(date +%Y-%m-%d)
    LOG_NEWDIR=$DATE-logs
    if [[ -e $LOG_PATH/$LOG_NEWDIR ]]; then
        rm $LOG_PATH/$LOG_NEWDIR/*
        else
        mkdir $LOG_PATH/$LOG_NEWDIR
    fi

    DATE=$(date +%d-%m-%Hh%M)
    LOG_TFILE=logs-$DATE.log



    cd $MC_PATH
    cat server.log >> $LOG_PATH/$LOG_NEWDIR/$LOG_TFILE


    if [[ -e $LOG_PATH/ip-list.log ]]; then
        cat $LOG_PATH/ip-list.log | sort | uniq > $LOG_PATH/templist.log
    fi

    cat $LOG_PATH/$LOG_NEWDIR/$LOG_TFILE | egrep '[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+.+logged in'  | sed -e 's/.*\[INFO\]\s//g' -e 's/\[\//\t/g' -e 's/:.*//g' >> $LOG_PATH/templist.log
    cat $LOG_PATH/templist.log | sort | uniq -w 4 > $LOG_PATH/ip-list.log
    rm $LOG_PATH/templist.log

    egrep '\[WARNING\]' $LOG_PATH/$LOG_NEWDIR/$LOG_TFILE >> $LOG_PATH/$LOG_NEWDIR/WARNING-$DATE.log

    egrep '\[SEVERE\]' $LOG_PATH/$LOG_NEWDIR/$LOG_TFILE >> $LOG_PATH/$LOG_NEWDIR/SEVERE-$DATE.log

    cat $LOG_PATH/$LOG_NEWDIR/$LOG_TFILE | egrep 'logged in|lost connection' | sed -e 's/.*\([0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\).\[INFO\].\([a-zA-Z0-9_]\{1,\}\).\{1,\}logged in/\1\t\2 : connected/g' -e 's/.*\([0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\).\[INFO\].\([a-zA-Z0-9_]\{1,\}\).lost connection.*/\1\t\2 : disconnected/g' >> $LOG_PATH/$LOG_NEWDIR/connexions-$DATE.log

    cat $LOG_PATH/$LOG_NEWDIR/$LOG_TFILE | egrep '<[a-zA-Z0-9_]+>|\[CONSOLE\]' | sed -e 's/.*\([0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\).\[INFO\]./\1 /g' >> $LOG_PATH/$LOG_NEWDIR/chat-$DATE.log

    cat $LOG_PATH/$LOG_NEWDIR/$LOG_TFILE | egrep 'Internal exception|error' | sed -e 's/.*\([0-9]\{2\}:[0-9]\{2\}:[0-9]\{2\}\).\[INFO\]./\1\t/g' >> $LOG_PATH/$LOG_NEWDIR/errors-$DATE.log
}

#Backs up the server's worlds as defined in WORLD_NAME_LIST
cb_backup (){
    mkdir -p $BKUP_PATH
    cd $BKUP_PATH
    #This logs section is for running once a day(we do it at 5am est)
    #It stops the server, runs cb_logs, then deletes server.log so the file doesn't get out of hand.
    #Then the server does it's full backup. This is done when we'd normally have a scheduled restart.
    if [[ "logs" == $2 ]]; then # for a logs full backup add "[path to minecraft.sh] backup full logs" as a cronjob
        echo "A logs full backup has begun"
        if [[ $ONLINE -eq 1 ]]; then
            cb_command "say Full backup of server starting in 2 min.\r"
            cb_command "say The server will shutdown for this task.\r"
            sleep 60
            cb_command "say Full backup of server starting in 1 min.\r"
            cb_command "say The server will shutdown for this task.\r"
            sleep 30
            cb_command "say Full backup of server starting in 30 sec.\r"
            cb_command "say The server will shutdown for this task.\r"
            sleep 10
            cb_command "say The server will restart in within 5 min.\r"
            sleep 10
            cb_command "say Full backup of server starting in 10 sec.\r"
            sleep 5
            cb_command "say See you in within 5 min!\r"
            sleep 1
            cb_command "$KICK_COMMAND Scheduled Full Backup, Rejoin in 5 min.\r"
            sleep 4
            echo "Stopping server"
            cb_stop_server
            sleep 60
            check_online
            while [[ $ONLINE -eq 1 ]]; do
                echo "Stopping server"
                cb_stop_server
                sleep 15
                check_online
            done
        fi
        cb_logs "clean"
        sleep 30
        rm $MC_PATH/server.log
    fi
    if [[ $ONLINE -eq 1 ]]; then
        echo "Server running, warning players : backup in 10s."
        cb_command "say How about a walk about the house or a drink of water.\r"
        cb_command "say Backing up the map in 10s.\r"
        sleep 10
        cb_command "say It's healthy for you.\r"
        cb_command "say Now backing up the map.\r"
        echo "Issuing save-all command, wait 10s."
        cb_command "save-all\r"
        sleep 10
        echo "Issuing save-off command."
        cb_command "save-off\r"
        sleep 3
    fi
    DATE=$(date +%Y-%m-%d-%Hh%M)
    for world in $(WORLD_NAME_LIST)
    do
        BACKUP_FULL_LINK=${BKUP_PATH}/${world}_full.tar.gz
        BACKUP_INCR_LINK=${BKUP_PATH}/${world}_incr.tar.gz
        if [[ -e $WORLD_PATH/$world ]]; then
            echo "Backing up \"$world\""

            cd $BKUP_PATH

            FILENAME=$world-$DATE
            BACKUP_FILES=$BKUP_PATH/list.$DATE

            if [[ "full" == $1 ]]; then
                # If full flag set, Make full backup, and remove old incrementals
                FILENAME=$FILENAME-full.tar.gz

                # Remove incrementals older than $BKUP_DAYS_INCR
                # Remove full archives older than $BKUP_DAYS_FULL
                find ./$world-*-incr.tar.gz -type f -mtime +$BKUP_DAYS_INCR -print | xargs /bin/rm -f
                find ./$world-*-full.tar.gz -type f -mtime +$BKUP_DAYS_FULL -print | xargs /bin/rm -f

                # Now make our full backup
                pushd $WORLD_PATH
                find $world -type f -print > $BACKUP_FILES
                ionice -c 2 -n 7 nice tar -zcf $BKUP_PATH/$FILENAME --files-from=$BACKUP_FILES
                popd

                rm -f $BACKUP_FULL_LINK $BACKUP_INCR_LINK
                ln -s $FILENAME $BACKUP_FULL_LINK
            else
                # Make incremental backup
                FILENAME=$FILENAME-incr.tar.gz
                # Remove incrementals older than $BKUP_DAYS_INCR
                find ./$world-*-incr.tar.gz -type f -mtime +$BKUP_DAYS_INCR -print | xargs /bin/rm -f

                pushd $WORLD_PATH
                find $world -newer $BACKUP_FULL_LINK -type f -print > $BACKUP_FILES
                nice tar -zcf $BKUP_PATH/$FILENAME --files-from=$BACKUP_FILES
                popd

                rm -f $BACKUP_INCR_LINK
                ln -s $FILENAME $BACKUP_INCR_LINK
            fi

            rm -f $BACKUP_FILES

            echo "Backup process for \"$world\" is over."

        else
            echo "The world \"$world\" does not exist.";
        fi
    done
    echo "Backup process is over."
    if [[ 1 -eq $ONLINE ]]; then
        echo "Issuing save-on command..."
        cb_command "save-on\r"
        sleep 1
        cb_command "say Backup is done, have fun!\r"
    fi
    if [[ "logs" == $2 ]]; then
        cb_start_server
        if [[ 1 -eq $DISPLAY_ON_LAUNCH ]]; then
            display
        fi
    fi
}

# Simple server status
cb_status (){
    if [[ 1 -eq $ONLINE ]]; then
        echo "Minecraft server seems ONLINE."
    else
        echo "Minecraft server seems OFFLINE."
    fi
}

# Update section
cb_update (){
    if [[ 1 -eq $ONLINE ]]; then
        echo "Telling players of the update, sleeping for 10s, and then stopping the server"
        cb_command "say The server is shutting down to update ${JAR_NAME}\r"
        cb_command "say The server will go offline in 10s and will be back up momentarily.\r"
        sleep 10
        cb_stop_server
    fi
    # Make backup of the old jar 
    mkdir -p $BKUP_PATH
    echo "Backing up current $JAR_NAME."
    DATE=$(date +%Y-%m-%d-%Hh%M)
    cd $MC_PATH
    tar -zcf $JAR_NAME-$DATE.tgz $JAR_NAME
    mv $JAR_NAME-$DATE.tgz $BKUP_PATH


    #They"ve changed the name of the files reciently so check every RB to see if they"ve changed the file name layout.
    if [[ "latest" == $1 ]]; then
        #Latest Successful Build
        echo "Downloading the Latest Successful Dev Build of $JAR_NAME"
        wget -N $DEV_BLD_URL -O Latest-Dev-Build.jar
        sleep 2
        mv Latest-Dev-Build.jar $JAR_NAME
    else
        if [[ "beta" == $1 ]]; then
            #beta build
            echo "Downloading the Latest Beta Dev Build of $JAR_NAME"
            wget -N $BETA_BLD_URL -O Beta-Dev-Build.jar
            sleep 2
            mv Beta-Dev-Build.jar $JAR_NAME
        else
            if [[ "RB" == $1 ]]; then
                #Recommended build
                echo "Downloading the Latest Recommended Build of $JAR_NAME"
                wget -N $REC_BLD_URL -O Recommended-Build.jar
                sleep 2
                mv Recommended-Build.jar $JAR_NAME
            fi
        fi
    fi
    sleep 2
    cb_start_server
    if [[ 1 -eq $DISPLAY_ON_LAUNCH ]]; then
        display
    fi
}

#For fixing dynmap webchat repeating over and over
cb_fix_chat() {
    cd $DYNMAP_WEBCHAT_PATH
    rm -f dynmap_webchat.json
}


#   ## End of Functions ##   #

#   ## Main ##   #

#The big case statement which without it this script would do nothing
if [[ $# -gt 0 ]]; then
    case "$1" in
    "checkup")
        cb_check_up
        ;;
    "status")
        cb_status
        ;;
    "start")
        if [[ "$2" == "force" ]]; then
            cb_force_start
        else
            cb_start_server
        fi
        ;;
    "stop")
        if [[ "$2" == "force" ]]; then
            cb_force_kill
        else
            cb_stop_server
        fi
        ;;
    "restart")
        if [ "$2" ]; then
            cb_restart $2
        else
            cb_restart
        fi
        ;;
    "backup")
        if [ "$3" ]; then
            cb_backup $2 $3
        else
            cb_backup $2
        fi
        ;;
    "update")
        if [[ "latest" != $2 ]]; then
            if [[ "beta" != $2 ]]; then
                if [[ "RB" != $2 ]]; then
                    echo "Blank is not an update option please do minecraft update [latest|beta|RB]"
                    exit 0
                fi
            fi
        fi
        cb_update $2
        ;;
    "cmd")
        if [ "$2" ]; then
            cb_command "$2"
        else
            cb_command
        fi
        ;;
    "logs")
        if [ "$2" ]; then
            cb_logs $2
        else
            cb_logs
        fi
        ;;
    "fixwebchat")
        cb_fix_chat
        ;;
    *)
        echo "Usage : minecraft < start [force] | stop [force] | restart [warn|sched] | cmd \"command\" >"
        echo "Usage : minecraft < backup [full] | update [latest|beta] | logs [clean] | status | fixwebchat >"
        ;;
    esac
else
    if [[ 1 -eq $ONLINE ]]; then
        display
    else
        echo "Minecraft server seems to be offline..."
    fi
fi

#   ## End of Main ##   #

exit 0
