CoreAstro ToDo
==============

In no particualr order...

* Replace truly awful toolbar icons
* Replace IKImageView with something slightly less broken
* CASImageProcessingChain for running filter chains asynchronously (drag and drop config UI)
* Save to FITS
* Temperature, guiding history overlays
* Hide/show options for histogram, temperature, guiding overlays
* Get camera serial number, use this to key images in the library
* Ability to customise library location
* Night mode using fade reservation
* Enhanced library UI
* Image acquisition sessions, appear as folders in library
* UI for building master darks, flats, etc
* Autoguiding, focussing modules
* Filter wheel, serial port, Star2K support
* Refactor CASCameraWindowController into a host for a set of NSViewControllers
* Debayer support for colour cameras
* Move SX-specific code out of the app delegate and camera controller
* Make CASCCDExposure support NSDiscardableContent
* CoreData-based exposures library index
* coreastrod with command line options, launchd integration watching for USB devices ?

Known bugs
----------

* Fairly regular crash in IKImageView when swapping in a new image
* Camera not always detected on insert - race condition in the USB code ?
* Numerous cosmetic bugs
* Doubtless many more...