### xSDR6000 [![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://en.wikipedia.org/wiki/MIT_License)

#### Mac Client for the FlexRadio (TM) 6000 series software defined radios.

##### Built on:

*  macOS 11.2.1
*  Xcode 12.4 (12D4e)
*  Swift 5.3

##### Runs on:
* macOS 10.15 and higher

##### Builds
Compiled  [RELEASE builds](https://github.com/K3TZR/xSDR6000/releases) will be created at relatively stable points, please use them.  If you require a DEBUG build you will have to build from sources. 

##### Comments / Questions
Please send any bugs / comments / questions to support@k3tzr.net

##### Evolution
Flex Radios can have one of four different version groups:
*  v1.x.x, the ***v1 API*** - untested at this time
*  v2.0.x thru v2.4.9, the ***v2 API***<<-- CURRENTLY SUPPORTED
*  v2.5.1 to less than v3.0.0, the ***v3 API without MultiFlex*** <<-- CURRENTLY SUPPORTED
*  v3.0.0 thru v3.2.14, the ***v3 API with MultiFlex*** <<-- CURRENTLY SUPPORTED
*  greater than v3.2.14 - untested at this time (may work ???)

##### Credits
[xLib6000](https://github.com/K3TZR/xLib6000.git)

[SwiftyUserDefaults](https://github.com/sunshinejr/SwiftyUserDefaults.git)

[XCGLogger](https://github.com/DaveWoodCom/XCGLogger.git)

[Opus](https://opus-codec.org/downloads/)

[TPCircularBuffer](https://github.com/michaeltyson/TPCircularBuffer)


##### Other software
[![DL3LSM](https://img.shields.io/badge/DL3LSM-xDAX,_xCAT,_xKey-informational)](https://dl3lsm.blogspot.com) Mac versions of DAX and/or CAT and a Remote CW Keyer.  
[![W6OP](https://img.shields.io/badge/W6OP-xVoiceKeyer,_xCW-informational)](https://w6op.com) A Mac-based Voice Keyer and a CW Keyer.  

---
##### 1.2.12 Release Notes
* corrections to PanadapterRenderer & WaterfallRenderer to eliminate pink screen on M1 Macs

##### 1.2.11 Release Notes
* corrected action of buttons on Flag
* made panadapter and waterfall click / drag actions the same
* added incrFrequency & decrFrequency to Radio menu with key equivalents Cmd-RightArrow & Cmd-LeftArrow
* added xmit to Radio menu with key equivalent Cmd-X

##### 1.2.10 Release Notes
* corrected disconnection process 
* corrected ATU usage in TXViewController.swift
* in PanafallViewController.swift added ability to double-click waterfall to change / move slice
* in AudioViewController.swift corrected agcMode == off
* in AntennaViewController.swift made rfGain controller respond continuously
* corrected the constraints in the Rx Side view to close up when controls are closed
* major rework of all the Side controllers & their observations
* code formatting changes throughout
* changes to MacAudio operation to try to reduce occasional "buzz"

##### 1.2.9 Release Notes

* corrected constraints on the Auth0 sheet (SmartLink logon)
* changed disconnect alert to be runModal rather than beginSheetModal
* changed all email references to new email (support@k3tzr.net)


##### 1.2.8 Release Notes

* xMini enhanced to make multiple Mini's, one per Panadapter
* made xMini background opaque
* made xMIni remember window position (by band)
* changed Panadapter & Waterfall load/store actions to .clear/.dontcare
* revised BandButtons (prep for adding Xvtr bandbuttons)
* corrected an error in panadapter fill level & color


##### 1.2.7 Release Notes

* fixed crash when selecting Dax button on Panadapter left side
* added xMini and xMini entry in Radio menu


##### 1.2.6 Release Notes

* corrected crash when opening if Side View was open on last execution
* corrected Slice / Spectrum dragging in Panadapter
* corrected issue with opening Preferences
* corrected 1 Hz rounding errors in frequency
* corrected ANF / APF in Flag->DSP tab
* corrected Audio Gain on Flag->AUD tab
* corrected missing frequency & filter values on Side View RX tab


##### 1.2.5 Release Notes

* added Startup Message and "showStartupMessage" Defaults key
* updated Help
* changed Metal drawing (Panadapter & Waterfall) from "on demand" to "periodic"
* corrected timeout of side button popovers
* changed queue usage for Logging
* corrected Waterfall (no longer restarts periodically)
* minor edits, stability improvements & code cleanup


##### 1.2.4 Release Notes

* corrections to Flag frequency field formatting
* added "SmartLink enabled" to Radio menu (ability to disable SmartLink)
* disable Login button on RadioPicker when SmartLink disabled
* added Alert when default radio not found
* refactored observations in Slice Flag
* corrections to filter width by mode (thanks to Mario, DL3LSM)
* corrected issue where Slice Flag moves but filter outline does not (thanks to Mario, DL3LSM)
* corrected issue where frequency changes but displayed frequency does not (thanks to Manoj, VU2CPL)
* many minor edits & code cleanup


##### 1.2.3 Release Notes

* removed version warning (source of toolbar button issue)


##### 1.2.2 Release Notes

* made width of parameter monitor fixed
* delayed toolbar button enabling to firstPing Response
* correction to Rf Gain values for 6400 & 6600
* corrections to meter handling (e.g. S-Meter, Power & SWR indicators)
* corrections to eliminate data races and main thread issues


##### 1.2.1 Release Notes

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


##### 1.2.0 Release Notes

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


##### 1.1.10 Release Notes

* corrected crash due to appFolder Logs 

##### 1.1.9 Release Notes

* Corrected crash when connecting to v3.1.11 radio

##### 1.1.8 Release Notes

* Location of logs changed to ~/Library/Application Support/net.k3tzr.xSDR6000/Logs
* Log Viewer added to xSDR6000 Menu
* various other corrections and stability improvements

##### 1.1.7 Release Notes

* Fixed crash when selecting FM mode
* Corrected preamp slider (now different for different Flex models)
* Corrected TX profile entry on TX Preferences dialog
* various other corrections and stability improvements

##### 1.1.3 Release Notes

* Removed from Sandbox
* Corrections to SmartLink log on/off
* Unified Local / SmartLink Logon
* Frequency entry now allows any Mhz value
* Profiles crash corrected
* Multiflex offers choice to force a disconnect




