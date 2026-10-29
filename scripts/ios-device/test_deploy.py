import datetime as dt
import importlib.util
import json
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

spec = importlib.util.spec_from_file_location("deploy", Path(__file__).with_name("deploy.py"))
deploy = importlib.util.module_from_spec(spec)
spec.loader.exec_module(deploy)


class DeploymentGuards(unittest.TestCase):
    def setUp(self):
        self.bundle = deploy.copy_bundle("iosparity20261019")
        self.team = "N3Z6DDSQCJ"
        self.udid = "selected-device"
        self.info = {"CFBundleIdentifier": self.bundle, "CFBundleDisplayName": deploy.DISPLAY_NAME}
        self.entitlements = {
            "application-identifier": f"{self.team}.{self.bundle}",
            "com.apple.developer.team-identifier": self.team,
            "com.apple.developer.applesignin": ["Default"],
        }
        self.profile = {
            "TeamIdentifier": [self.team], "ProvisionedDevices": [self.udid],
            "ExpirationDate": dt.datetime(2099, 1, 1),
            "Entitlements": {"application-identifier": self.entitlements["application-identifier"],
                             "get-task-allow": True},
        }

    def verify(self, info=None, entitlements=None, profile=None):
        deploy.validate_app(info or self.info, entitlements or self.entitlements,
                            profile or self.profile, self.bundle, self.team, self.udid)

    def test_rejects_invalid_copy_ids(self):
        for value in ("", "../canonical", "UPPER", "main.copy", "ios\n", "中英文"):
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                deploy.copy_bundle(value)

    def test_verified_isolated_app_is_accepted(self):
        self.verify()

    def test_canonical_app_or_other_team_cannot_be_installed(self):
        with self.assertRaisesRegex(RuntimeError, "Bundle ID"):
            self.verify(info={**self.info, "CFBundleIdentifier": deploy.CANONICAL_BUNDLE})
        with self.assertRaisesRegex(RuntimeError, "team"):
            self.verify(entitlements={**self.entitlements, "com.apple.developer.team-identifier": "OTHERTEAM0"})

    def test_shared_keychain_or_app_group_cannot_be_installed(self):
        for key, value in (("keychain-access-groups", ["shared.canonical"]),
                           ("com.apple.security.application-groups", ["group.canonical"])):
            with self.subTest(key=key), self.assertRaises(RuntimeError):
                self.verify(entitlements={**self.entitlements, key: value})

    def test_wrong_device_and_expired_profile_are_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "UDID"):
            self.verify(profile={**self.profile, "ProvisionedDevices": ["another-device"]})
        with self.assertRaisesRegex(RuntimeError, "expired"):
            self.verify(profile={**self.profile, "ExpirationDate": dt.datetime(2000, 1, 1)})
        with self.assertRaisesRegex(RuntimeError, "name"):
            deploy.validate_device({"deviceProperties": {"name": "other phone"}}, "chosen phone", self.udid)

    def test_dirty_or_changed_source_is_rejected(self):
        for outputs in ((b"other", b"sha", b""), (b"chosen", b"other-sha", b""),
                        (b"chosen", b"sha", b" M ios/source.swift")):
            with self.subTest(outputs=outputs), patch.object(deploy, "capture", side_effect=outputs), \
                    self.assertRaises(RuntimeError):
                deploy.source_identity("chosen", "sha")

    def test_failed_build_stops_before_install_or_launch(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}), \
                patch.object(deploy, "validate_device"):
            args = SimpleNamespace(copy_id="testcopy", team=self.team, output=f"{folder}/run",
                branch="codex/test", expected_head="sha", device="chosen-device",
                device_name="chosen phone", udid=self.udid)
            execution = deploy.Deployment(args)
            with patch.object(execution, "device_command", return_value={}) as device, \
                    patch.object(execution, "run", side_effect=RuntimeError("build failed")), \
                    self.assertRaisesRegex(RuntimeError, "build failed"):
                execution.execute()
            self.assertEqual([x.args[0] for x in device.call_args_list], ["device"])
            self.assertEqual(execution.receipt["status"], "failed")

    def test_launch_has_no_options_accidentally_forwarded_to_app(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}):
            args = SimpleNamespace(copy_id="testcopy", team=self.team, output=f"{folder}/run",
                branch="codex/test", expected_head="sha", device="chosen-device",
                device_name="chosen phone", udid=self.udid)
            execution = deploy.Deployment(args)
            execution.output.mkdir()

            def fake_run(step, command):
                # Model devicectl's launch parser: tokens after Bundle ID go to App.
                self.assertEqual(command[command.index(execution.bundle) + 1:], [])
                self.assertLess(command.index("--device"), command.index(execution.bundle))
                path = Path(command[command.index("--json-output") + 1])
                path.write_text(json.dumps({"info": {"outcome": "success"},
                                            "result": {"process": {"processIdentifier": 42}}}))

            with patch.object(execution, "run", side_effect=fake_run):
                result = execution.device_command("launch", ["device", "process", "launch", execution.bundle])
            self.assertEqual(result["process"]["processIdentifier"], 42)


if __name__ == "__main__":
    unittest.main()
