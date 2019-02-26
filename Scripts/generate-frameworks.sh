#!/bin/sh
rm -rf Build && \
/usr/bin/xcodebuild -scheme WonderPush archive && /usr/bin/xcodebuild -scheme WonderPushExtension archive && \
    cd Build && \
    zip -r Binaries.zip WonderPush*;
