.PHONY: appledoc
appledoc:
	mkdir -p docs && appledoc --no-install-docset --project-name WonderPush --project-company WonderPush --company-id com.wonderpush --explicit-crossref --index-desc ./index.markdown --keep-intermediate-files --output ./docs WonderPush/WonderPush.h WonderPushExtension/NotificationServiceExtension.h
