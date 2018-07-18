#!/bin/bash
## ACKNOWLEDGEMENTS;
## THIS SABNZBD POST PROCESSING SCRIPT IS LARGELY BASED ON THE MKVDTS2AC3.sh SCRIPT WITTEN BY JAKE WHARTON AND CHRIS HOEKSTRA, WHICH CAN BE FOUND HERE: https://github.com/JakeWharton/mkvdts2ac3 ALONG WITH ALL THE HELP INFO THAT I FOUND SO VALUABLE, AND IF YOU'RE READING THIS THEN SO WILL YOU. THANK YOU GUYS FOR ALL THAT WORK WAY BACK ALL THOSE YEARS. 

## WHAT THIS SAB POST PROC SCRIPT DOES (OR IS SUPPOSED TO DO);
## THE SCRIPT PRIMARILY DOES TWO THINGS -  RENAME THE FINAL FILENAME TO THAT OF ITS PARENT FOLDER SO AS TO FIX THE OBFUSCATED FILENAME ISSUE, AND OF COURSE CONVERT AUDIO TO AC3. I'VE ADDED SUPPORT TO CONVERT ALL MULTICHANNEL AUDIO TO AC3 BTW, NOT JUST DTS. IT WILL CONVERT DTS, DTS-HD, DTS-ES, EAC-3, TrueHD, AND TrueHD Atmos - ALL TO AC3. IT CONVERTS THE FIRST MULTI-CHANNEL FILE IT FINDS AND DISCARDS THE REST ALONG WITH ANY SUBTITLE FILES WITHIN THE MKV. I HAD MY OWN REASONS FOR DOING THIS... THERE ARE SOME CHECKS ALONG THE WAY WHICH CAN BE IDENTIFIED WHEREVER YOU SEE A MESSAGE ECHOING TO THE POST PROC LOG FILE. IN SUMMARY IT FIRSTLY RENAMES, THEN CHECKS IF THE FILE IS AN MKV. IF NO IT EXITS CLEANLY THEN AND THERE. IF YES IT THEN CHECKS IF THE FILE HAS AC3 AND OR SUBS. IT REMOVES THE SUBS IF YES, THEN EXITS CLEANLY IF AC3 EXISTS. IF NO AC3 IS FOUND, THEN IT SEARCHES FORA SURROUND SOUND TRACK AND CONVERTS THE FIRST ONE. IT THEN RUNS THROUGH A BUNCH OF STUFF THAT WAS IN THE ORIGINAL SCRIPT AND ENSURES PREDICTABLE RESULTS EACH TIME. ANYHOW, WHAT YOU SHOULD END UP WITH IS AN MKV FILE WITH THE VIDEO TRACK UNTOUCHED FROM WHAT WAS DOWNLOADED,  A SINGLE AC3 AUDIO TRACK, PLUS ANY CHAPTER FILES ETC AS I CBF TAKING ANOTHER SIX MONTHS FIGURING THAT OUT. PLEASE FORGIVE ME IN ADVANCE FOR THE LIMITED PORTABILITY OF THIS SCRIPT, BUT IT'S THE FIRST SCRIPT I'VE EVER WRITTEN. I KNOW THERE ARE QUITE A FEW THINGS IN IT THAT ARE SPECIFIC TO MY OWN NEEDS, BUT I DID TRY! I PULLED ALL THE VARIABLES FROM THE rc_USER FILE INTO THE SCRIPT SO IT COULD STAND ALONE WITHIN SAB, AND THESE ARE IMMEDIATELY BELOW THIS FEEBLE ATTEMPT AR A README FILE... 
## FINALLY, AGAIN, THANKS TO JAKE W AND CHRIS H. CANT BELIEVE THEY WROTE THIS IN 2011. I SHUDDER TO THINK HOW SMART THEY MUST BE NOW, 7 FULL YEARS LATER... PROBABLY WRITING CODE FOR TIME TRAVEL OR SIMILAR.
## THANKS AND REGARDS, Steve Evans, Sydney AUSTRALIA,  July 2018

# Match any case so find doesnt fail
shopt -s nocaseglob

