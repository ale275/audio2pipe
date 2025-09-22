#!/bin/bash

errcho(){ >&2 echo $@; }

_scriptHome=${A2P_HOME:-$HOME}
_scriptName=$(basename $0)

_mode=$1
_deviceName=${A2P_DEVNAME}
_owntoneLibPath=${A2P_OT_LIB}

# Command line parameters validation
while getopts 'd:l:m:hs:' opt; do
  case "$opt" in
    d)
      _deviceName="$OPTARG"
      ;;

    l)
      _owntoneLibPath="$OPTARG"
      ;;

    m)
      _mode="$OPTARG"
      ;;

    s)
      _scriptHome="$OPTARG"
      ;;
   
    ?|h)
      echo "Usage: $(basename $0) [-d arg] [-l arg] [-m arg] [-s arg]"
      echo "---------------------------------------------------------"
      echo "    -d  <DEVICE NAME [STR]> Set name of connected device to the pipe. Will create all the mnemonics"
      echo "        It overrides the ENV variable A2P_DEVNAME"
      echo "        Audio pipe:         <DEVICE NAME>                   Audio pipe seen by OwnTone"
      echo "        Detect pipe:        A2P_DETECT_<DEVICE NAME>.pipe   Audio detection pipe used by CPIPED"
      echo "        Cat proc pid:       A2P_<DEVICE NAME>.pid           File storing the redirection process id"
      echo "        OwnTone Out Sel:    A2P_OT_OUT_SEL_<DEVICE NAME>    Script automatically sourced before audio redirection, useful to set per device OwnTone outputs"
      echo "    -l  <OWNTONE LIB [STR]> Set the path for OwnTone library. Audio pipe will be created there"
      echo "        It overrides the ENV variable A2P_OT_LIB"
      echo "    -m  <MODE [STR]>        Set script execution mode. Valid options:"
      echo "        PRE     Run all pre-checks to be sure all folders and files exists. Sourced only once at service start"
      echo "        DETECT  Redirect detection pipe to main audio pipe"
      echo "        SILENCE Clean-up once no audio is being sent through the pipe"
      echo ""
      echo "        Mode can be derived from script name ending, useful if called though symlinks"
      echo "        Pre     -> MODE is set to PRE"
      echo "        Detect  -> MODE is set to DETECT"
      echo "        Silence -> MODE is set to SILENCE"
      echo "    -s  <SCRIPT HOME [STR]> Set script execution root dir"
      echo "        It overrides the ENV variable A2P_HOME. If nor the variable nor the parameter are passed user home is used as root dir"
      echo ""
      echo "        Folder structure"
      echo "        <SCRIPT HOME>/bin       Location for OwnTone Out Selection script"
      echo "        <SCRIPT HOME>/var/pipes Location for detection pipes"
      echo "        <SCRIPT HOME>/var/run   Location for PID files"
      exit 1
      ;;
  esac
done
shift "$(($OPTIND -1))"

# Variables validation

# * _mode ----
if [[ "-${_mode}-" == "--" ]]; then
    echo "Deriving mode from script name"

    [[ "${_scriptName}" =~ (Pre)$ ]] && _mode=PRE
    [[ "${_scriptName}" =~ (Detect)$ ]] && _mode=DETECT
    [[ "${_scriptName}" =~ (Silence)$ ]] && _mode=SILENCE
fi
if [[ ! "${_mode}" =~ (PRE)|(DETECT)|(SILENCE) ]]; then
    errcho "Mode '${_mode}' is not a valid mode"
    exit 100
fi

# * _deviceName ----
if [[ "-${_deviceName}-" == "--" ]]; then
    errcho "Device name cannot be null"
    exit 100
fi

# * _owntoneLibPath ----
if [[ "-${_owntoneLibPath}-" == "--" ]]; then
    errcho "OwnTone lib cannot be null"
    exit 100
fi

