import importlib.util
import plistlib
import tempfile
import unittest
from pathlib import Path

spec = importlib.util.spec_from_file_location('social_config', Path(__file__).with_name('configure_social_auth.py'))
config = importlib.util.module_from_spec(spec)
spec.loader.exec_module(config)


class ConfigTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        config.ROOT = Path(self.temp.name)
        config.IOS = config.ROOT / 'ios' / 'Runner'
        config.IOS.mkdir(parents=True)
        self.write('Info.plist', {'CFBundleURLTypes': [{'CFBundleURLSchemes': ['existing.callback']}], 'NSCameraUsageDescription': 'Camera'})

    def write(self, filename, value):
        (config.IOS / filename).write_bytes(plistlib.dumps(value))

    def test_google_missing_ids_does_not_modify_info(self):
        self.write('GoogleService-Info.plist', {'BUNDLE_ID': 'com.muratovaslan.hairApp'})
        before = (config.IOS / 'Info.plist').read_bytes()
        with self.assertRaises(ValueError):
            config.configure_google()
        self.assertEqual(before, (config.IOS / 'Info.plist').read_bytes())

    def test_google_configuration_preserves_other_schemes_and_is_idempotent(self):
        self.write('GoogleService-Info.plist', {
            'BUNDLE_ID': 'com.muratovaslan.hairApp',
            'CLIENT_ID': 'test.apps.googleusercontent.com',
            'REVERSED_CLIENT_ID': 'com.googleusercontent.apps.test',
        })
        config.configure_google()
        before = (config.IOS / 'Info.plist').read_bytes()
        config.configure_google()
        self.assertEqual(before, (config.IOS / 'Info.plist').read_bytes())
        info = config.read_plist(config.IOS / 'Info.plist')
        self.assertEqual(info['GIDClientID'], 'test.apps.googleusercontent.com')
        self.assertEqual(info['NSCameraUsageDescription'], 'Camera')
        self.assertEqual(len(info['CFBundleURLTypes']), 2)
        self.assertEqual(info['CFBundleURLTypes'][0]['CFBundleURLSchemes'], ['existing.callback'])



if __name__ == '__main__':
    unittest.main()
