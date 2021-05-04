#!/bin/sh
echo Cleaning Build/ && rm -rf Build;

for framework in WonderPush WonderPushExtension; do
  for sdk in iphoneos iphonesimulator; do
    /usr/bin/xcodebuild -scheme $framework archive -archivePath Build/$framework-$sdk.xcarchive -sdk $sdk SKIP_INSTALL=NO;
    if [ "$?" != "0" ]; then
      exit 1
    fi
  done
  xcodebuild -create-xcframework -framework Build/$framework-iphoneos.xcarchive/Products/Library/Frameworks/$framework.framework -framework Build/$framework-iphonesimulator.xcarchive/Products/Library/Frameworks/$framework.framework -output Build/$framework.xcframework
  if [ "$?" != "0" ]; then
    exit 1
  fi
done

echo Generate Build/Binaries.zip && \
cd Build && \
zip -r Binaries.zip *.xcframework >/dev/null;
