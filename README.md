# TapVault reader build

Source for the personal iPhone NFC reader, version 1.1.1 (4).
Detects compatible MIFARE and ISO 15693 tags before attempting NDEF.
Includes read-only Ultralight EV1 product identification and encrypted local storage.
Does not emulate access credentials. Hardware behavior must be tested on an iPhone.

The workflow builds and tests an unsigned application on a standard macOS runner.
Signing keys, provisioning profiles and user card data are not included.
The app is signed locally after downloading the build output.
