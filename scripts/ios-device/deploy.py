#!/usr/bin/env python3
"""Build, verify, install and launch an isolated Xunju on one explicit device."""
from __future__ import annotations

import argparse
import datetime as dt
import json
from pathlib import Path
import plistlib
import re
import subprocess

CANONICAL_BUNDLE = "com.keeline.xunju.ios"
DISPLAY_NAME = "看房搭子开发版"
ROOT = Path(__file__).resolve().parents[2]


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def copy_bundle(copy_id):
    require(re.fullmatch(r"[a-z][a-z0-9]{2,31}", copy_id),
            "copy-id must be 3–32 lowercase ASCII letters/digits, starting with a letter")
    return f"{CANONICAL_BUNDLE}.dev.{copy_id}"


def capture(command, cwd=ROOT):
    return subprocess.check_output(command, cwd=cwd, stderr=subprocess.PIPE)


def source_identity(branch, head):
    actual_branch = capture(["git", "branch", "--show-current"]).decode().strip()
    actual_head = capture(["git", "rev-parse", "HEAD"]).decode().strip()
    require(actual_branch == branch and actual_branch, "source branch mismatch or detached HEAD")
    require(actual_head == head, "source SHA mismatch; pass the full expected SHA")
    require(not capture(["git", "status", "--porcelain", "--untracked-files=all"]).strip(),
            "source worktree is dirty; deployment stopped without changing files")
    return {"worktree": str(ROOT), "branch": actual_branch, "head": actual_head}


def validate_device(device, name, udid):
    require(device.get("deviceProperties", {}).get("name") == name, "device name mismatch")
    hardware = device.get("hardwareProperties", {})
    require(hardware.get("udid") == udid, "device hardware UDID mismatch")
    require(hardware.get("reality") == "physical" and hardware.get("platform") == "iOS",
            "target must be a physical iOS device")
    require(device.get("connectionProperties", {}).get("pairingState") == "paired",
            "target is not paired")
    require(device.get("deviceProperties", {}).get("developerModeStatus") == "enabled",
            "Developer Mode is not enabled")


def validate_app(info, entitlements, profile, bundle, team, udid, now=None):
    now = now or dt.datetime.now(dt.timezone.utc)
    require(info.get("CFBundleIdentifier") == bundle and bundle != CANONICAL_BUNDLE,
            "built Bundle ID is not the requested isolated identity")
    require(info.get("CFBundleDisplayName") == DISPLAY_NAME, "built display name mismatch")
    app_id = f"{team}.{bundle}"
    require(entitlements.get("application-identifier") == app_id, "signed app identifier mismatch")
    require(entitlements.get("com.apple.developer.team-identifier") == team, "signed team mismatch")
    groups = entitlements.get("keychain-access-groups", [])
    require(set(groups).issubset({app_id}), "shared Keychain access group is forbidden for this copy")
    require(not entitlements.get("com.apple.security.application-groups"),
            "shared App Group is forbidden for this copy")
    require(profile.get("TeamIdentifier") == [team], "provisioning team mismatch")
    require(profile.get("Entitlements", {}).get("application-identifier") == app_id,
            "provisioning app identifier mismatch")
    require(udid in profile.get("ProvisionedDevices", []), "target UDID is not provisioned")
    require(profile.get("Entitlements", {}).get("get-task-allow") is True,
            "expected a development provisioning profile")
    expiry = profile.get("ExpirationDate")
    require(isinstance(expiry, dt.datetime), "profile expiration missing")
    require(expiry.replace(tzinfo=dt.timezone.utc) > now, "provisioning profile expired")


