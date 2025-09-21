# AirPlay!? No Way! (AudioMonitor)

*AirPlay!? No Way!* is a macOS utility that monitors audio devices and can revert audio output when AirPlay devices are connected (instead of set to the newly connected AirPlay device).

## Purpose

- Monitors system audio device changes.
- Automatically reverts audio output to the previous device when AirPlay connects.
- Includes a launcher and a helper for background monitoring.

## Build

Prerequisites:

- *XCode* or *XCode Command-Line Tools*. For the tools, run `xcode-select --install` in the terminal . Among other things, this will install the Swift command-line compiler. Type `swift –version` in the terminal to check if it was installed correctly. Version 5.9 of the Swift tools is currently used (but a later version should be fine).
- The build process uses a code signing certificate named `My Swift Dev Cert` (by default). If you already have a code signing certificate (official Apple or self-signed), you can update the name in `app_config.env`, variable `SIGNING_CERT`. If you do not have a signing certificate, you need to create one in your Keychain. Follow [How to create code signing certificate in macOS](https://www.simplified.guide/macos/keychain-cert-code-signing-create) for a quick walkthrough of creating a self-signed certificate (for local use).

To build the application, run:

```sh
make
```

## Install

To install the app to your `~/Applications` folder:

```sh
make install
```

After installation, run the app once from your `~/Applications` folder to activate the background service. Manage in *Login Items > Allow in the Background*. The tool will be called **AudioMonitor**.

## Uninstall

To remove the app and disable the helper:

```sh
make uninstall
```

## Note

Log with `console.app` or in command-line:

`log stream --debug --info --predicate "subsystem = 'com.user.audiomonitor'"`
