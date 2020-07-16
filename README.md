[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://en.wikipedia.org/wiki/MIT_License)

# xSDR6000
## Mac Client for the FlexRadio (TM) 6000 series software defined radios.
###      (see Evolution below for radio versions that are supported)




##         xSDR600 is starting to be useable for some even though it's far from complete.

I want to focus on "stability" for the next few releases. I need feedback from users. If you see a bug or experience a crash, please take a minute to report it to:

douglas.adams@me.com

If possible, include a copy of the log(s) found in:

~/Library/Application Support/net.k3tzr.xSDR6000/Logs/

Thank you for your help! 👍





### Built on:

*  macOS 10.15.6 Beta (19G46c)
*  Xcode 11.5 (11E608c)
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

Flex Radios can have one of four different version groups:
*  v1.x.x, the v1 API - untested at this time
*  v2.0.x thru v2.4.9, the v2 API <<-- CURRENTLY SUPPORTED
*  v2.5.1 to less than v3.0.0, the v3 API without MultiFlex <<-- CURRENTLY SUPPORTED
*  v3.0.0 thru v3.1.12, the v3 API with MultiFlex <<-- CURRENTLY SUPPORTED
*  greater than v3.1.12 - untested at this time (may work ???)


## Credits

SwiftyUserDefaults Package:

* https://github.com/sunshinejr/SwiftyUserDefaults.git

XCGLogger Package:

* https://github.com/DaveWoodCom/XCGLogger.git

xLib6000 Package:

* https://github.com/K3TZR/xLib6000.git

OpusOSX, framework built from sources at:

* https://opus-codec.org/downloads/


## 1.2.6 Release Notes

* corrected crash when opening if Side View was open on last execution
* corrected Slice / Spectrum dragging in Panadapter
* corrected issue with opening Preferences
* corrected 1 Hz rounding errors in frequency
* corrected ANF / APF in Flag->DSP tab
* corrected Audio Gain on Flag->AUD tab
* corrected missing frequency & filter values on Side View RX tab


## 1.2.5 Release Notes

* added Startup Message and "showStartupMessage" Defaults key
* updated Help
* changed Metal drawing (Panadapter & Waterfall) from "on demand" to "periodic"
* corrected timeout of side button popovers
* changed queue usage for Logging
* corrected Waterfall (no longer restarts periodically)
* minor edits, stability improvements & code cleanup


## 1.2.4 Release Notes

* corrections to Flag frequency field formatting
* added "SmartLink enabled" to Radio menu (ability to disable SmartLink)
* disable Login button on RadioPicker when SmartLink disabled
* added Alert when default radio not found
* refactored observations in Slice Flag
* corrections to filter width by mode (thanks to Mario, DL3LSM)
* corrected issue where Slice Flag moves but filter outline does not (thanks to Mario, DL3LSM)
* corrected issue where frequency changes but displayed frequency does not (thanks to Manoj, VU2CPL)
* many minor edits & code cleanup


## 1.2.3 Release Notes

* removed version warning (source of toolbar button issue)


## 1.2.2 Release Notes

* made width of parameter monitor fixed
* delayed toolbar button enabling to firstPing Response
* correction to Rf Gain values for 6400 & 6600
* corrections to meter handling (e.g. S-Meter, Power & SWR indicators)
* corrections to eliminate data races and main thread issues


## 1.2.1 Release Notes

* major refactor of RadioPicker / RadioViewController / WanManager / Auth0
* refactor of Parameter Monitor
* updated Help to include list of Unimplemented features and Known issues
* corrected crash on FlexControl enable (FlexControl not implemented)
* corrected a number of Main Thread issues
* refactored Waterfall to eliminate crash on resizing
* added Connect / Disconnect button to Toolbar
* corrected main thread issue in Slice flag
* corrected Side button action (toolbar)
* corrected Radio menu actions


## 1.2.0 Release Notes

* corrected crash on changing Pan fill level
* corrected crash on Slice mode change
* corrected s-Meter operation w/2 slices
* corrected side view of Slice when active Slice is changed
* corrected Slice lock
* corrected Profiles window
* added right-click in Radio Picker to set/reset default radio
* addded sheet to announce "waiting for default radio"
* added additional logging

* internal changes, major refactoring to simplify internal structure

Known Issues

* Application crashes (sometimes) when Waterfall resized
* Xvtr preference panel not implemented
* GPS preference panel not implemented

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




