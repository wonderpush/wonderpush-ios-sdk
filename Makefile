.PHONY: appledoc
appledoc:
	mkdir -p docs && appledoc --project-name WonderPush --project-company WonderPush --company-id com.wonderpush --explicit-crossref --index-desc ./index.markdown --keep-intermediate-files --output ./docs WonderPush/WonderPush_public.h
