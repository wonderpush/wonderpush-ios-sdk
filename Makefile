.PHONY: appledoc
appledoc:
	mkdir -p docs && appledoc --create-html --no-create-docset --no-install-docset --no-publish-docset --project-name WonderPush --project-company WonderPush --company-id com.wonderpush --explicit-crossref --index-desc ./index.markdown --keep-intermediate-files --output ./docs WonderPush/Sources/WonderPush.h WonderPushExtension/Sources/WPNotificationServiceExtension.h
