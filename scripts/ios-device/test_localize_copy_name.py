import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location(
    "localize_copy_name", Path(__file__).with_name("localize_copy_name.py"))
localize = importlib.util.module_from_spec(spec)
spec.loader.exec_module(localize)


class LocalizedCopyName(unittest.TestCase):
    def setUp(self):
        self.folder = tempfile.TemporaryDirectory()
        self.addCleanup(self.folder.cleanup)
        self.root = Path(self.folder.name)
        self.source = self.root / "source"
        self.app = self.root / "App.app"
        self.name = "看房搭子开发版 R001"
        self.originals = {}
        for locale in ("en", "zh-Hans"):
            relative = Path(f"{locale}.lproj/InfoPlist.strings")
            # Use the real generated permission translations, including future keys.
            values = localize.read_strings(localize.SOURCE_RESOURCES / relative)
            self.assertTrue(values["CFBundleDisplayName"])
            self.originals[relative] = values
            for root in (self.source, self.app):
                path = root / relative
                path.parent.mkdir(parents=True)
                path.write_bytes(plistlib.dumps(values, fmt=plistlib.FMT_BINARY))

    def test_copy_name_preserves_all_localized_permission_values(self):
        localize.update_display_name(self.app, self.name)
        localize.verify_localizations(self.app, self.name, self.source)
        for relative, original in self.originals.items():
            actual = localize.read_strings(self.app / relative)
            self.assertEqual(actual.pop("CFBundleDisplayName"), self.name)
            self.assertEqual(actual, {k: v for k, v in original.items()
                                      if k != "CFBundleDisplayName"})
            self.assertEqual(localize.read_strings(self.source / relative), original)

    def test_normal_build_keeps_localized_branding_and_bytes(self):
        before = {relative: (self.app / relative).read_bytes() for relative in self.originals}
        localize.update_display_name(self.app, "")
        self.assertEqual(before, {p: (self.app / p).read_bytes() for p in before})

    def test_missing_localization_is_rejected(self):
        localize.update_display_name(self.app, self.name)
        (self.app / "en.lproj/InfoPlist.strings").unlink()
        with self.assertRaisesRegex(RuntimeError, "localization missing"):
            localize.verify_localizations(self.app, self.name, self.source)

    def test_reused_build_restores_normal_localized_names(self):
        localize.update_display_name(self.app, self.name)
        localize.update_display_name(self.app, "", self.source)
        for relative, original in self.originals.items():
            self.assertEqual(localize.read_strings(self.app / relative), original)

    def test_changed_permission_or_wrong_copy_name_is_rejected(self):
        localize.update_display_name(self.app, self.name)
        path = self.app / "en.lproj/InfoPlist.strings"
        expected = localize.read_strings(path)
        for key, value in (("NSCameraUsageDescription", "错误的中文说明"),
                           ("CFBundleDisplayName", "看房搭子开发版 R002")):
            with self.subTest(key=key):
                path.write_bytes(plistlib.dumps({**expected, key: value}))
                with self.assertRaisesRegex(RuntimeError, "text mismatch"):
                    localize.verify_localizations(self.app, self.name, self.source)

    def test_cannot_rename_app_without_localization_resources(self):
        with self.assertRaisesRegex(RuntimeError, "localizations are missing"):
            localize.update_display_name(self.root / "empty.app", self.name)


if __name__ == "__main__":
    unittest.main()
