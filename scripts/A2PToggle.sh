#!/bin/bash

_cpipedUnitToStopList=()
_cpipedUnitToStartList=()

# functions
userAnsValidation () {
    local _userAns=$1

    # defaulting empty to y
    [ "-${_userAns}-" == "--" ] && _userAns=y

    case "$_userAns" in
        Y|y|1)
            return 0
            ;;

        N|n|0)
            return 1
            ;;

        *)
            echo "Input '$_userAns' is not valid. Allowed values [y/n]"
            return 3
            ;;

    esac

}

unitControl () {
    local _cpipedUnit=$1
    local _systemctlCmd=$2

    systemctl ${_systemctlCmd} ${_cpipedUnit}
    _sysRet=$?

    [[ ${_sysRet} -eq 0 ]] && echo "${_cpipedUnit} ${_systemctlCmd}ed successfully"
    [[ ${_sysRet} -eq 1 ]] && echo "${_cpipedUnit} did not ${_systemctlCmd} successfully"

}

# fail if not sudo
if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    echo "User must have sudo rights. Exiting..."
    exit 10
fi

# get all the cpiped units
readarray -t _cpipedUnitList < <(systemctl list-unit-files | grep cpiped_ | awk '{print $1}')

for _cpipedUnit in ${_cpipedUnitList[@]} 
do
    # return 0 if service is active
    systemctl is-active --quiet "${_cpipedUnit}"
    _cpipedUnitRunning=$?


    while true;
    do

        [[ ${_cpipedUnitRunning} -eq 0 ]] && read -p "${_cpipedUnit} is $(tput bold)running$(tput sgr0). Do you want to stop it? [Y/n] " _userAns
        [[ ${_cpipedUnitRunning} -ne 0 ]] && read -p "${_cpipedUnit} is $(tput bold)not running$(tput sgr0). Do you want to start it? [Y/n] " _userAns

        # read answer and validate
        userAnsValidation ${_userAns}
        _userAns=$?

        # if unit is running and answer yes add to list of service to be stopped
        [[ ${_cpipedUnitRunning} -eq 0 && ${_userAns} -eq 0 ]] && _cpipedUnitToStopList+=(${_cpipedUnit})
        # if unit is not running and answer yes add to list of service to be started
        [[ ${_cpipedUnitRunning} -ne 0 && ${_userAns} -eq 0 ]] && _cpipedUnitToStartList+=(${_cpipedUnit})
        [[ ${_userAns} -eq 0 || ${_userAns} -eq 1 ]]; break
    done

done

if [[ ${#_cpipedUnitToStopList[@]} -gt 0 ]]; then
    echo "Stopping unit(s).."
    for _cpipedUnitToStop in ${_cpipedUnitToStopList[@]}
    do
        _unitCtlRet=$( unitControl ${_cpipedUnitToStop} stop )
        echo "* ${_unitCtlRet}"
    done
else
    echo "No unit to be stopped"
fi

if [[ ${#_cpipedUnitToStartList[@]} -gt 0 ]]; then
    echo "Starting unit(s).."
    for _cpipedUnitToStart in ${_cpipedUnitToStartList[@]}
    do
        _unitCtlRet=$( unitControl ${_cpipedUnitToStart} start )
        echo "* ${_unitCtlRet}"
    done
else
    echo "No unit to be started"
fi
