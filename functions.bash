#!/bin/bash

#function to write onto log files for echo statements
function writeLog {

    if [ -t 0 ]
    then
        data=$1
	    echo "nopipe"
    else
        data=$(cat)
        if [ "$DEBUG" -eq "1" ]; then #if debugging echo onto stdout as well
	        echo  "$data" >> "$logFile"
	        echo "DEBUG:: $data"
	    else
	        echo  "$data" >> "$logFile"
	    fi
    fi

}

#function to write onto log files for the manifest
function writeULog {

    if [ -t 0 ]
    then
        data=$1
	    echo "nopipe"
    else
        data=$(cat)
        if [ "$DEBUG" -eq "1" ]; then #if debugging echo onto stdout as well
	        echo  "$data" >> "$uploadLog"
	        echo "DEBUG:: $data"
	    else
	        echo  "$data" >> "$uploadLog"
	    fi
    fi

}

#function to output debug messages onto logfile as stdout, data has to be piped into it
function ifDebug {
    if [ "$DEBUG" -eq "1" ]; then
        if [ -t 0 ]
        then
            data=$1
	        echo "No Message"
        else
            data=$(cat)
            echo "DEBUG:: $data" >> "$logFile"
	        echo "DEBUG:: $data"
        fi
    fi
}

function encryptFile {

    fullpath=$(realpath "$1")
    #filename=$2
    encName=$2
	echo "ENCFUNC:: $fullpath  2ND PARAMETER: $encName " | ifDebug
	openssl enc -e -in "$fullpath" -aes-256-cbc -pass file:"$key2" -nosalt > "$tempFolder/$encName" #create encrypted file to upload to backblaze
	filechecksum=$(sha1sum "$tempFolder/$encName" | awk '{print $1}') #create a file checksum for encrypted file for backblaze upload confirmation
	echo "Encrypted checksum $filechecksum" | ifDebug
	b2 upload-file --sha1 "$filechecksum" --threads 4 "$bucketName" "$tempFolder/$encName" "$encName" | writeLog
	rm -f "$tempFolder/$encName" #remove encrypted file from $tempFolder
	echo "Temp File removed $tempFolder/$encName" | writeLog
	echo "$fullpath - $encName" | writeULog
}

function encryptFileName {

    fullpath=$(realpath "$1")
	#simplistic encryption of the full path and name to obfuscate the backup names
	encFileName=$(echo "$fullpath" | openssl enc -base64 -A -aes-256-cbc -pass file:"$key1" -nosalt | base64 | tr -d "\n" ) #create encrypted filename, encode with base64 to ensure it is clean and can be used as filename
	fileChecksum=$(sha1sum "$fullpath" | awk '{print $1}') #create filechecksum to add as part of filename
	echo "$encFileName-$fileChecksum.enc"
}

function backup {
	echo "hello stub for backup function"
}

function checkBinaries {
	checkB2=$(b2 version | grep version | wc -l)
	checkOpenssl=$(openssl version -a | grep OPENSSLDIR | wc -l )

	if [[ "$checkB2" -lt "1" || "$checkOpenssl" -lt "1" && "$DEBUG" -eq "1" ]]
	then
		echo "Check your pre-requisite binaries are installed... i.e. b2 cli, openssl"
		exit 400
	else
		echo "all good."
	fi
}

function restoreFilePath {
	encrypted="$1"
	decrypted=$(echo "$encrypted" | base64 -d | openssl enc -d -base64 -A -aes-256-cbc -pass file:"$key1" -nosalt) #decrypt file path
	echo "$decrypted"
}

function restoreFile {
	fileToRestore="$1"
	localFile="$2"
	tempFilename="toRestore-$(date +%s)"
	b2 download-file-by-name "$bucketName" "$fileToRestore" "$tempFolder/$tempFilename"
	openssl enc -d -in "$tempFolder/$tempFilename" -aes-256-cbc -pass file:"$key2" -nosalt > "$localFile" #create encrypted file to upload to backblaze
	echo "Restored $localFile"
}

##Grab the name of the latest log file
function getLatestUploadLog {
  shortName="${uploadLog:0:5}"
  latest=$(ls -lt $shortName* | awk '{print $9}' | head -n1 )
  echo $latest
}

##check if the file being checked is in the log
function checkFileUploaded {
  checkFile="$1"
  logPath=$(dirname $0)
  logPath=$(realpath $logPath)
  inFile=$(cat $logPath/$latestLog | grep $checkFile | wc -l)
  echo $inFile
}
