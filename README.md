# AudioMonitor

AudioMonitor is a macOS utility that monitors audio devices and can revert audio output when AirPlay devices are connected (instead of set to the Airplay device).

## Purpose

- Monitors system audio device changes.
- Automatically reverts audio output to the previous device when AirPlay connects.
- Includes a launcher and a helper for background monitoring.

## Build

To build the application, run:

```sh
make
```

**Note:** The build process uses a code signing certificate named `My Swift Dev Cert`.  
If you do not have this certificate, you must create one in your Keychain.  
Follow [How to create code signing certificate in macOS](https://www.simplified.guide/macos/keychain-cert-code-signing-create) for a quick walkthrough.


## Install

To install the app to your `~/Applications` folder:

```sh
make install
```

After installation, run the app once from your Applications folder to activate the background service. Manage in *Login Items > Allow in the Background*

## Uninstall

To remove the app and disable the helper:

```sh
make uninstall
```