###############################################
# Here is where you can set some default values. 
PRIORITY=0
INITIAL=1
NEW=0
COMP="none"
#EXTERNAL=1
NODTS=1
#KEEPDTS=1
DEFAULT=1
FORCE=1
INITIAL=0
#MD5=1
#NEW=1
#PRIORITY=0
#DTSTRACK=
DTSNAME="AC3-5.1-Surround-640kbs"

## The working directory is set automatically by sab here
WD=$"$SAB_COMPLETE_DIR"

## Here we set a variable for your user. I purposely made the variable unique in case people have requirements for multiple users. I do not. It is merely used to send the exit point results to the post proc log file (which now I think of it you might need to check againsts your sabnzbd config files). I use Debian stable btw...
sab_USER=$"steve"

# Make sure that our $DIR is a known constant
if [ -f "$1" ]; then
		DIR=$(dirname "$1")
fi

if [ -d "$1" ]; then
		DIR="$1"
fi

if [ "$1" = "" ]; then
		DIR="$PWD"
fi

# These are so you can make quick changes to the cmdline args without having to search and replace the entire script
DUCMD="$(which \du) -k"
RSYNCCMD="$(which \rsync) -a"

# Find out the obfuscated filename
sab_PATHNAME=$(find "$DIR" -type f -iname "*.*")

# Isolate the filename from the extension
sab_NAME=$(basename "$sab_PATHNAME")
sab_EXTENSION=$(echo "$sab_NAME" | awk -F '.' '{print $NF}')

# Start the renaming and send output to log
echo "######################################################################################################" >> /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;
echo "$(date): POST PROCESSING INFORMATION FOLLOWS FOR: $SAB_FILENAME" >> /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;

echo "1. Full path prior to commencing is: $sab_PATHNAME" >> /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;

echo "2. New path after renaming is: "$SAB_COMPLETE_DIR/$3.$sab_EXTENSION"" >> /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;

MKVFILE=$"$SAB_COMPLETE_DIR/$3.$sab_EXTENSION"

touch "$MKVFILE" 

$RSYNCCMD "$sab_PATHNAME" "$MKVFILE";

rm "$sab_PATHNAME"

# Export MKVFILE for when we call the mkvdts2ac3.sh script later
export MKVFILE="$MKVFILE";

if [[ $sab_EXTENSION != mkv ]]; then
	echo "3. This file is not an MKV so we are all done. Exit 0 status." >> /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;
	echo $"This file is not an MKV so we are all done. Exit 0 status."
	exit 0

else
	echo "3. Processing file to ensure Surround Sound is AC3 and removing subs." >> /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;

fi

shopt -u nocaseglob

# Debugging flags
# DO NOT EDIT THESE! USE --debug OR --test ARGUMENT INSTEAD.
PRINT=0
PAUSE=0
EXECUTE=1

# Force English output, grepping for messages may fail otherwise
export LC_MESSAGES=C

#---------- FUNCTIONS --------
# Usage: dopause
dopause() {
	if [ $PAUSE = 1 ]; then
		read
	fi
}
# Usage: cleanup file
cleanup() {
	if [ -f "$1" ]; then
		rm -f "$1"
		if [ $? -ne 0 ]; then
			$"There was a problem removing the file \"$1\". Please remove manually."
			return 1
		fi
	fi
}

# Usage: doprint "String to print"
doprint() {
	if [ $PRINT = 1 ]; then
		echo -e "$1"
	fi
}

#---------- START OF PROGRAM ----------

