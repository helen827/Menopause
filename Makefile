.PHONY: test test-backend test-frontend test-ios

test: test-backend test-frontend test-ios

test-backend:
	cd backend && python3 -m pytest

test-frontend:
	cd ui-prototype && npm test && npm run build

test-ios:
	xcodebuild test \
		-project ios/menocalmxia/menocalmxia.xcodeproj \
		-scheme menocalmxia \
		-destination 'platform=iOS Simulator,name=iPhone 17,OS=latest' \
		-only-testing:menocalmxiaTests \
		CODE_SIGNING_ALLOWED=NO
