"""Override only the isolated app name in compiled InfoPlist localizations."""
import argparse
from pathlib import Path
import plistlib
import subprocess

SOURCE_RESOURCES = Path(__file__).resolve().parents[2] / "ios/Xunju/Resources"


def read_strings(path):
    return plistlib.loads(subprocess.check_output([
        "/usr/bin/plutil", "-convert", "xml1", "-o", "-", str(path)]))


def verify_localizations(app, display_name, source=SOURCE_RESOURCES):
    originals = list(source.glob("*.lproj/InfoPlist.strings"))
    if not originals:
        raise RuntimeError("source InfoPlist localizations are missing")
    for original in originals:
        relative = original.relative_to(source)
        localized = app / relative
        if not localized.is_file():
            raise RuntimeError(f"built InfoPlist localization missing: {relative}")
        expected = {**read_strings(original), "CFBundleDisplayName": display_name}
        if read_strings(localized) != expected:
            raise RuntimeError(f"localized app name or permission text mismatch: {relative}")


def update_display_name(app, display_name, source=SOURCE_RESOURCES):
    files = list(app.glob("*.lproj/InfoPlist.strings"))
    if not files:
        raise RuntimeError("built InfoPlist localizations are missing")
    for path in files:
        values = read_strings(path)
        name = display_name or read_strings(source / path.relative_to(app))["CFBundleDisplayName"]
        if values.get("CFBundleDisplayName") != name:
            values["CFBundleDisplayName"] = name
            path.write_bytes(plistlib.dumps(values, fmt=plistlib.FMT_BINARY))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--display-name", required=True)
    parser.add_argument("--verify", action="store_true")
    args = parser.parse_args()
    if args.verify:
        verify_localizations(args.app, args.display_name)
    else:
        update_display_name(args.app, args.display_name)


if __name__ == "__main__":
    main()
