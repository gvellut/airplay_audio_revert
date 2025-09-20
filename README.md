# Airplay!? No Way! (AudioMonitor)

*Airplay!? No Way!* is a macOS utility that monitors audio devices and can revert audio output when AirPlay devices are connected (instead of set to the Airplay device).

## Purpose

- Monitors system audio device changes.
- Automatically reverts audio output to the previous device when AirPlay connects.
- Includes a launcher and a helper for background monitoring.

## Build

To build the application, run:

```sh
make
```

**Note:** The build process uses a code signing certificate named `My Swift Dev Cert` (by default).
If you already have a code signing certificate (official Apple or self-signed), you can update the name in `app_config.env`, variable `SIGNING_CERT`.
If you do not have a signing certificate, you need to create one in your Keychain.
Follow [How to create code signing certificate in macOS](https://www.simplified.guide/macos/keychain-cert-code-signing-create) for a quick walkthrough of creating a self-signed certificate (for local use).


## Install

To install the app to your `~/Applications` folder:

```sh
make install
```

After installation, run the app once from your `Applications` folder to activate the background service. Manage in *Login Items > Allow in the Background*. The tool is called `AudioMonitor`.

## Uninstall

To remove the app and disable the helper:

```sh
make uninstall
```


## Note

Log with `console.app` or in command-line:

`log stream --debug --info --predicate "subsystem = 'com.user.audiomonitor'"`
