import datetime as dt
import importlib.util
import json
import plistlib
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
        self.copy_id = "iosparity20261019"
        self.bundle = deploy.copy_bundle(self.copy_id)
        self.team = "N3Z6DDSQCJ"
        self.udid = "selected-device"
        self.display_name = deploy.copy_display_name(self.copy_id)
        self.info = {"CFBundleIdentifier": self.bundle, "CFBundleDisplayName": self.display_name}
        self.entitlements = {
            "application-identifier": f"{self.team}.{self.bundle}",
            "com.apple.developer.team-identifier": self.team,
        }
        self.profile = {
            "TeamIdentifier": [self.team], "ProvisionedDevices": [self.udid],
            "ExpirationDate": dt.datetime(2099, 1, 1),
            "Entitlements": {"application-identifier": self.entitlements["application-identifier"],
                             "get-task-allow": True},
        }

    def verify(self, info=None, entitlements=None, profile=None):
        deploy.validate_app(info or self.info, entitlements or self.entitlements,
                            profile or self.profile, self.bundle, self.team, self.udid,
                            self.display_name)

    def test_rejects_invalid_copy_ids(self):
        for value in ("", "../canonical", "UPPER", "main.copy", "ios\n", "中英文"):
            with self.subTest(value=value), self.assertRaises(RuntimeError):
                deploy.copy_bundle(value)

    def test_verified_isolated_app_is_accepted(self):
        self.verify()

    def test_display_name_carries_copy_id(self):
        self.assertEqual(deploy.copy_display_name("r001"), f"{deploy.DISPLAY_NAME} R001")

    def test_display_name_without_copy_id_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "display name"):
            self.verify(info={**self.info, "CFBundleDisplayName": deploy.DISPLAY_NAME})

    def test_team_wildcard_profile_is_accepted(self):
        wildcard = {**self.profile, "Entitlements": {
            **self.profile["Entitlements"], "application-identifier": f"{self.team}.*"}}
        self.verify(profile=wildcard)

    def canonical_fixture(self):
        bundle = deploy.CANONICAL_BUNDLE
        info = {"CFBundleIdentifier": bundle, "CFBundleDisplayName": "看房搭子"}
        entitlements = {**self.entitlements, "application-identifier": f"{self.team}.{bundle}"}
        profile = {**self.profile, "Entitlements": {
            **self.profile["Entitlements"], "application-identifier": entitlements["application-identifier"]}}
        return info, entitlements, profile

    def test_canonical_identity_requires_explicit_opt_in(self):
        info, entitlements, profile = self.canonical_fixture()
        args = (info, entitlements, profile, deploy.CANONICAL_BUNDLE, self.team, self.udid, "看房搭子")
        with self.assertRaisesRegex(RuntimeError, "Bundle ID"):
            deploy.validate_app(*args)
        deploy.validate_app(*args, canonical=True)

    def test_canonical_sandbox_rejects_wildcard_profile(self):
        info, entitlements, profile = self.canonical_fixture()
        profile["Entitlements"]["application-identifier"] = f"{self.team}.*"
        with self.assertRaisesRegex(RuntimeError, "provisioning app identifier"):
            deploy.validate_app(info, entitlements, profile, deploy.CANONICAL_BUNDLE,
                                self.team, self.udid, "看房搭子", canonical=True)

    def test_canonical_mode_cannot_silently_install_a_copy(self):
        with self.assertRaisesRegex(RuntimeError, "Bundle ID"):
            deploy.validate_app(self.info, self.entitlements, self.profile,
                                self.bundle, self.team, self.udid, self.display_name, canonical=True)

    def test_ambiguous_or_missing_installation_identity_is_rejected(self):
        for copy_id, canonical in (("testcopy", True), (None, False)):
            with self.subTest(copy_id=copy_id, canonical=canonical), self.assertRaisesRegex(
                    RuntimeError, "choose exactly one"):
                deploy.Deployment(SimpleNamespace(copy_id=copy_id, canonical=canonical))

    def test_canonical_deployment_uses_main_branding_and_verified_exact_identity(self):
        self.check_canonical_deployment(use_cache=False)

    def test_cached_canonical_deployment_keeps_profile_and_cache_receipt(self):
        self.check_canonical_deployment(use_cache=True)

    def check_canonical_deployment(self, use_cache):
        info, entitlements, profile = self.canonical_fixture()
        profile["UUID"] = "12345678-1234-1234-1234-123456789abc"
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}), \
                patch.object(deploy, "validate_device"), \
                patch.object(deploy, "capture", side_effect=[
                    plistlib.dumps(entitlements), plistlib.dumps(profile)]):
            args = SimpleNamespace(copy_id=None, canonical=True, team=self.team, output=f"{folder}/run",
                branch="codex/test", expected_head="sha", device="chosen-device",
                device_name="chosen phone", udid=self.udid, provisioning_profile=profile["UUID"])
            if use_cache:
                args.derived_data = f"{folder}/cache"
            execution = deploy.Deployment(args)
            commands = {}

            def fake_run(step, command):
                commands[step] = command
                if step == "build":
                    app = execution.derived_data / "Build/Products/Release-iphoneos/Xunju.app"
                    app.mkdir(parents=True)
                    (app / "Info.plist").write_bytes(plistlib.dumps(info))

            def fake_device(step, command):
                if step == "installed-app":
                    return {"apps": [{"bundleIdentifier": deploy.CANONICAL_BUNDLE}]}
                if step == "launch":
                    return {"process": {"processIdentifier": 42}}
                return {}

            with patch.object(execution, "device_command", side_effect=fake_device) as device, \
                    patch.object(execution, "run", side_effect=fake_run):
                execution.execute()
            build = commands["build"]
            self.assertEqual(build[build.index("-scheme") + 1], "Xunju")
            self.assertEqual(build[build.index("-configuration") + 1], "Release")
            expected_data = Path(folder).resolve() / ("cache" if use_cache else "run/DerivedData")
            self.assertEqual(build[build.index("-derivedDataPath") + 1], str(expected_data))
            self.assertIn("CODE_SIGN_IDENTITY=Apple Development", build)
            self.assertIn("CODE_SIGN_STYLE=Manual", build)
            self.assertIn(f"XUNJU_PROVISIONING_PROFILE={profile['UUID']}", build)
            self.assertFalse(any(arg.startswith("PROVISIONING_PROFILE_SPECIFIER=") for arg in build))
            self.assertNotIn("CODE_SIGN_STYLE=Automatic", build)
            self.assertNotIn("-allowProvisioningUpdates", build)
            self.assertNotIn("-allowProvisioningDeviceRegistration", build)
            self.assertIn(f"PRODUCT_BUNDLE_IDENTIFIER={deploy.CANONICAL_BUNDLE}", build)
            self.assertIn("XUNJU_ISOLATED_DISPLAY_NAME=", build)
            self.assertFalse(any(arg.startswith("INFOPLIST_KEY_CFBundleDisplayName=") for arg in build))
            self.assertEqual(commands["localized-resources"][-2:], ["--display-name", ""])
            self.assertEqual([call.args[0] for call in device.call_args_list],
                             ["device", "device-before-install", "install", "installed-app", "launch"])
            self.assertEqual(execution.receipt["mode"], "canonical")
            self.assertEqual(execution.receipt["provisioningProfile"], profile["UUID"])
            self.assertEqual(execution.receipt["derivedData"], str(expected_data))
            self.assertEqual(execution.receipt["derivedDataMode"], "cache" if use_cache else "per-run")
            self.assertTrue(execution.receipt["identityVerified"])
            self.assertEqual(execution.receipt["status"], "launched")

    def test_foreign_profile_app_identifier_is_rejected(self):
        with self.assertRaisesRegex(RuntimeError, "provisioning app identifier"):
            self.verify(profile={**self.profile, "Entitlements": {
                **self.profile["Entitlements"],
                "application-identifier": "OTHERTEAM0.other.app"}})

    def test_requested_profile_mismatch_stops_before_install(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}), \
                patch.object(deploy, "validate_device"), \
                patch.object(deploy, "capture", side_effect=[
                    plistlib.dumps(self.entitlements),
                    plistlib.dumps({**self.profile, "UUID": "another-profile"})]):
            args = SimpleNamespace(copy_id="testcopy", team=self.team, output=f"{folder}/run",
                branch="codex/test", expected_head="sha", device="chosen-device",
                device_name="chosen phone", udid=self.udid,
                provisioning_profile="12345678-1234-1234-1234-123456789abc")
            execution = deploy.Deployment(args)
            with patch.object(execution, "device_command", return_value={}) as device, \
                    patch.object(execution, "run"), \
                    self.assertRaisesRegex(RuntimeError, "requested UUID"):
                execution.execute()
            self.assertEqual([call.args[0] for call in device.call_args_list], ["device"])
            self.assertEqual(execution.receipt["status"], "failed")

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

    def test_missing_localized_permissions_stop_before_install(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}), \
                patch.object(deploy, "validate_device"), \
                patch.object(deploy, "validate_app"), \
                patch.object(deploy, "capture", side_effect=[
                    plistlib.dumps(self.entitlements), plistlib.dumps(self.profile)]):
            args = SimpleNamespace(copy_id="testcopy", team=self.team, output=f"{folder}/run",
                branch="codex/test", expected_head="sha", device="chosen-device",
                device_name="chosen phone", udid=self.udid)
            execution = deploy.Deployment(args)

            def fake_run(step, command):
                if step == "build":
                    self.assertIn(f"XUNJU_ISOLATED_DISPLAY_NAME={execution.display_name}", command)
                    self.assertIn("CODE_SIGN_STYLE=Automatic", command)
                    self.assertIn("-allowProvisioningUpdates", command)
                    self.assertFalse(any(arg.startswith("EXCLUDED_SOURCE_FILE_NAMES=") for arg in command))
                    app = execution.output / "DerivedData/Build/Products/Release-iphoneos/Xunju.app"
                    app.mkdir(parents=True)
                    (app / "Info.plist").write_bytes(plistlib.dumps(self.info))
                if step == "localized-resources":
                    raise RuntimeError("localized permission validation failed")

            with patch.object(execution, "device_command", return_value={}) as device, \
                    patch.object(execution, "run", side_effect=fake_run), \
                    self.assertRaisesRegex(RuntimeError, "localized permission"):
                execution.execute()
            self.assertEqual([call.args[0] for call in device.call_args_list], ["device"])
            self.assertEqual(execution.receipt["status"], "failed")

    def make_args(self, folder, **overrides):
        values = dict(copy_id="testcopy", team=self.team, output=f"{folder}/run",
            branch="codex/test", expected_head="sha", device="chosen-device",
            device_name="chosen phone", udid=self.udid)
        values.update(overrides)
        return SimpleNamespace(**values)

    def test_per_run_derived_data_stays_inside_output(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}):
            execution = deploy.Deployment(self.make_args(folder))
            self.assertEqual(execution.derived_data, Path(folder).resolve() / "run/DerivedData")
            self.assertEqual(execution.derived_data_mode, "per-run")
            self.assertEqual(execution.receipt["derivedDataMode"], "per-run")

    def test_cached_derived_data_drives_build_and_app_path(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}), \
                patch.object(deploy, "validate_device"), \
                patch.object(deploy, "validate_app"), \
                patch.object(deploy, "capture", side_effect=[
                    plistlib.dumps(self.entitlements), plistlib.dumps(self.profile)]):
            cache = Path(folder).resolve() / "cache"
            execution = deploy.Deployment(self.make_args(folder, derived_data=str(cache)))

            def fake_run(step, command):
                if step == "build":
                    self.assertEqual(command[command.index("-derivedDataPath") + 1], str(cache))
                    app = cache / "Build/Products/Release-iphoneos/Xunju.app"
                    app.mkdir(parents=True)
                    (app / "Info.plist").write_bytes(plistlib.dumps(self.info))
                if step == "localized-resources":
                    raise RuntimeError("stop after app path check")

            with patch.object(execution, "device_command", return_value={}) as device, \
                    patch.object(execution, "run", side_effect=fake_run), \
                    self.assertRaisesRegex(RuntimeError, "app path check"):
                execution.execute()
            self.assertEqual([call.args[0] for call in device.call_args_list], ["device"])
            self.assertEqual(execution.receipt["derivedData"], str(cache))
            self.assertEqual(execution.receipt["status"], "failed")

    def test_invalid_derived_data_paths_are_rejected(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}):
            for cache, message in (
                    (deploy.ROOT / "ios" / "cache", "outside the source worktree"),
                    (f"{folder}/run/cache", "inside the output directory")):
                with self.subTest(cache=cache), self.assertRaisesRegex(RuntimeError, message):
                    deploy.Deployment(self.make_args(folder, derived_data=str(cache)))
            with tempfile.NamedTemporaryFile() as handle, \
                    self.assertRaisesRegex(RuntimeError, "must be a directory"):
                deploy.Deployment(self.make_args(
                    folder, derived_data=handle.name))

    def test_derived_data_on_another_volume_is_rejected(self):
        with tempfile.TemporaryDirectory() as folder, \
                patch.object(deploy, "source_identity", return_value={"head": "sha"}), \
                patch.object(deploy, "on_boot_volume", return_value=False), \
                self.assertRaisesRegex(RuntimeError, "boot volume"):
            deploy.Deployment(self.make_args(folder, derived_data=f"{folder}/cache"))

    def test_boot_volume_probe_walks_up_from_a_missing_path(self):
        probe = Path("/private/tmp/xunju-missing-xyz/nested")
        self.assertTrue(deploy.on_boot_volume(probe))
        foreign = SimpleNamespace(stat=lambda: SimpleNamespace(st_dev=-1))
        with patch.object(deploy, "BOOT_VOLUME", foreign):
            self.assertFalse(deploy.on_boot_volume(probe))


if __name__ == "__main__":
    unittest.main()
