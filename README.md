Requirements:
==============
- Java runtime environment
- Bukkit Static download links
- Screen v4.x


Installation :
==============
- Install the required programs
### Screen

Try:
     sudo apt-get install screen

Or:
     sudo yum install screen

     
### minecraft.sh

- copy the script into your minecraft server folder.
- allow the script to be executed 
#####     chmod +x minecraft.sh

- check the rights of the script user. Every folder specified in the 
configuration phase has to be available to him.
- edit the script to configure it (see the configuration section)

#### (optional)
- I strongly recommend using crontab to automate some of the process. 
- For example:
        30 */1 * * * /home/minecraft/craftbukkit/minecraft.sh backup
- So every hour on the half-hour an incrimental backup is made
        58 4 * * * /home/minecraft/craftbukkit/minecraft.sh backup full logs
- At 4:58am a logs full backup is run which stops the server, runs the "logs clean", deletes the server.log file, does a full backup of the worlds, and restarts the server. 
        58 0,8,12,16,20 * * * /home/minecraft/craftbukkit/minecraft.sh restart sched
- At every 4th hour 58min except at 4:58am the server gets a scheduled restart to clear the memory
        */10 * * * * /home/minecraft/craftbukkit/minecraft.sh checkup
- Every 10 min's check to see if the server's up if not it start's the server if the DO_CHECK is set to 1 in the script

- I made an alias to be able to use 'minecraft command' instead of 
'./minecraft.sh command'. It also enables the automatic completion, if 
you type 'mine' then press tab. Much quicker =) You can do this by 
editing /home/USER/.bashrc, and adding the line:

#####     alias minecraft="/home/minecraft/minecraft.sh"

**(of course, change the path if needed)**

Considerations:
--------------

#### Multiple Worlds

This script handles backing up multiple worlds using a space seperated list in the config section.

Configuration :
===============

There are several variables to set before you can run the script for the first time.
Open minecraft.sh with a text editor, and edit the following lines, at the beginning of the file :

**Main Settings**
    MC_PATH=/home/minecraft
This is the path to your minecraft folder

    SCREEN_NAME="minecraft"
This is the name of the screen the server will be run on

    MEMMAX=1024
This is the maximum size of RAM you want to allow the server to use, if you are not sure, keep this and MEMALOC identical.

    MEMALOC=1024
This is the initial memory allocation reserved for the server

    DISPLAY_ON_LAUNCH=1
Do you want the screen to be displayed each time the server starts? 1 if yes, 0 if no.

    USERNAME='minecraft'
The username of the *unix user allowed to run the commands so the script can run them

    SERVER_OPTIONS="nogui"
This is where you would place any desired flags for running your server.
The "-Djava.net.preferIPv4Stack=true -XX:+UseConcMarkSweepGC -XX:+CMSIncrementalPacing -XX:ParallelGCThreads=$CPU_COUNT -XX:+AggressiveOpts" java options are default

    CPU_COUNT=2
The number of cores you want the server to run on

**Updating**

    REC_BLD_URL=http://dl.bukkit.org/latest-rb/craftbukkit.jar
The Recommeded Build static URL.

    BETA_BLD_URL=http://dl.bukkit.org/latest-beta/craftbukkit.jar
The Beta Build static URL

    DEV_BLD_URL=http://dl.bukkit.org/latest-dev/craftbukkit.jar
The Latest Sucessful Dev Build staic URL.

    JAR_NAME="craftbukkit.jar"
The downloaded builds of the server get renamed to this after it's downloaded

**Restarting**

    DO_CHECK=1
Enable cb_check_up to restart the server if down. Use if you don't want to change the cronjob.

    MAX_TRIES=3
How many retrys of shutting down the server before a force stop

    KICK_COMMAND="kick -o *"
Kick command for restart use "say" if to don't have the kick all command

**Backups**

    WORLD_NAME_LIST ()
    {
        echo "World World_nether World_the_end"
    }
A list of the worlds you want backuped, has to have a space between worlds. Example: echo "World World_nether World_the_end"

    BKUP_PATH=$MC_PATH/backup
This is the path to the backup folder. Map backups and old log entries will go there.

    BKUP_DAYS_INCR=2
How long will incremental map backups be kept?

    BKUP_DAYS_FULL=5
How long will full map backups be kept? _(Only used with the './minecraft.sh backup full' command)_

    WORLD_PATH=$MC_PATH/Worlds
Path to where you store your worlds

**Logs**

    LOG_PATH=/home/minecraft/craftbukkit/logs
This is the path to the logs folder

    LOGS_DAYS=14
How long will the logs be kept? _(Only used with the './minecraft.sh logs clean' and './minecraft.sh backup full logs' commands)_

**Mapping**

Dynmap web chat fix. For when the web chat is spewing out the same line over and over

    DYNMAP_WEBCHAT_PATH=/home/minecraft/www/map/web/standalone/
The path to the folder that holds the dynmap_webchat.json file on your server
Does Dynmap's internal web server use the same file for webchat just in the /plugins/dynmap/web/* folder?


### Detailed Command Usage

##### ./minecraft.sh
Without arguments, the script will resume the server screen. 
(If you want to close the screen without shutting down the server, use 
CTRL+A then press D to detach the screen)

##### ./minecraft.sh status
Tells you if the servers seems to be running, or not.

##### ./minecraft.sh start [force]
Starts the server. If you know your server is not running, but the script believe it is, use the force option.

##### ./minecraft.sh stop [force]
Self explainatory

##### ./minecraft.sh restart [warn|sched]
If the warn option is specified, it will display a warning 30s & 10s and kicks the players if KICK_COMMAND is specified then restarts.
If the sched option is specified, it does the same as warn but with added 2min and 1min warnings

##### ./minecraft.sh logs [clean]
Parses logs into several files, grouped into a folder named with the date of the logging.
If the clean option is specified, it will move the older folders into the backup folder.

##### ./minecraft.sh backup [full]
Displays a message to the players if the server is online, stops the writing of chunks, create a dated archive and backs up the 
world folder. If the full option is specified, it will delete the older incremental and full archives based on the settings.

#### ./minecraft.sh checkup
If the DO_CHECK var is set to 1 it will check if the server is up and if it isn't it will start the server automatically.

#### ./minecraft.sh update [latest|beta|RB]
Warns players if server's up, Stops the server, Downloads the equivalent server binarys from the given urls, backups the current jar and puts the new one in place and starts the server.

#### ./minecraft.sh cmd "minecraft command"
Runs the minecraft command that's in the quotes.

#### ./minecraft.sh fixwebchat
Does a Force Delete of the dynmap_webchat.json file to make dynmap's webchat stop spamming the server.


### Future updates :
* Bugfixes ?
* Better log parsing, this one is realy primitive
* Anything you could think of.

#### Any advice on how to upgrade this script is very welcome.

