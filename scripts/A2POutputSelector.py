import json
import os
import requests
import sys

def eprint(*args, **kwargs):
    print(*args, file=sys.stderr, **kwargs)

def owntone_get_outputs(setids = False, checkSelection = False, debug = False):

    # Function variables
    ownToneOutSelected = None

    print("Getting OwnTone output(s)")
    ownToneOutReq = requests.get("http://" + ownToneServer + ownToneApiOutGet)

    if debug:
        print("Status code")
        print(ownToneOutReq.status_code)

    if ownToneOutReq.status_code != 200:
        print("Failed OwnTone output(s) retrieval")
        print("Response Body:", ownToneOutReq.content.decode())
        exit(200)

    ownToneOutData = ownToneOutReq.json()

    for ownToneOutDetails in ownToneOutData['outputs']:
        if debug:
            print(ownToneOutDetails)
        if ownToneOutDetails['name'] in userOutList:
            print("Found '" + ownToneOutDetails['name'] + " type '" + ownToneOutDetails['type'] + "' selected '" + str(ownToneOutDetails['selected']) + "'")
            if setids == True:
                ownToneOutSetStruct['outputs'].append(ownToneOutDetails['id'])
            if checkSelection:
                # at startup ownToneOutSelected is set to None, if ownToneOutSelected will evaluate false
                if ownToneOutSelected:
                    ownToneOutSelected = ownToneOutSelected and ownToneOutDetails['selected']
                else:
                    ownToneOutSelected = ownToneOutDetails['selected']

    if setids == True:
        ownToneOutSetStruct['outputs'] = sorted(set(ownToneOutSetStruct['outputs']))
        if debug:
            print("ownToneOutSetStruct")
            print(ownToneOutSetStruct)
    if checkSelection:
        print("All output(s) selected", ownToneOutSelected)

def owntone_set_outputs(ownToneOutputs, debug = False):
    print("Setting OwnTone output(s)")
    if debug:
        print(ownToneOutputs)

    ownToneOutReq = requests.put("http://" + ownToneServer + ownToneApiOutSet, data = json.dumps(ownToneOutputs))

    if ownToneOutReq.status_code != 204:
        print("Failed OwnTone output(s) set")
        print("Response Body:", ownToneOutReq.content.decode())
        exit(220)

    if debug:
        print("Status code")
        print(ownToneOutReq.status_code)
        print(ownToneOutReq.content.decode())
        print(ownToneOutReq)

# OwnTone API
ownToneApiOutGet = '/api/outputs'
ownToneApiOutSet = '/api/outputs/set'

ownToneOutSetStruct = {'outputs' :[]}

# Get owntone server - if no localhost
scriptDebug = os.environ.get('A2P_DEBUG', False)

# Get owntone server - if no localhost
ownToneServer = os.environ.get('A2P_OT_HOST', 'localhost:3689')

# Get list of user desiderd output(s)
userOutString = os.environ.get('A2P_OT_OUT_LIST', '')

if userOutString == '' :
    eprint("Env variable 'A2P_OT_OUT_LIST' not set")
    exit(100)

print("Output(s) to be selected: " + userOutString)

# Make output selection string a list
# * remove leading and trailing newlines
userOutString = userOutString.strip("\n")
# * split the comma separated output list
userOutList = userOutString.split(',')
# * sort and unique 
userOutList = sorted(set(userOutList))
# * remove leading and trailing spaces, tabs and new line introduced by mistake in userOutList 
userOutList = [userOut.strip(" \n\t") for userOut in userOutList]

# Retrieve output from OwnTone
owntone_get_outputs(setids = True, debug = scriptDebug)

# * check if at least on on the requested output was found
if len(ownToneOutSetStruct['outputs']) == 0:
    eprint("No output found on OwnTone matching the selected criteria")
    exit(210)

# * check if less output than expected were found
if len(ownToneOutSetStruct['outputs']) != len(userOutList):
    print("WARN Not all the requested output(s) could be found on OwnTone")

# Set OwnTone output
owntone_set_outputs(ownToneOutSetStruct, debug = scriptDebug)

# Retrieve output from OwnTone to check selection
owntone_get_outputs(debug = scriptDebug, checkSelection = True)