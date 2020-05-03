[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://en.wikipedia.org/wiki/MIT_License)

# xSDR6000
## Mac Client for the FlexRadio (TM) 6000 series software defined radios.
###      (see Evolution below for radio versions that are supported)

### Built on:

*  macOS 10.15.4
*  Xcode 11.4.1 (11E503a)
*  Swift 5.2


## Usage

Provides functionality similar to the FlexRadio (TM) SmartSDR (TM) app.

**NOTE: This app is a "work in progress" and is not fully functional**  

Portions of this app do not work and changes may be added from time to time which will break all or part of this app.  


## Builds

Compiled RELEASE builds will be created at relatively stable points, please use them.  

If you require a DEBUG build you will have to build from sources. 


## Comments / Questions

Please send any bugs / comments / questions to douglas.adams@me.com


## Evolution

Please see ChangeLog.txt for a running list of changes.

This version currently supports Radios using the Flex v2 API. A Future version of this library will support all Radio versions.

Flex Radios can have one of four different version groups:
*  v1.x.x, the v1 API - untested at this time
*  v2.0.x thru v2.4.9, the v2 API <<-- CURRENTLY SUPPORTED
*  v2.5.1 to less than v3.0.0, the v3 API without MultiFlex <<-- CURRENTLY SUPPORTED
*  v3.0.0 thru v3.1.8, the v3 API with MultiFlex <<-- CURRENTLY SUPPORTED
*  greater than v3.1.8 - untested at this time


## Credits

SwiftyUserDefaults Package:

* https://github.com/sunshinejr/SwiftyUserDefaults.git

XCGLogger Package:

* https://github.com/DaveWoodCom/XCGLogger.git

xLib6000 Package:

* https://github.com/K3TZR/xLib6000.git

OpusOSX, framework built from sources at:

* https://opus-codec.org/downloads/


## 1.1.10 Release Notes

* corrected crash due to appFolder Logs 

## 1.1.9 Release Notes

* Corrected crash when connecting to v3.1.11 radio

## 1.1.8 Release Notes

* Location of logs changed to ~/Library/Application Support/net.k3tzr.xSDR6000/Logs
* Log Viewer added to xSDR6000 Menu
* various other corrections and stability improvements

## 1.1.7 Release Notes

* Fixed crash when selecting FM mode
* Corrected preamp slider (now different for different Flex models)
* Corrected TX profile entry on TX Preferences dialog
* various other corrections and stability improvements

## 1.1.3 Release Notes

* Removed from Sandbox
* Corrections to SmartLink log on/off
* Unified Local / SmartLink Logon
* Frequency entry now allows any Mhz value
* Profiles crash corrected
* Multiflex offers choice to force a disconnect




