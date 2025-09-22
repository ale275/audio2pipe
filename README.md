# audio2pipe
Set of scripts and services to better handle pipe creation for audio streamers. Recommended in conjunction with [OwnTone](https://owntone.github.io/owntone-server/)

System is comprised of the following components:
#### **scripts/A2PSourceProcess.sh**
Universal bash script taking various ENV variable for configuration to make monitor and audio pipes, pid monitoring and output selector callback function.

Script has three execution phases
- **Pre:** running all the preparatory check before cpiped is started. Executed only once at service start
- **Detect:** Section run at sound detect. It runs python output selector callback script. script can be replaced at user discretion by replacing the symlinked script
- **Silence:** Performs all the files clean-up when audio source is stopped

#### **scripts/A2POutputselector.py**
Python script using OwnTone http API(s) to select the output(s) defined in ENV variable at sound detect phase.

#### **Install**
Script to create a customized set of audio and monitor pipe for each device and audio source pair.
Generic bash script will take care of environment pre-check, audio detect tasks and silence clean-up.

Associated SystemD service file will be created to run cpiped, customized for the specific input.

Existence of all dependencies and daemon base dir configuration will be also done here.

### Config ENV variables
- **A2P_HOME:** audio2pipe base-dir. *var* folder will be created here containing subfolder for PID and detect pipe(s) managements. If not specified user home will be used
- **A2P_DEVNAME:** device input name. Mnemonic that will define all the specialized file name
  - PID file: *var/run/A2P_<A2P_DEVNAME>.pid*
  - Detect pipe: *var/pipes/A2PDETECT_<A2P_DEVNAME>.pipe*
  - Audio pipe: *<A2P_OT_LIB>/<A2P_DEVNAME>*
  - systemd service file: *cpiped_<A2P_DEVNAME>.service*
- **A2P_CP_SOUNDCARD:** audio input soundcard to be passed to cpiped in *hw:\<card>,\<device>* format
- **A2P_CP_SL:** cpiped silence level
- **A2P_OT_LIB:** OwnTone library folder. Where the audio pipe will be created and filled on sound detection
- **A2P_OT_HOST:** OwnTOne server hostname. Default *localhost*
- **A2P_OT_OUT_LIST:** OwnTone output(s) label to be selected at sound detect
- **A2P_DEBUG:** make log more verbose. Accepts True or False values

## Dependencies
- Bash
- Python
- [CPiped](https://github.com/b-fitzpatrick/cpiped)

## ToDo(s)
- [ ] Move ENV variable setup from Service file to EnvironFile to define monitoring pipe in pre stage
- [ ] Rework detect pipe section that is prone to config error
- [ ] Create install script
- [ ] Add command line parameters to A2POutputselector.py
- [ ] Change detect pipe extension from .pipe to .detectpipe
- [ ] Improve systemd service ExecStop section of script to stop the device specific instance of cpiped and not all of them
- [ ] Fix systemd service KillMode warning

## Credits

Based on [Making an Analog In to Airplay RPi-Transmitter](https://github.com/owntone/owntone-server/wiki/Making-an-Analog-In-to-Airplay-RPi-Transmitter) from ownTone wiki

Created to be used with [OwnTone](https://owntone.github.io/owntone-server/)