class Deployment:
    def __init__(self, args):
        self.args = args
        self.bundle = copy_bundle(args.copy_id)
        self.output = Path(args.output).resolve()
        require(not self.output.is_relative_to(ROOT), "output must be outside the source worktree")
        require(re.fullmatch(r"[A-Z0-9]{10}", args.team), "invalid signing team")
        self.receipt = {
            "source": source_identity(args.branch, args.expected_head),
            "configuration": "Release", "scheme": "Xunju", "mode": "isolated",
            "copyID": args.copy_id, "bundleID": self.bundle, "displayName": DISPLAY_NAME,
            "team": args.team, "deviceID": args.device, "deviceName": args.device_name,
            "deviceUDID": args.udid, "steps": {},
        }

    def save(self):
        (self.output / "receipt.json").write_text(
            json.dumps(self.receipt, ensure_ascii=False, indent=2) + "\n")

    def run(self, step, command):
        print(f"{step}: running", flush=True)
        log = self.output / f"{step}.log"
        self.receipt["steps"][step] = {"status": "running", "log": str(log)}
        self.save()
        with log.open("wb") as handle:
            result = subprocess.run(command, cwd=ROOT, stdout=handle, stderr=subprocess.STDOUT)
        self.receipt["steps"][step]["status"] = "passed" if result.returncode == 0 else "failed"
        self.receipt["steps"][step]["exitCode"] = result.returncode
        self.save()
        require(result.returncode == 0, f"{step} failed; inspect {log}")
        print(f"{step}: passed", flush=True)

    def device_command(self, step, command):
        path = self.output / f"{step}.json"
        # launch treats every token after its bundle identifier as an App argument.
        # Keep device/options before the positional payload for every subcommand.
        self.run(step, ["/usr/bin/xcrun", "devicectl", *command[:3], "--device", self.args.device,
                        "--timeout", "60", "--json-output", str(path), *command[3:]])
        result = json.loads(path.read_text())
        require(result.get("info", {}).get("outcome") == "success", f"{step}: unsuccessful receipt")
        return result["result"]

    def execute(self):
        self.output.mkdir(parents=True, exist_ok=False)
        self.save()
        try:
            device = self.device_command("device", ["device", "info", "details"])
            validate_device(device, self.args.device_name, self.args.udid)
            self.run("build", [str(ROOT / "scripts/run-xcodebuild.sh"),
                "-project", str(ROOT / "ios/Xunju.xcodeproj"), "-scheme", "Xunju",
                "-configuration", "Release", "-destination", f"id={self.args.udid}",
                "-derivedDataPath", str(self.output / "DerivedData"),
                "-resultBundlePath", str(self.output / "build.xcresult"),
                "-allowProvisioningUpdates", "-allowProvisioningDeviceRegistration",
                f"DEVELOPMENT_TEAM={self.args.team}", "CODE_SIGN_STYLE=Automatic",
                "CODE_SIGN_IDENTITY=Apple Development", f"PRODUCT_BUNDLE_IDENTIFIER={self.bundle}",
                f"INFOPLIST_KEY_CFBundleDisplayName={DISPLAY_NAME}", "build"])
            source_identity(self.args.branch, self.args.expected_head)
            app = self.output / "DerivedData/Build/Products/Release-iphoneos/Xunju.app"
            self.run("signature", ["/usr/bin/codesign", "--verify", "--deep", "--strict", str(app)])
            entitlements = plistlib.loads(capture([
                "/usr/bin/codesign", "-d", "--entitlements", ":-", str(app)]))
            profile = plistlib.loads(capture([
                "/usr/bin/security", "cms", "-D", "-i", str(app / "embedded.mobileprovision")]))
            with (app / "Info.plist").open("rb") as handle:
                info = plistlib.load(handle)
            validate_app(info, entitlements, profile, self.bundle, self.args.team, self.args.udid)
            self.receipt["app"] = str(app)
            self.receipt["profileExpiration"] = profile["ExpirationDate"].isoformat() + "Z"
            self.receipt["identityVerified"] = True
            self.save()
            # Recheck the actual target immediately before any device mutation.
            device = self.device_command("device-before-install", ["device", "info", "details"])
            validate_device(device, self.args.device_name, self.args.udid)
            self.device_command("install", ["device", "install", "app", str(app)])
            installed = self.device_command("installed-app", [
                "device", "info", "apps", "--bundle-id", self.bundle])
            require(any(x.get("bundleIdentifier") == self.bundle for x in installed.get("apps", [])),
                    "installed app readback did not find the isolated Bundle ID")
            launch = self.device_command("launch", ["device", "process", "launch", self.bundle])
            require(launch.get("process", {}).get("processIdentifier", 0) > 0,
                    "launch receipt did not return a process ID")
            self.receipt["processID"] = launch["process"]["processIdentifier"]
            self.receipt["status"] = "launched"
            self.save()
            print(f"Deployment launched: {DISPLAY_NAME} ({self.bundle})", flush=True)
        except Exception as error:
            self.receipt["status"] = "failed"
            self.receipt["error"] = str(error)
            self.save()
            raise


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    for flag in ("copy-id", "team", "device", "device-name", "udid", "branch", "expected-head", "output"):
        parser.add_argument(f"--{flag}", required=True)
    args = parser.parse_args()
    try:
        Deployment(args).execute()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        parser.exit(1, f"Deployment stopped: {error}\n")


if __name__ == "__main__":
    main()
