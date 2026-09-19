# TapVault reader and writer build

Source for the personal iPhone NFC utility, version 1.3.0 (7).
Detects compatible MIFARE and ISO 15693 tags before attempting NDEF.
Includes read-only Ultralight EV1 product identification and encrypted local storage.
Includes a multi-record NDEF composer for text, URLs, contacts, phone, email,
SMS, map links, application links, JSON and MIME binary payloads.
Writing checks capacity and verifies the result by reading the tag back.
Does not emulate access credentials. Hardware behavior must be tested on an iPhone.

The workflow builds and tests an unsigned application on a standard macOS runner.
Signing keys, provisioning profiles and user card data are not included.
The app is signed locally after downloading the build output.
