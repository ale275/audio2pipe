#!/bin/bash

errcho(){ >&2 echo $@; }

_scriptHome=${A2P_HOME:-$HOME}
_scriptName=$(basename $0)

_mode=$1
_deviceName=${A2P_DEVNAME}
_deviceFormat=${A2P_DEVFORMAT}
_deviceSampleFrequency=
_deviceSampleFormat=
_deviceChannelCount=
_cpipedSR=${CPIPED_SR:-NOTDEF}
_cpipedSS=${CPIPED_SS:-NOTDEF}
_cpipedCC=${CPIPED_CC:-NOTDEF}
_owntoneLibPath=${A2P_OT_LIB}
_owntoneHost=${A2P_OT_HOST:-localhost:3689}
_silenceWriteLen=.5

# Command line parameters validation
while getopts 'd:f:l:m:hs:' opt; do
  case "$opt" in
    d)
      _deviceName="$OPTARG"
      ;;

    f)
      _deviceFormat="$OPTARG"
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
      echo "    -f  <DEVICE FORMAT [STR]> Concatenation of sample format and sample frequency separated by two underscores"
      echo "        Example: sample format 16bit Little Endian and sample frequency 48kHz will be S16_LE__48000"
      echo "        It overrides the ENV variable A2P_DEVFORMAT and CPIPED_SR, CPIPED_SS, CPIPED_CC defined by cpiped"
      echo "        To be used only if installed cpiped version doesn't support export of env variables"
      echo "    -l  <OWNTONE LIB [STR]> Set the path for OwnTone library. Audio pipe will be created there"
      echo "        It overrides the ENV variable A2P_OT_LIB"
      echo "    -m  <MODE [STR]>        Set script execution mode. Valid options:"
      echo "        PRE     Run all pre-checks to be sure all folders and files exists. Sourced only once at service start"
      echo "        DETECT  Redirect detection pipe to main audio pipe"
      echo "        SILENCE Clean-up once no audio is being sent through the pipe"
      echo "        STOP    Clean-up once service is stopped"
      echo ""
      echo "        Mode can be derived from script name ending, useful if called though symlinks"
      echo "        Pre     -> MODE is set to PRE"
      echo "        Detect  -> MODE is set to DETECT"
      echo "        Silence -> MODE is set to SILENCE"
      echo "        Stop    -> MODE is set to STOP"
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
    [[ "${_scriptName}" =~ (Stop)$ ]] && _mode=STOP
fi
if [[ ! "${_mode}" =~ (PRE)|(DETECT)|(SILENCE)|(STOP) ]]; then
    errcho "Mode '${_mode}' is not a valid mode"
    exit 100
fi

# * _deviceName ----
if [[ "-${_deviceName}-" == "--" ]]; then
    errcho "Device name cannot be null"
    exit 100
fi

if [[ "${_mode}" != "PRE" && "${_mode}" != "STOP" ]]; then
    # * _deviceFormat ----
    if [[ "-${_deviceFormat}-" != "--" ]]; then
        echo "Device format: ${_deviceFormat}"
        _deviceSampleFormat=$(echo ${_deviceFormat} | grep -oP '((?<=^S)[0-9]{1,2}(?=_LE))')
        if [[ $? -ne 0 ]]; then
            errcho "Unknown sample format"
            exit 100
        fi
        _deviceSampleFrequency=$(echo ${_deviceFormat} | grep -oP '((?<=__)[0-9]{1,6}$)')
        if [[ $? -ne 0 ]]; then
            errcho "Unknown sample frequency"
            exit 100
        fi
    else
        if [[ "${_cpipedSR}" != "NOTDEF" ]]; then
            _deviceSampleFrequency=${_cpipedSR}
        else
            echo "Using default sample rate 44100 Hz"
            _deviceSampleFrequency=41000
        fi

        if [[ "${_cpipedSS}" != "NOTDEF" ]]; then
            _deviceSampleFormat=${_cpipedSS}
        else
            echo "Using default sample format S16_LE"
            _deviceSampleFormat=16
        fi
    fi

    # * channel count ----
    if [[ "${_cpipedCC}" != "NOTDEF" ]]; then
        _deviceChannelCount=${_cpipedCC}
    else
        echo "Using default 2 channels count"
        _deviceChannelCount=2
    fi
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

# Functions
silenceWrite () {
    local _pipeToWrite=$1
    echo "Writing ${_silenceWriteLen}s of silence to '${_pipeToWrite}'"
    # Calculate audio stream size - OwnTone expects 44100 sample rate 16bit per channel 2 channels
    _silenceStreamSize=$( echo "(${_silenceWriteLen} * 44100 * (16 / 8) ) / 1" | bc )
    head -c ${_silenceStreamSize} < /dev/zero > "${_pipeToWrite}"
}


