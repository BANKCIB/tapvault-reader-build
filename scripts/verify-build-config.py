"""Verify privacy strings, launch metadata and NFC configuration survive XcodeGen."""
from pathlib import Path
import plistlib
import sys
import zipfile
import re

root = Path(__file__).resolve().parent.parent
with (root / 'TapVault/Info.plist').open('rb') as stream:
    source_info = plistlib.load(stream)
with (root / 'TapVault/TapVault.entitlements').open('rb') as stream:
    entitlements = plistlib.load(stream)
assert entitlements.get('com.apple.developer.nfc.readersession.formats') == ['TAG'], 'Expected current TAG entitlement; NDEF is a deprecated entitlement value'

def check_metadata(info):
    for key in ['CFBundleDisplayName', 'NFCReaderUsageDescription']:
        assert isinstance(info.get(key), str) and info[key].strip(), f'Missing {key}'
    assert 'NSFaceIDUsageDescription' not in info, 'App authentication has been removed'
    assert 'UILaunchScreen' in info, 'Missing launch configuration causes legacy screen sizing'
    assert info['CFBundleDisplayName'] == 'قُرب', 'Display name was lost'
    assert 'ar' in info['CFBundleLocalizations'], 'Arabic localization missing'
    assert info['UTExportedTypeDeclarations'][0]['UTTypeIdentifier'] == 'com.m7madv.tapvault.backup', 'Encrypted backup type missing'
    assert info['UIApplicationSceneManifest']['UIApplicationSupportsMultipleScenes'] is False

# Authentication must not return through a leftover view, callback or import.
for source in (root / 'TapVault').glob('*.swift'):
    swift = source.read_text('utf-8')
    for token in ['LocalAuthentication', 'LAContext', 'evaluatePolicy', 'struct LockView', 'store.lock()', 'store.unlock()', '"faceid"']:
        assert token not in swift, f'App lock remains in {source.name}: {token}'
check_metadata(source_info)
assert source_info['CFBundleShortVersionString'] == '$(MARKETING_VERSION)', 'Version must come from project settings'
assert source_info['CFBundleVersion'] == '$(CURRENT_PROJECT_VERSION)', 'Build number must come from project settings'
if len(sys.argv) > 1:
    target = Path(sys.argv[1])
    if target.suffix == '.ipa':
        with zipfile.ZipFile(target) as archive:
            assert archive.testzip() is None, 'Corrupt IPA archive'
            info = plistlib.loads(archive.read('Payload/TapVault.app/Info.plist'))
            assert 'Payload/TapVault.app/TapVault' in archive.namelist(), 'Executable missing'
    else:
        info = plistlib.loads((target / 'Info.plist').read_bytes())
        assert (target / 'TapVault').is_file(), 'Executable missing'
    check_metadata(info)
    assert info['UIDeviceFamily'] == [1], 'Expected iPhone-only target'
    assert info['CFBundleSupportedPlatforms'] == ['iPhoneOS'], 'Expected physical iPhone build'
    assert info['CFBundleIdentifier'] == 'com.m7madv.tapvault'
    assert info['MinimumOSVersion'] == '17.0'
    project = (root / 'project.yml').read_text('utf-8')
    assert info['CFBundleShortVersionString'] == re.search(r'MARKETING_VERSION: "([^"]+)"', project).group(1)
    assert info['CFBundleVersion'] == re.search(r'CURRENT_PROJECT_VERSION: "([^"]+)"', project).group(1)
print('PASS: NFC entitlement, privacy strings, Arabic name, launch configuration and backup type preserved.')
