#!/bin/sh
echo Cleaning Build/ && \
rm -rf Build && \
echo Generate Build/WonderPush.framework && \
/usr/bin/xcodebuild -scheme WonderPush archive >/dev/null && \
echo Generate Build/WonderPushExtension.framework && \
/usr/bin/xcodebuild -scheme WonderPushExtension archive >/dev/null && \
echo Generate Build/Binaries.zip && \
cd Build && \
zip -r Binaries.zip WonderPush* >/dev/null;
