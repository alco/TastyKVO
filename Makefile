.PHONY: test

test:
	xcodebuild -project test/TastyKVOTest/TastyKVOTest.xcodeproj -alltargets >test_output.txt