if [[ ! -d "${_owntoneLibPath}" ]]; then
    errcho "OwnTone lib '${_owntoneLibPath}' is not a valid folder"
    exit 100
fi

echo "Executing A2P script for device '${_deviceName}' in mode '${_mode}'"

# Child variables init
_audioPipeName="${_deviceName}"
_outSelScript="${_scriptHome}/bin/A2P_OT_OUT_SEL_${_deviceName}"
_detectPipeDir="${_scriptHome}/var/pipes"
_detectPipeName="A2P_DETECT_${_deviceName}.pipe"
_pidDir="${_scriptHome}/var/run"
_pidName="A2P_${_deviceName}.pid"
_prevPid=

# Child variables validation

if [[ "${_mode}" == "PRE" ]]; then
    
    echo "Running pre-checks"

    # * _detectPipeDir ----
    if [[ ! -d "${_detectPipeDir}" ]]; then
        echo "Creating detect pipe folder '${_detectPipeDir}'"
        mkdir -p "${_detectPipeDir}"

        if [[ $? -ne 0 ]]; then
            errcho "Failed creating detect pipe folder '${_detectPipeDir}'"
            exit 110
        fi
    else 
        echo "Detect pipe folder exists"
    fi

    # * _pidDir ----
    if [[ ! -d "${_pidDir}" ]]; then
        echo "Creating process pid folder '${_pidDir}'"
        mkdir -p "${_pidDir}"

        if [[ $? -ne 0 ]]; then
            errcho "Failed creating process pid folder '${_pidDir}'"
            exit 110
        fi
    else 
        echo "Pid folder exists"
    fi

    # Detect Pipe
    if [[ ! -p "${_detectPipeDir}/${_detectPipeName}" ]]; then
        echo "Creating audio detect pipe '${_detectPipeDir}/${_detectPipeName}'"
        mkfifo -m 666 "${_detectPipeDir}/${_detectPipeName}"
        
        if [[ $? -ne 0 ]]; then
            errcho "Failed creating audio detect pipe '${_detectPipeDir}/${_detectPipeName}'"
            exit 200
        fi
    else 
        echo "Detect pipe exists"
    fi 

    # Remove audio pipe leftovers
    if [[ ! -p "${_owntoneLibPath}/${_audioPipeName}" ]]; then
        rm "${_owntoneLibPath}/${_audioPipeName}"
    fi

elif [[ "${_mode}" == "DETECT" ]]; then
    #
    # DETECT
    #

    echo "Sound detected, preparing the environment" 

    # Select speaker if selection script exists
    if [[ -x "${_outSelScript}" ]]; then
        echo "OwnTone output selection script found at '${_outSelScript}'"
        python "${_outSelScript}"
    fi

    # Audio Pipe
    if [[ ! -p "${_owntoneLibPath}/${_audioPipeName}" ]]; then
        echo "Creating audio pipe '${_owntoneLibPath}/${_audioPipeName}'"
        mkfifo -m 666 "${_owntoneLibPath}/${_audioPipeName}"
        
        if [[ $? -ne 0 ]]; then
            errcho "Failed creating audio pipe '${_owntoneLibPath}/${_audioPipeName}'"
            exit 200
        fi
    fi
    
    echo "Starting audio pipe filling" 
    cat "${_detectPipeDir}/${_detectPipeName}" > "${_owntoneLibPath}/${_audioPipeName}" &
    echo $! > "${_pidDir}/${_pidName}"

elif [[ "${_mode}" == "SILENCE" ]]; then
    #
    # SILENCE
    #
    _prevPid=$(< "${_pidDir}/${_pidName}")

    echo "Silence detected killing audio pipe filling pid ${_prevPid}"

    kill -0 ${_prevPid}
    if [[ $? -eq 0 ]]; then
        echo "Process running, killing it"
        kill ${_prevPid}
    else
        echo "No process to be killed, something is off"
    fi    

    echo "" > "${_pidDir}/${_pidName}"

fi