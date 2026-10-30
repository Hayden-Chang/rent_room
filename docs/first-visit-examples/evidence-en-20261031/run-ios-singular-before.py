import subprocess,sys,os
os.environ["GIT_CONFIG_COUNT"]="1"
os.environ["GIT_CONFIG_KEY_0"]="url.https://github.com/weichsel/.insteadOf"
os.environ["GIT_CONFIG_VALUE_0"]="https://github.com/weichsel/"
command=['/Users/pc/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/bin/node', '/Volumes/mac2/projects/git_repo/run_self/Simulator Management/bin/sim-test-run.mjs', '--plan', '/private/tmp/rent-room-examples-en-20261031/ios-plan-singular-before.json', '--', '/private/tmp/rent-room-first-launch-examples-20261030/scripts/run-xcodebuild.sh', '-project', '/private/tmp/rent-room-first-launch-examples-20261030/ios/Xunju.xcodeproj', '-scheme', 'Xunju', '-destination', 'platform=iOS Simulator,id=__SIM_UDID__', '-derivedDataPath', '/Volumes/mac2/codex-builds/rent-room-examples-en-20261031-singular-before-__SIM_UDID__', '-resultBundlePath', '/private/tmp/rent-room-examples-en-20261031/ios-singular-before.xcresult', 'test', '-only-testing:XunjuTests/AppCopyTests/testEnglishIssueCountUsesSingularOnlyForOne']
if "--validate-only" in sys.argv: command.insert(2,"--validate-only")
raise SystemExit(subprocess.call(command))
