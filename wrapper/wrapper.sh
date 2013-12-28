#!/bin/bash



#variables
source ./deploy-common.conf #Reads common variables between deploy.sh and wrapper.sh
source ./custom.conf #Reads custom common variables between deploy.sh and wrapper.sh
log_verbose=1 		#whether or not to display output on terminal screen
log=/var/log/bitlancer-wrapper.log #logfile name
model="" 		#passed from strings
model_name="" 		#passed from Strings
server_list="" 		#passed from Strings
server_array=""		#Used to parse server list
server_hostname=""	#used in building command list
server_role=""		#used in building command list
server_profile=""       #used in building command list
cloud_files_credentials="" #passed from Strings
repo="" 		#passed from Strings
reposhort=""		#later derived from repo
config_reposhort=""	#later derived from deploy-common.conf configrepo
ref="" 			#passed from Strings
validate_count=0 	#Used for validating switches
validate_string=""	#Used for validation switches
validate_param="" 	#Used for obtaining valid switches parameters
validate_success=0 	#Switch to check status of switch validity
validate_var="" 	#variable to set in script from Strings variables
OFS=$(echo $IFS)	#Original file separator (internal var.) Using to reset later
dirpath=""         	#Used for setting a path to use with CreateDir
tarpath=""		#Used for reading what file(s) to tar up for deployment
wraplock="/var/lock/bitlancer-wrapper.lck"	#Used to prevent multiple runs

