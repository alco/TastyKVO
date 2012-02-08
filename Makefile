.PHONY: test

WORKSPACE_FILE=test/TastyKVOTest/TastyKVOTest.xcodeproj/project.xcworkspace

test:
	xcodebuild -workspace $(WORKSPACE_FILE) -scheme TastyKVOExtensionTests >test_output.txt
	xcodebuild -workspace $(WORKSPACE_FILE) -scheme TastyKVOAutoRemovalTests >>test_output.txt
