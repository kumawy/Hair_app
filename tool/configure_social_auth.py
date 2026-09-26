#!/usr/bin/env python3
"""Apply public OAuth configuration after Firebase console setup.

Default: read-only check. No private keys or client secrets are needed here.
"""
import argparse
import json
import plistlib
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
IOS = ROOT / 'ios' / 'Runner'


def read_plist(path):
    return plistlib.loads(path.read_bytes())


def configure_google():
    config = read_plist(IOS / 'GoogleService-Info.plist')
    client = config.get('CLIENT_ID', '')
    scheme = config.get('REVERSED_CLIENT_ID', '')
    if not client or scheme != '.'.join(reversed(client.split('.'))):
        raise ValueError('Enable Google in Firebase and download a new iOS GoogleService-Info.plist containing CLIENT_ID and REVERSED_CLIENT_ID.')
    if config.get('BUNDLE_ID') != 'com.muratovaslan.hairApp':
        raise ValueError('The iOS config belongs to a different bundle ID.')
    info_path = IOS / 'Info.plist'
    info = read_plist(info_path)
    old_client = info.get('GIDClientID', '')
    old_scheme = '.'.join(reversed(old_client.split('.'))) if old_client else ''
    url_types = info.get('CFBundleURLTypes', [])
    # Replace only this app's prior Google callback; retain unrelated schemes.
    for url_type in url_types:
        url_type['CFBundleURLSchemes'] = [s for s in url_type.get('CFBundleURLSchemes', []) if s != old_scheme]
    url_types = [t for t in url_types if t.get('CFBundleURLSchemes')]
    if not any(scheme in t['CFBundleURLSchemes'] for t in url_types):
        url_types.append({'CFBundleTypeRole': 'Editor', 'CFBundleURLSchemes': [scheme]})
    info['CFBundleURLTypes'] = url_types
    info['GIDClientID'] = client
    info_path.write_bytes(plistlib.dumps(info, sort_keys=False))
    print('iOS Google client ID and callback configured. Rebuild the app.')


def check():
    config = read_plist(IOS / 'GoogleService-Info.plist')
    info = read_plist(IOS / 'Info.plist')
    client = config.get('CLIENT_ID')
    schemes = [s for t in info.get('CFBundleURLTypes', []) for s in t.get('CFBundleURLSchemes', [])]
    ios_ready = bool(client and info.get('GIDClientID') == client and config.get('REVERSED_CLIENT_ID') in schemes)
    android = json.loads((ROOT / 'android/app/google-services.json').read_text())
    clients = [c for c in android['client'] if c['client_info']['android_client_info']['package_name'] == 'com.example.hair_app']
    android_ready = any(o.get('client_type') == 3 for c in clients for o in c.get('oauth_client', []))
    for name, ready in [('iOS Google', ios_ready), ('Android Google web OAuth client', android_ready)]:
        print(f'{name}: {"configured locally" if ready else "not configured"}')
    print('This check cannot verify Firebase provider enablement or Android signing fingerprints.')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--google', action='store_true', help='Copy public IDs from the downloaded iOS Firebase plist')
    args = parser.parse_args()
    try:
        if args.google:
            configure_google()
    except ValueError as error:
        parser.exit(1, str(error) + '\n')
    check()


if __name__ == '__main__':
    main()