#sourcing our models
source ./*.model #functions that build an application model
#sourcing check_model function to keep this script modular
source ./models.case



#Functions
function logger {
  #Used for verbose logging to console as well as logging to files.
  if [ $log_verbose -eq 1 ]
  then
     #Echo out to the console as well as write to the log file.
     echo $log_string >> $log
     echo $log_string
     #clear log_string for next instantiation
     log_string=""
  else
     #Write out to the log only.
     echo $log_string >> $log
     #clear log_string for next instantiation
     log_string=""
  fi
}

function chk_running {
  if [[ -f $wraplock ]]
    then
        log_string="Error: Script is already running."
        logger
        log_string="Time of Error: `date`"
        logger
        #you don't want to clean_local in this case
        exit 5
  fi
}

function clean_local {
  #cleans up local temp deploy data
  log_string="Cleaning up temp deploy data."
  logger
  rm -rf $staginghome$ref
  rm -rf $packagehome$ref
  rm -rf $gitrepohome$ref
  rm -rf $osdata$ref
  rm -f *.$ref.sh
}

function rm_lock {
 #remove lock file
      rm -f $wraplock
      if [[ $? -eq 0 ]]
      then
          log_string="Lock file removed successfully."
          logger
      else
          log_string="Lock file was unable to be removed."
          logger
      fi
}

function get_parameter {
  #Used to grab the valid switch's parameter string
  log_string=$validate_param
  logger
  eval $validate_var='$validate_param'
  log_string="validate_var set to $validate_var"
  logger
  eval log_string=\${"${validate_var}"}
  logger
  echo
}

function validate_input {
  #Used to validate the switches coming from Strings against recognized options
  log_string="Validating"
  logger
  log_string="Switch $validate_string provided"
  logger
  case "$validate_string" in
    --model) log_string="model"
             logger
             validate_var="model"
             validate_count=$((validate_count +1))
             validate_success=$((validate_success +1))
             ;;
    --model-name) log_string="model-name"
                  logger
                  validate_var="model_name"
                  validate_count=$((validate_count +1))
                  validate_success=$((validate_success +1))
                  ;;
    --server-list) log_string="server-list"
                   logger
                   validate_var="server_list"
                   validate_count=$((validate_count +1))
                   validate_success=$((validate_success +1))
                   ;;
    --cloud-files-credentials) log_string="cloud-files-credentials"
                               logger
                               validate_var="cloud_files_credentials"
                               validate_count=$((validate_count +1))
                               validate_success=$((validate_success +1))                                                 ;;
    --repo) log_string="repo"
            logger
            validate_var="repo"
            validate_count=$((validate_count +1))
            validate_success=$((validate_success +1))
            ;;
    --ref) log_string="ref"
           logger
           validate_var="ref"
           validate_count=$((validate_count +1))
           validate_success=$((validate_success +1))
           echo $validate_count
          ;;
    *) log_string="Unknown Switch"
       logger
       validate_count=$((validate_count +1))
       ;;
  esac

  #if [[ $validate_string == "--model" ]]
  #then
  #   echo "model"
  #else
  #   echo "invalid switch $validate_string"
  #fi   
}

function CreateDir {
  #creates a new directory and verifies.
  log_string="Creating missing directory."
  logger
  mkdir -p $dirpath 2>&1&>>$log
  if [ $? -eq 0 ]
  then
      log_string="Directory created."
      logger
      dirsuccess=1
  else
      log_string="Directory failed to be created.  Check directory permissions."
      logger
      dirsuccess=0
  fi
}

function role_check {
  #Checks to see what role we're using and determines what work to do
  case "$server_role" in
    "Drupal 7 Web Server") log_string="Role is: $server_role"
                           logger
                           ;;
    "Primary MySQL Server") log_string="Role is: $server_role"
                            logger 
                            ;;
  esac
}

#may move this out to a file to keep modular, but not sure yet
function check_profile () {
  #Checks to see what profiles we're using and determines what work to do
  server_profile="$1"
  echo "Checking Profile: $server_profile"
  case "$server_profile" in
    "Apache Web Server") log_string="Profile is: $server_profile"
                         logger
                         ;;
    "Base Node") log_string="Profile is: $server_profile"
                 logger
                 ;;
    "MySQL Server") log_string="Profile is: $server_profile"
                    logger
                    ;;
    *) log_string="Unrecognized Server Profile Name specified: $server_profile"
       logger
       clean_local
       rm_lock
       exit 1 
         ;;
  esac
}

function create_tarball {
#packages our repository and data for deployment
  dirpath=$packagehome
  CreateDir
  present=`pwd` #moving around to create clean tars will ref on success of tar create
  cd "$tarpath" && tar -zcvf "$packagehome$ref/$model_name.tar.gz" *

  if [[ $? -eq 0 ]]
  then
      log_string="Created deployment"
      logger
      cd "$present" #moving back to previous path due to success
  else
      log_string="Unable to create tar deployment."
      logger
      clean_local
      rm_lock
      exit 5
  fi
}

function parse_serverlist {
  #Reads server_list string and starts doing work
  IFS=';' #changed the internal field selector to 
  read -ra single_server_list <<< "$server_list"
  for i in "${single_server_list[@]}"; do
    log_string="single_server_list is: $i"
    logger
    #do work on single_server_list now that we have it
    IFS=',' #changed the internal field separator to split on comma
    read -ra item <<< "$i"  #created an array for the single_server_list items
    log_string="List by array index"
    logger
    log_string="${item[0]}"  #hostname
    logger
    #Set curent hostname
    server_hostname="${item[0]}"
    log_string="${item[1]}"  #role
    logger
    #Set current role
    server_role="${item[1]}"
    log_string="${item[2]}"  #profile 1
    logger
    log_string="${item[3]}"  #profile 2
    logger
    check_profile "${item[2]}"
    #put some logic now that we have a profile and model to deploy
      #run the models profile command structure
      eval `echo "$model_name" | tr -d ' '`_`echo "$server_profile" | tr -d ' '` #this launches the .model function
    check_profile "${item[3]}"
    #put some logic now that we have a profile and model to deploy
    eval `echo "$model_name" | tr -d ' '`_`echo "$server_profile" | tr -d ' '` #this launches the .model function
    done
}

function cleanup_local {
  #cleans all local cache locations
  log_string="Cleaning up local deploy caches."
  logger
  #add logic

}

#Start Logging
log_string="--------------------------------------------------"
logger
echo >> $log
log_string="Work Received on: `date`"
logger

#see if the script is already running
chk_running

#Not running so create the lock File
date > $wraplock

#Read in Variables from Strings
  #12 possible parameters
  while [ $validate_count -lt 11 ]; do
    validate_count=$((validate_count +1))
    eval validate_string=\${$validate_count}
    validate_input
    if [[ validate_success -eq 0 ]]
    then
        echo "You hit me with a bad bad switch"
    else
       eval validate_param=\${$validate_count}
       get_parameter
       #reset to 0 so loop works
       validate_success=0
    fi
  done

#set the repo shortname now that we read in variables a req't of deploy.sh GitConf func.
reposhort=$(basename ${repo%.*})
config_reposhort=$(basename ${config_repo%.*})
parse_serverlist



#Set the internal field separator back to what it was when we started
IFS=$OFS
echo "Set internal field separator back to: $IFS"

#Exit Clean
clean_local
rm_lock
exit 0