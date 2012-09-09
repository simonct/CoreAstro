CoreAstro
=========

CoreAstro - a framework for building astronomical device drivers in Objective-C

Why ?
-----

It seems that anyone who wants to write software on the Mac (or iOS device) that deals with the various types of device common in amateur astronomy ends up having to re-invent the wheel over and over again, writing and supporting their own drivers for each of the cameras, mounts, filter-wheels, etc that they want to handle. This takes a serious amount of time and effort that could be better spent developing distinctive and useful features.

This problem was solved years ago on Windows by the [ASCOM](http://www.ascom-standards.org/) project which provides a standard framework which devices vendors can write their drivers against and application writes can use to access hardware. CoreAstro is my attempt to build the same kind of framework for Objective-C.

ASCOM is huge and there's no likelihood of CoreAstro matching it for capabilities any time soon but you have to start somewhere !

Design Goals
------------

This is an initial list of design goals. Not all of these exist in the code but in most cases a start has been made.

* Provide a simple, generic framework that dynamically loads either built-in or vendor-supplied driver bundles
* Ease of integration into client apps, rich built-in capabilities to make writing new drivers quick and simple
* Transport independence e.g. client apps should be able to access devices over the network as easily as if they were attached locally
* Support for plugin types other than hardware devices e.g. auto-guiding, focussing and image processing algorithms
* Support automation technologies such as AppleScript and Automator
* Provide a web-based system for updating plugins
* Open source, permissive licence

What's in the package
---------------------

CoreAstro is made up of two components; a framework and an app. The CoreAstro framework is really where the bulk of the code lives, the app is a simple image acquisition program that is both useful in it's own right and acts as a development harness for the framework. There's also quite a bit of code that will move from the app to the framework as the various divisions of responsibilities are worked out.

The app is really designed to be as simple to use as possible. The general idea is to provide an incredibly simple, integrated acquisition system that works out of the box and lets the new camera owner get out there and start taking great pictures almost straight away.

The app and framework run on Mac OS X 10.7 Lion and higher

Supported Devices
-----------------

CoreAstro currently supports [SX](http://sxccd.com) cameras. This is entirely down to Terry and Michael's generous technical support - thank you both ! __Please note that this project is in no way affiliated with SX Imaging. Any bugs or problems are entirely down to me, don't go calling them and complaining !__

__Also, this is very beta software. There are known bugs and deficiencies. You are welcome to download and use it but you do so entirely at your own risk. If it manages to reformat your hard-drive, blow up your camera and lose you your job then sadly that's your problem :)__ There's also no guarantees for backwards compatibility with future versions of the app and framework either in terms of source code or file formats.

Why CoreAstro ?
---------------

Apple uses Core as a prefix for many of their fundamental technology frameworks e.g. CoreFoundation, CoreGraphics, CoreData. Seemed to make sense.