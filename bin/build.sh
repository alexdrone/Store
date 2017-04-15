#!/bin/bash

cd bin
cd ..
rm -rf .build_temp
mkdir .build_temp
cd .build_temp
echo "github \"alexdrone/Dispatch\" \"master\"" >> Cartfile
carthage update
mv Carthage/Build/iOS/Dispatcher_iOS.framework ../bin/Dispatcher_iOS.framework
mv Carthage/Build/iOS/Dispatcher_iOS.framework.dSYM ../bin/Dispatcher_iOS.dSYM
mv Carthage/Build/Mac/Dispatcher_macOS.framework ../bin/Dispatcher_macOS.framework
mv Carthage/Build/Mac/Dispatcher_macOS.framework.dSYM ../bin/Dispatcher_macOS.dSYM
cd ..
rm -rf .build_temp
cd bin
