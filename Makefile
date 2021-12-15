.PHONY: appledoc
appledoc:
	mkdir -p docs && appledoc --create-html --no-create-docset --no-install-docset --no-publish-docset --project-name WonderPush --project-company WonderPush --company-id com.wonderpush --explicit-crossref --index-desc ./index.markdown --keep-intermediate-files --output ./docs Sources/WonderPush/WonderPush.h Sources/WonderPushExtension/WPNotificationServiceExtension.h