if [[ "${_mode}" == "PRE" ]]; then
    #
    # PRE
    #

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
    if [[ -p "${_owntoneLibPath}/${_audioPipeName}" || -f "${_owntoneLibPath}/${_audioPipeName}" ]]; then
        rm "${_owntoneLibPath}/${_audioPipeName}"
    fi

    # Audio Pipe
    if [[ ! -p "${_owntoneLibPath}/${_audioPipeName}" ]]; then
        echo "Creating audio pipe '${_owntoneLibPath}/${_audioPipeName}'"
        mkfifo -m 666 "${_owntoneLibPath}/${_audioPipeName}"

        if [[ $? -ne 0 ]]; then
            errcho "Failed creating audio pipe '${_owntoneLibPath}/${_audioPipeName}'"
            exit 200
        fi

        # Write some silence in the pipe
        silenceWrite "${_owntoneLibPath}/${_audioPipeName}"
    fi

elif [[ "${_mode}" == "DETECT" ]]; then
    #
    # DETECT
    #

    echo "Sound detected, preparing the environment"

    echo "Device sample frequency: ${_deviceSampleFrequency}Hz"
    echo "Device sample format: ${_deviceSampleFormat}bit Little Endian"
    echo "Device channel count: ${_deviceChannelCount}"

    # Select output(s) if selection script exists
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

    else
        echo "Audio pipe exists"
        silenceWrite "${_owntoneLibPath}/${_audioPipeName}"
    fi

    echo "Starting audio pipe filling"
    if [[ "${_deviceSampleFrequency}" == "44100" && "${_deviceSampleFormat}" == "16" && "${_deviceChannelCount}" == "2" ]]; then
        cat "${_detectPipeDir}/${_detectPipeName}" > "${_owntoneLibPath}/${_audioPipeName}" &
        echo $! > "${_pidDir}/${_pidName}"
    else
        sox -t raw -r ${_deviceSampleFrequency} -e signed -b ${_deviceSampleFormat} -c ${_deviceChannelCount} "${_detectPipeDir}/${_detectPipeName}" -t raw -r 44100 -e signed -b 16 -c 2 - > "${_owntoneLibPath}/${_audioPipeName}" &
        echo $! > "${_pidDir}/${_pidName}"
    fi

elif [[ "${_mode}" == "SILENCE" ]]; then
    #
    # SILENCE
    #
    _prevPid=$(< "${_pidDir}/${_pidName}")

    echo "Silence detected killing audio pipe filling (pid ${_prevPid})"

    # Kill pipe filling only if previous pid is defined
    if [[ "-${_prevPid}-" != "--" ]]; then
        kill -0 ${_prevPid}
        if [[ $? -eq 0 ]]; then
            echo "Process running, killing it"
            kill -9 ${_prevPid}
        else
            echo "No process to be killed, something is off"
        fi

        # If using sox instead of cat, killing might take a bit longer
        [[ "${_deviceSampleFrequency}" != "44100" || "${_deviceSampleFormat}" != "16" || "${_deviceChannelCount}" != "2" ]] && sleep 1

        # pid clean-up
        echo "" > "${_pidDir}/${_pidName}"
    fi

    echo "Clearing OwnTone queue"
    # Stop playing
    curl -sS -X PUT "http://${_owntoneHost}/api/player/stop"
    [ $? -ne 0 ] && echo "WARN failed to stop OwnTone player"
    # Next song
    curl -sS -X PUT "http://${_owntoneHost}/api/player/next"
    [ $? -ne 0 ] && echo "WARN failed skip song on OwnTone player"
    # Clear queue
    curl -sS -X PUT "http://${_owntoneHost}/api/queue/clear"
    [ $? -ne 0 ] && echo "WARN failed clear OwnTone player queue"

    # De-select output(s) if selection script exists
    if [[ -x "${_outSelScript}" ]]; then
        echo "Deselect OwnTone output(s)"
        curl -sS -X PUT "http://${_owntoneHost}/api/outputs/set" --data "{\"outputs\":[]}"
    fi

elif [[ "${_mode}" == "STOP" ]]; then
    #
    # STOP
    #

    if [[ -p "${_owntoneLibPath}/${_audioPipeName}" || -f "${_owntoneLibPath}/${_audioPipeName}" ]]; then
        echo "Removing audio pipe"
        rm "${_owntoneLibPath}/${_audioPipeName}"
    fi
    if [[ -p "${_detectPipeDir}/${_detectPipeName}" || -f "${_detectPipeDir}/${_detectPipeName}" ]]; then
        echo "Removing detect pipe"
        rm "${_detectPipeDir}/${_detectPipeName}"
    fi
    if [[ -p "${_pidDir}/${_pidName}" || -f "${_pidDir}/${_pidName}" ]]; then
        echo "Removing pipe filling pid"
        rm "${_pidDir}/${_pidName}"
    fi
fi

exit 0