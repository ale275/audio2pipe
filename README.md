<h1>audio2pipe</h1>

<!-- [![Release][release-shield]][release-url] -->
![GitHub commit activity][commit-shield]
[![Issues][issues-shield]][issues-url]
[![Contributors][contributors-shield]][contributors-url]
[![project_license][license-shield]][license-url]
[![Stargazers][stars-shield]][stars-url]
[![Forks][forks-shield]][forks-url]
<!-- ![Build flow][build-shield] -->

![bash][bash-shield]
![python][python-shield]


    audio2pipe is a set of utilities to pipe sound towards other software

`audio2pipe` is a set of scripts and services to better handle pipe creation for audio streamers leveraging [cpiped](https://github.com/ale275/cpiped) under the hood. Recommended in conjunction with [OwnTone](https://owntone.github.io/owntone-server/)

## Contents

- [Contents](#contents)
- [Features](#features)
- [Getting Started](#getting-started)
  - [Prerequisites](#prerequisites)
  - [Installation](#installation)
- [Usage](#usage)
  - [scripts/A2PSourceProcess.sh](#scriptsa2psourceprocesssh)
  - [scripts/A2POutputselector.py](#scriptsa2poutputselectorpy)
  - [scripts/A2PToggle.sh](#scriptsa2ptogglesh)
  - [service/cpiped\_Template.service](#servicecpiped_templateservice)
  - [Configuration](#configuration)
- [ToDo(s)](#todos)
- [Acknowledgments](#acknowledgments)
  - [Top contributors:](#top-contributors)

## Features

- systemd service to manage cpiped instances supporting different sample rates
- Multiple input device supported with dedicated configuration
- Interlock to avoid out of sequence triggering of per device script
- Automatic OwnTone output selection on sound detection

## Getting Started

### Prerequisites

`audio2pipe` requires 
- bash
- [cpiped](https://github.com/ale275/cpiped)
- [python](https://www.python.org/) >= v3.11.2
  - requests 2.28.1

### Installation

1. Clone the repository
   ```sh
   git clone https://github.com/ale275/audio2pipe.git
   ```
2. Install scripts in audio2pipe base dir defined by *A2P_HOME* [env variable](#configuration) and setup needed symlink
   ```sh
   cd audio2pipe
   export A2P_HOME=/home/user
   install  -m 755 -D scripts/* -t "${A2P_HOME}/bin"
   ln -s "${A2P_HOME}/bin/A2PSourceProcess.sh" "${A2P_HOME}/bin/A2PSourceProcessPre"
   ln -s "${A2P_HOME}/bin/A2PSourceProcess.sh" "${A2P_HOME}/bin/A2PSourceProcessDetect"
   ln -s "${A2P_HOME}/bin/A2PSourceProcess.sh" "${A2P_HOME}/bin/A2PSourceProcessSilence"
   ln -s "${A2P_HOME}/bin/A2PSourceProcess.sh" "${A2P_HOME}/bin/A2PSourceProcessStop"
   ln -s "${A2P_HOME}/bin/A2PToggle.sh" "${A2P_HOME}/bin/A2PToggle"
   ```

   To configure autmatic output selection on sound detect please refer to [scripts/A2POutputselector.py](#scriptsa2poutputselectorpy) section.
3. Create per device systemd service file starting from template. More details in [configuration](#configuration) section
   ```sh
   export A2P_HOME=/home/user
   export A2P_DEVNAME=Test_Device
   cp "service/cpiped_Template.service" "service/cpiped_${A2P_DEVNAME}.service"
   nano "service/cpiped_${A2P_DEVNAME}.service"
   ```
4. Install and activate the service
   ```sh
   export A2P_HOME=/home/user
   export A2P_DEVNAME=Test_Device
   sudo cp "service/cpiped_${A2P_DEVNAME}.service" "/lib/systemd/system/"
   sudo systemctl daemon-reload
   sudo systemctl enable cpiped_${A2P_DEVNAME}.service
   sudo systemctl start cpiped_${A2P_DEVNAME}
   ```

## Usage

`audio2pipe` scripts functionality description

### scripts/A2PSourceProcess.sh

Main bash script taking various ENV variable as [configuration](#configuration) to make, monitor and clean-up audio pipes, pid monitoring and output selection via callback function.

Script has three execution phases from now on <A2P_ExecPhase>
- **Pre:** running all the preparatory check before `cpiped` is started. Executed only once at service start
- **Detect:** Section run at sound detect. It runs python output selector callback script. Script can be replaced at user discretion by replacing the symlinked script
- **Silence:** Performs all the files clean-up when audio source is stopped

Lockfile and pipe filling PID checks prevent parallel command execution and multiple pipe fillings resulting in unpleasant white noise blasting from speakers. These features are especially useful when audio is sourced from record players.

On **sound detect** a python callback script is used, in the repository an OwnTone output selection script is provided.

### scripts/A2POutputselector.py

Python script using [OwnTone http API(s)](https://owntone.github.io/owntone-server/json-api/) to select the output(s) defined in ENV variable at *sound detect* phase. It's usage is not mandatory

To be invoked script must be located in `<A2P_HOME>/bin` and named `A2P_OT_OUT_SEL_<A2P_DEVNAME>`
```sh
export A2P_HOME=/home/user
export A2P_DEVNAME=Test_Device
ln -s "${A2P_HOME}/bin/A2POutputSelector.py" "${A2P_HOME}/bin/A2P_OT_OUT_SEL_${A2P_DEVNAME}"
```

### scripts/A2PToggle.sh

Script to toggle the various cpiped services. Must be run as `sudo`

### service/cpiped_Template.service

Systemd service 

### Configuration

Script configuration are mainly managed though ENV variables

<table>
  <tr>
    <th>Variable<br>name</th>
    <th>Description</th>
    <th>Type</th>
    <th>Default</th>
    <th>Range/Format</th>
    <th>Required?</th>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_HOME</code></td>
    <!-- Description -->
    <td>audio2pipe basedir<br><br>
      Folder structure:
      <ul>
        <li><i>bin</i>: contains all the scripts</li>
        <li><i>var/pipes</i>: contains all the detect pipes needed by <code>cpiped</code></li>
        <li><i>var/run</i>: contains pid files and lockfiles for <code>audio2pipe</code> and <code>cpiped</code></li>
      </ul>
    </td>
    <!-- Type -->
    <td><code>string</code></td>
    <!-- Type -->
    <td><code>$HOME</code></td>
    <!-- Range/Format -->
    <td></td>
    <!-- Required? -->
    <td>No</td>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_DEVNAME</code></td>
    <!-- Description -->
    <td>Device input name<br><br>
      Mnemonic that will define all the specialized file name
      <ul>
        <li>Audio pipe: <i>&lt;A2P_OT_LIB&gt;/&lt;A2P_DEVNAME&gt;</i></li>
        <li>Audio pipe filling PID file: <i>var/run/A2P_&lt;A2P_DEVNAME&gt;.pid</i></li>
        <li><code>cpiped</code> PID file: <i>var/run/A2P_&lt;A2P_DEVNAME&gt;.pid</i></li>
        <li>Detect pipe: <i>var/pipes/A2P_&lt;A2P_DEVNAME&gt;.detectpipe</i></li>
        <li>Lockfile file: <i>var/run/A2P_&lt;A2P_DEVNAME&gt;.lock.&lt;A2P_ExecPhase&gt;</i></li>
        <li>systemd service file: <i>cpiped_&lt;A2P_DEVNAME&gt;.service</i></li>
      </ul>
    </td>
    <!-- Type -->
    <td><code>string</code></td>
    <!-- Type -->
    <td></td>
    <!-- Range/Format -->
    <td></td>
    <!-- Required? -->
    <td>Yes</td>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_CP_SF</code></td>
    <!-- Description -->
    <td>Audio device sample rate to be passed to <code>cpiped</code> in <i>hz</i><br><br>
    <code>cpiped</code> will then set env variables <i>CPIPED_SR</i>, <i>CPIPED_SS</i>, <i>CPIPED_CC</i>, respectively for sample rate, sample size and capture channel directly
  </td>
    <!-- Type -->
    <td><code>integer</code></td>
    <!-- Default -->
    <td><code>44100</code></td>
    <!-- Range/Format -->
    <td><code>16000 - 192000</code></td>
    <!-- Required? -->
    <td>No</td>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_CP_SOUNDCARD</code></td>
    <!-- Description -->
    <td>Audio capture soundcard to be passed to <code>cpiped</code> in ALSA format</td>
    <!-- Type -->
    <td><code>string</code></td>
    <!-- Default -->
    <td><code>'default'</code></td>
    <!-- Range/Format -->
    <td><code>hw:&lt;card&gt;,&lt;device&gt;</code></td>
    <!-- Required? -->
    <td>No</td>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_CP_SL</code></td>
    <!-- Description -->
    <td><code>cpiped</code> silence level</td>
    <!-- Type -->
    <td><code>integer</code></td>
    <!-- Default -->
    <td><code>100</code></td>
    <!-- Range/Format -->
    <td><code>1 - 32767</code></td>
    <!-- Required? -->
    <td>No</td>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_OT_LIB</code></td>
    <!-- Description -->
    <td>OwnTone library folder. Where the audio pipe will be created and filled on sound detection</td>
    <!-- Type -->
    <td><code>string</code></td>
    <!-- Default -->
    <td></td>
    <!-- Range/Format -->
    <td></td>
    <!-- Required? -->
    <td>No</td>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_OT_HOST</code></td>
    <!-- Description -->
    <td>OwnTone server hostname</td>
    <!-- Type -->
    <td><code>string</code></td>
    <!-- Default -->
    <td><code>localhost</code></td>
    <!-- Range/Format -->
    <td></td>
    <!-- Required? -->
    <td>No</td>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_OT_OUT_LIST</code></td>
    <!-- Description -->
    <td>OwnTone output(s) label to be selected at sound detect</td>
    <!-- Type -->
    <td><code>string</code><br><code>comma separated list</code></td>
    <!-- Default -->
    <td></td>
    <!-- Range/Format -->
    <td></td>
    <!-- Required? -->
    <td>No</td>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_DEBUG</code></td>
    <!-- Description -->
    <td>Make log more verbose. Accepts True or False values</td>
    <!-- Type -->
    <td><code>string</code></td>
    <!-- Default -->
    <td><code>False</code></td>
    <!-- Range/Format -->
    <td><code>True - False</code></td>
    <!-- Required? -->
    <td>No</td>
  </tr>
</table>

Usage of following variable is **not recommended**

<table>
  <tr>
    <th>Variable<br>name</th>
    <th>Description</th>
    <th>Type</th>
    <th>Default</th>
    <th>Range/Format</th>
    <th>Required?</th>
  </tr>
  <tr>
    <!-- Var name -->
    <td><code>A2P_DEVFORMAT</code></td>
    <!-- Description -->
    <td>
      Concatenation of sample format and sample frequency separated by two underscores<br> 
      Example: sample format 16bit Little Endian and sample frequency 48kHz will be S16_LE__48000<br> 
      Default sample rate <i>41000Hz</i><br>
      Default sample size <i>16bit</i><br>
      Default capture channel <i>2</i><br>
      **Preferred** approach is to read <code>cpiped</code> env variables <i>CPIPED_SR</i>, <i>CPIPED_SS</i>, <i>CPIPED_CC</i>, respectively for sample rate, sample size and capture channel directly
    </td>
    <!-- Type -->
    <td><code>string</code></td>
    <!-- Default -->
    <td></td>
    <!-- Range/Format -->
    <td><code>&lt;Sample format&gt;__&lt;Sample rate&gt;</code></td>
    <!-- Required? -->
    <td>Not recomended</td>
  </tr>
</table>

## ToDo(s)

- [ ] Sysvinit scripts
- [ ] Move ENV variable setup from Service file to EnvironFile to define monitoring pipe in pre stage. Under evaluation
- [ ] Rework detect pipe section that is prone to config error
- [ ] Create install script
- [ ] Add command line parameters to scripts/A2POutputselector.py
- [ ] Add command line parameters to scripts/A2PToggle.sh
- [x] Change detect pipe extension from .pipe to .detectpipe
- [ ] Add cpiped existence check in <A2P_ExecPhase>==Pre
- [x] Improve systemd service ExecStop section of script to stop the device specific instance of cpiped and not all of them
- [x] Fix systemd service KillMode warning

See the [open issues](https://github.com/ale275/audio2pipe/issues) for a full list of proposed features (and known issues).

## Acknowledgments

Based on [Making an Analog In to Airplay RPi-Transmitter](https://github.com/owntone/owntone-server/wiki/Making-an-Analog-In-to-Airplay-RPi-Transmitter) from ownTone wiki

Created to be used with [OwnTone](https://owntone.github.io/owntone-server/)

### Top contributors:

<a href="https://github.com/ale275/audio2pipe/graphs/contributors">
  <img src="https://contrib.rocks/image?repo=ale275/audio2pipe" alt="contrib.rocks image" />
</a>

<!-- variables -->
[build-shield]: https://github.com/ale275/audio2pipe/actions/workflows/audio2pipe-build.yml/badge.svg
[commit-shield]: https://img.shields.io/github/commit-activity/t/ale275/audio2pipe?style=flat
[release-shield]: https://img.shields.io/github/release/ale275/audio2pipe.svg?colorB=58839b
[release-url]: https://github.com/ale275/audio2pipe/releases/latest
[contributors-shield]: https://img.shields.io/github/contributors/ale275/audio2pipe.svg
[contributors-url]: https://github.com/ale275/audio2pipe/graphs/contributors
[forks-shield]: https://img.shields.io/github/forks/ale275/audio2pipe.svg?style=flat
[forks-url]: https://github.com/ale275/audio2pipe/network/members
[stars-shield]: https://img.shields.io/github/stars/ale275/audio2pipe.svg?style=flat
[stars-url]: https://github.com/ale275/audio2pipe/stargazers
[issues-shield]: https://img.shields.io/github/issues/ale275/audio2pipe.svg
[issues-url]: https://github.com/ale275/audio2pipe/issues
[license-shield]: https://img.shields.io/github/license/ale275/audio2pipe.svg
[license-url]: https://github.com/ale275/audio2pipe/blob/master/LICENSE
[bash-shield]: https://img.shields.io/badge/bash-1f425f?style=flat&logo=gnubash
[python-shield]: https://img.shields.io/badge/python-1f425f?style=flat&logo=python