# Make some adjustments based on the version of mkvtoolnix
MKVTOOLNIXVERSION=$(mkvmerge -V | cut -d " " -f 2 | sed s/\[\^0-9\]//g)
if [ ${MKVTOOLNIXVERSION} -lt 670 ]; then
	AUDIOTRACKPREFIX="audio (A_"
	VIDEOTRACKPREFIX="video (V_"

else
	AUDIOTRACKPREFIX="audio ("
	VIDEOTRACKPREFIX="video ("
fi

# Path to file
DEST=$(dirname "$MKVFILE")

# File name without the extension
#NAME=$(basename "$MKVFILE" .mkv)
NAME=$(basename "$MKVFILE")

# Setup temporary files
DTSFILE="$WD/$NAME.dts"
AC3FILE="$WD/$NAME.ac3"
TCFILE="$WD/$NAME.tc"
NEWFILE="$WD/$NAME.new.$sab_EXTENSION"

doprint $"MKV FILE: $MKVFILE"
doprint $"DTS FILE: $DTSFILE"
doprint $"AC3 FILE: $AC3FILE"
doprint $"TIMECODE: $TCFILE"
doprint $"NEW FILE: $NEWFILE"
doprint $"WORKING DIRECTORY: $WD"

# ------ GATHER DATA ------
#############################################################################
## Added check to see if AC3 track exists. If so, remove subs if they exist, remux, then exit 0 (no need for any conversion)
if [ "$(mkvmerge -i "$MKVFILE" | grep -i "${AUDIOTRACKPREFIX}AC-3")" ]; then
	echo $"AC3 track already exists in '$MKVFILE'. Checking to see if it is Surround or Stereo."
	AC3CHANNELS=$(mediainfo --Inform='Audio;%Channels%' "$MKVFILE" | sed 's/[^0-9].*$//')
		if (($AC3CHANNELS > 2)); then
			echo "4. MKVFILE already has a surround sound AC3 track. Removing subs if they exist then exiting." >>  /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;
			AC3TRACK=$(mkvmerge -i "$MKVFILE" | grep -m 1 "${AUDIOTRACKPREFIX}AC-3)" | cut -d ":" -f 1 | cut -d " " -f 3);
			mkvmerge -o "$NEWFILE" --no-subtitles --audio-tracks "$AC3TRACK" "$MKVFILE";
			$RSYNCCMD "$NEWFILE" "$MKVFILE"
			rm -r "$NEWFILE"
			echo $"All good. I'm done with Exit 0 status."
			exit 0
		else
			echo "Found an AC3 audio file but it is stereo. Continuing..."
		fi
fi

#################################################################################	
# If the track id wasn't specified via command line then search for the first Surround Sound audio track
if [ -z $DTSTRACK ]; then
	doprint ""
	doprint $"Find first Surround Sound track in MKV file."
	doprint "> mkvmerge -i \"$MKVFILE\" | grep -m 1 -e \"${AUDIOTRACKPREFIX}DTS)\" -e \"${AUDIOTRACKPREFIX}DTS-HD Master Audio)\" -e \"${AUDIOTRACKPREFIX}DTS-HD High Resolution Audio)\" -e \"${AUDIOTRACKPREFIX}DTS-ES)\" -e \"${AUDIOTRACKPREFIX}E-AC-3)\" -e \"${AUDIOTRACKPREFIX}TrueHD)\" -e \"${AUDIOTRACKPREFIX}TrueHD Atmos)\" | cut -d ":" -f 1 | cut -d \" \" -f 3"
	DTSTRACK="DTSTRACK" #Value for debugging
	dopause
	if [ $EXECUTE = 1 ]; then
		DTSTRACK=$(mkvmerge -i "$MKVFILE" | grep -m 1 -e "${AUDIOTRACKPREFIX}DTS-HD Master Audio)" -e "${AUDIOTRACKPREFIX}DTS)" -e "${AUDIOTRACKPREFIX}DTS-HD High Resolution Audio)" -e "${AUDIOTRACKPREFIX}DTS-ES)" -e "${AUDIOTRACKPREFIX}E-AC-3)" -e "${AUDIOTRACKPREFIX}TrueHD)" -e "${AUDIOTRACKPREFIX}TrueHD Atmos)" | cut -d ":" -f 1 | cut -d " " -f 3)

		# Check to make sure there is a Surround Sound track in the MKV
		if [ -z $DTSTRACK ]; then
			echo $"WTF...??  There are no Surround Sound tracks in '$MKVFILE'. If there are subtitles I'll remove them. then I'm done!"
			mkvmerge -o "$NEWFILE" --no-subtitles "$MKVFILE";
			$RSYNCCMD "$NEWFILE" "$MKVFILE";
			rm -r "$NEWFILE";
			echo $"All good. I'm done with Exit 0 status."
			exit 0
		fi
	fi
	doprint "RESULT:DTSTRACK=$DTSTRACK"
else
	# Checks to make sure the command line argument track id is valid
	doprint ""
	doprint $"Checking to see if Surround Sound track specified via arguments is valid."
	doprint "> mkvmerge -i \"$MKVFILE\" | grep -e \"Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}DTS)\" -e \"Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}DTS-HD Master Audio)\" -e \"Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}DTS-HD High Resolution Audio)\" -e \"Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}DTS-ES)\" -e \"Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}E-AC-3)\" -e \"Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}TrueHD)\" -e \"Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}TrueHD Atmos)\""
	VALID=$"VALID" #Value for debugging
	dopause
	if [ $EXECUTE = 1 ]; then
		VALID=$(mkvmerge -i "$MKVFILE" | grep -e "Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}DTS)" -e "Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}DTS-HD Master Audio)" -e "Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}DTS-HD High Resolution Audio)" -e "Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}DTS-ES)" -e "Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}E-AC-3)" -e "Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}TrueHD)" -e "Track ID $DTSTRACK: ${AUDIOTRACKPREFIX}TrueHD Atmos)")

		if [ -z "$VALID" ]; then
			echo "4. WTF? Track ID $DTSTRACK does'nt seem to exist. Exit 1 status." >>  /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;
			exit 1
		else
			info $"Using alternate Surround Sound track with ID '$DTSTRACK'."
		fi
	fi
	doprint "RESULT:VALID=$VALID"
fi

# Get the specified Surround Sound track's information
doprint ""
doprint $"Extract track information for selected Surround Sound track."
doprint "> mkvinfo \"$MKVFILE\""

INFO=$"INFO" #Value for debugging
dopause
if [ $EXECUTE = 1 ]; then
	INFO=$(mkvinfo "$MKVFILE")
	FIRSTLINE=$(echo "$INFO" | grep -n -m 1 "Track number: $DTSTRACK" | cut -d ":" -f 1)
	INFO=$(echo "$INFO" | tail -n +$FIRSTLINE)
	LASTLINE=$(echo "$INFO" | grep -n -m 1 "Track number: $(($DTSTRACK+1))" | cut -d ":" -f 1)
	if [ -z "$LASTLINE" ]; then
		LASTLINE=$(echo "$INFO" | grep -m 1 -n "|+" | cut -d ":" -f 1)
	fi
	if [ -z "$LASTLINE" ]; then
		LASTLINE=$(echo "$INFO" | wc -l)
	fi
	INFO=$(echo "$INFO" | head -n $LASTLINE)
fi
doprint "RESULT:INFO=\n$INFO"

#Get the language for the Surround Sound track specified
doprint ""
doprint $"Extract language from track info."
doprint '> echo "$INFO" | grep -m 1 \"Language\" | cut -d \" \" -f 5'

DTSLANG=$"DTSLANG" #Value for debugging
dopause
if [ $EXECUTE = 1 ]; then
	DTSLANG=$(echo "$INFO" | grep -m 1 "Language" | cut -d " " -f 5)
	if [ -z "$DTSLANG" ]; then
		DTSLANG=$"eng"
	fi
fi
doprint "RESULT:DTSLANG=$DTSLANG"

# Check if a custom name was already specified
if [ -z $DTSNAME ]; then
	# Get the name for the Surround Sound track specified
	doprint ""
	doprint $"Extract name for selected Surround Sound track. Change Surround Sound to AC3 and update bitrate if present."
	doprint '> echo "$INFO" | grep -m 1 "Name" | cut -d " " -f 5- | sed "s/DTS|DTS....|EAC3.|E.AC3.|E.AC.3.|True.HD|TrueHD|True.HD.Atmos|TrueHD.Atmos" | awk '"'{gsub(/[0-9]+(\.[0-9]+)?(M|K)bps/,"640Kbps")}1'"''
	DTSNAME="DTSNAME" #Value for debugging
	dopause
	if [ $EXECUTE = 1 ]; then
		DTSNAME=$(echo "$INFO" | grep -m 1 "Name" | cut -d " " -f 5- | sed -e "s/DTS*/AC3/; s/DTS.../AC3/; s/E.AC.3/AC3/; s/EAC3/AC3/; s/E.AC3/AC3/; s/True.HD./AC3/; s/TrueHD/AC3/; s/True.HD.Atmos/AC3; s/TrueHD.Atmos/AC3;" | awk '{gsub(/[0-9]+(\.[0-9]+)?(M|K)bps/,"640Kbps")}1')
	fi
	doprint "RESULT:DTSNAME=$DTSNAME"
fi

# ------ EXTRACTION ------
# Extract timecode information for the target track
doprint ""
doprint $"Extract timecode information for the audio track."
doprint "> mkvextract timecodes_v2 \"$MKVFILE\" $DTSTRACK:\"$TCFILE\""
doprint "> sed -n \"2p\" \"$TCFILE\""
doprint "> rm -f \"$TCFILE\""

DELAY=$"DELAY" #Value for debugging
dopause
if [ $EXECUTE = 1 ]; then
	echo $"Extracting Timecodes:";
	nice -n $PRIORITY mkvextract timecodes_v2 "$MKVFILE" $DTSTRACK:"$TCFILE"
	DELAY=$(sed -n "2p" "$TCFILE")
	cleanup "$TCFILE"
fi
doprint "RESULT:DELAY=$DELAY"

# Extract the Surround Sound track
doprint ""
doprint $"Extract Surround Sound file from MKV."
doprint "> mkvextract tracks \"$MKVFILE\" $DTSTRACK:\"$DTSFILE\""

dopause
if [ $EXECUTE = 1 ]; then
	echo $"Extracting Surround Sound Track: ";
	nice -n "$PRIORITY" mkvextract tracks "$MKVFILE" $DTSTRACK:"$DTSFILE" 2>&1|perl -ne '$/="\015";next unless /Progress/;$|=1;print "%s\r",$_' #Use Perl to change EOL from \n to \r show Progress %
fi

# ------ CONVERSION ------
# Convert Surround Sound to AC3
doprint $"Converting Surround Sound to AC3."
doprint "> ffmpeg -i \"$DTSFILE\" -acodec ac3 -ac 6 -ab 640k -ar 48000 \"$AC3FILE\""

dopause
if [ $EXECUTE = 1 ]; then
	echo $"Converting Surround Sound to AC3:";
	DTSFILESIZE=$($DUCMD "$DTSFILE" | cut -f1) # Capture Surround Sound filesize for end summary
	nice -n $PRIORITY ffmpeg -i "$DTSFILE" -acodec ac3 -ac 6 -ab 640k -ar 48000 "$AC3FILE" 2>&1|perl -ne '$/="\015";next unless /size=\s*(\d+)/;$|=1;$s='$DTSFILESIZE';printf "Progress: %.0f%\r",450*$1/$s' #run ffmpeg and only show Progress %. Need perl to read \r end of lines

	cleanup "$DTSFILE"
	echo "Progress: 100%"	#The last Progress % gets overwritten so let's put it back and make it pretty
fi

# Check there is enough free space for AC3+MKV
if [ $EXECUTE = 1 ]; then
	MKVFILESIZE=$($DUCMD "$MKVFILE" | cut -f1)
	AC3FILESIZE=$($DUCMD "$AC3FILE" | cut -f1)
	WDFREESPACE=$(\df -Pk "$WD" | tail -1 | awk '{print $4}')
	if [ $(($MKVFILESIZE + $AC3FILESIZE)) -gt $WDFREESPACE ]; then
		echo "WTF? There is not enough free space to copy the new MKV over the original. Free up some space and then copy $NEWFILE over $MKVFILE. Exit 1" >>  /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;
		exit 1
	fi
fi

if [ $EXTERNAL ]; then
	# We need to trick the rest of the script so that there isn't a lot of
	# code duplication. Basically $NEWFILE will be the AC3 track and we'll
	# change $MKVFILE to where we want the AC3 track to be so we don't
	# overwrite the MKV file only an AC3 track
	NEWFILE=$AC3FILE
	MKVFILE="$DEST/$NAME.ac3"
else
# Start to "build" command
CMD="nice -n $PRIORITY mkvmerge"

	# Puts the AC3 track as the second in the file if indicated as initial
	if [ $INITIAL = 1 ]; then
		CMD="$CMD --track-order 0:1,1:0"
	fi

	# Declare output file
	CMD="$CMD -o \"$NEWFILE\""


	CMD="$CMD -A"

	# Get track ID of video track
	VIDEOTRACK=$(mkvmerge -i "$MKVFILE" | grep -m 1 "$VIDEOTRACKPREFIX" | cut -d ":" -f 1 | cut -d " " -f 3)
	# Add original MKV file, set header compression scheme
	CMD="$CMD --compression $VIDEOTRACK:$COMP \"$MKVFILE\""


	# If user wants new AC3 as default then add appropriate arguments to command
	if [ $DEFAULT ]; then
		CMD="$CMD --default-track 0"
	fi

	# If the language was set for the original Surround Sound track set it for the AC3
	if [ $DTSLANG ]; then
		CMD="$CMD --language 0:$DTSLANG"
	fi

	# If the name was set for the original Surround Sound track set it for the AC3
	if [ "$DTSNAME" ]; then
		CMD="$CMD --track-name 0:\"$DTSNAME\""
	fi

	# If there was a delay on the original Surround Sound set the delay for the new AC3
	if [ $DELAY != 0 ]; then
		CMD="$CMD --sync 0:$DELAY"
	fi

	# Set track compression scheme and append new AC3
	CMD="$CMD --compression 0:$COMP \"$AC3FILE\""

	##SFE - Remove any subtitle tracks present
	CMD="$CMD --no-subtitles"

	# ------ MUXING ------
	# Run it!
	doprint $"Running main remux."
	doprint "> $CMD"
	dopause
	if [ $EXECUTE = 1 ]; then
		echo "4. Processing complete. Remuxing file with new AC3 soundtrack" >>  /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;
		eval $CMD 2>&1|perl -ne '$/="\015";next unless /(Progress:\s*\d+%)/;$|=1;print "\r",$1' #Use Perl to change EOL from \n to \r show Progress %
		echo 	#Just need a CR to undo the last \r printed
	fi

	# Delete AC3 file if successful
	doprint $"Removing temporary AC3 file."
	doprint "> rm -f \"$AC3FILE\""
	dopause
	cleanup "$AC3FILE"
fi

if [ $EXECUTE = 1 ]; then

echo "Moving new file over old file. DO NOT KILL THIS PROCESS OR YOU WILL EXPERIENCE DATA LOSS!"

echo $"NEW FILE: $NEWFILE"
echo $"MKV FILE: $MKVFILE"
$RSYNCCMD "$NEWFILE" "$MKVFILE"

else
	doprint ""
	doprint $"Copying new file over the old one."
	doprint "> cp \"$NEWFILE\" \"$MKVFILE\""
	dopause

	# Check there is enough free space for the new file
	if [ $EXECUTE = 1 ]; then
		MKVFILEDIFF=$(($($DUCMD "$NEWFILE" | cut -f1) - $MKVFILESIZE))
		DESTFREESPACE=$(\df -k "$DEST" | tail -1 | awk '{print $4*1024}')
		if [ $MKVFILEDIFF -gt $DESTFREESPACE ]; then
			echo "WTF? There is not enough free space to copy the new MKV over the original. Free up some space and then copy $NEWFILE over $MKVFILE. Exit 1" >>  /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;
			exit 1
		fi

		# Rsync our new MKV with the AC3 over the old one OR if we're using the -e
		# switch then this actually copies the AC3 file to the original directory
		info $"Moving new file over old file. DO NOT KILL THIS PROCESS OR YOU WILL EXPERIENCE DATA LOSS!"
		$RSYNCCMD "$NEWFILE" "$MKVFILE"
	fi
	# Remove new file in $WD
	doprint ""
	doprint $"Remove working file."
	doprint "> rm -f \"$NEWFILE\""
	dopause
	cleanup "$NEWFILE"
fi

echo "5. All done! Enjoy the movie lounge lizard." >>  /home/$sab_USER/.sabnzbd/logs/PostProcLog/sab_PP_log.txt;

exit 0
