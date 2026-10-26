# Sony BRAVIA Cinema — iPhone deployment

This branch is a **newly prepared, conservative build** for Sony Android TV 8.0 (API 26) on firmware 6.827. It is NOT the same unuploaded files produced in the earlier Claude Code session. It uses the upstream CleanYourTV Android launcher, a Cinema configuration, the original Cinema wallpaper from the user's LG fork, and a reversible ADB helper.

**Do not flash or root the TV.** The retail model in Settings is shown only as "BRAVIA 4K 2015". The XBR-55X850D example is a close firmware match, not proof of that exact model.

## Files in the GitHub release

Release: https://github.com/Cryptic-Tiger/cleanyourtv/releases/tag/sony-cinema

- SonyCinema.apk — Android application ID com.gathin.tvhome, Android 8.0 (API 26) or newer.
- sony-cinema-kit.zip — the APK, cyt.sh, config.json, wallpaper.jpg and this guide.
- .sha256 files — download integrity checks.

**Signing limitation:** unless a persistent signing key is configured, the upstream release build uses the runner's Android debug key. Different GitHub build runs may have different keys. Save this build; a later differently signed APK may require uninstalling the old launcher and reinstalling, which could reset launcher data. Never uninstall a working launcher while it is the only enabled Home.

## On the iPhone and Sony TV

1. Connect the TV and iPhone to the same private Wi-Fi. In Sony Settings > About, press Build repeatedly to enable Developer options, then enable ADB debugging temporarily. Find the TV IP under Settings > Network.
2. In atvTools, connect to the TV over ADB (commonly port 5555) and accept its on-screen authorization. If the TV refuses wireless ADB, do not brute-force it; this firmware may require a computer for initial enabling.
3. Open the GitHub release above on your iPhone. Download SonyCinema.apk and sony-cinema-kit.zip. Verify the .sha256 hashes if your phone tool supports this.
4. Use atvTools to **install the APK only**. Keep the Sony stock launcher enabled.
5. Extract the kit in Files, then use atvTools' file transfer to copy these files to the TV at /sdcard/Download/sony-cinema/: cyt.sh, config.json, wallpaper.jpg.
6. In atvTools' Shell tab, run the following **one command at a time**:

    sh /sdcard/Download/sony-cinema/cyt.sh check
    sh /sdcard/Download/sony-cinema/cyt.sh home try

7. Press the **physical Sony Home button**. If the new Cinema launcher appears, run:

    sh /sdcard/Download/sony-cinema/cyt.sh home finish
    sh /sdcard/Download/sony-cinema/cyt.sh theme

8. The theme is lightweight and uses reduced motion for older hardware. On this Android build, the TV may use the existing Sony font and its native inputs menu. No webOS-specific features from your LG are installed.
9. Only if the rear label confirms XBR-55X850D AND the TV is on Sony firmware 6.827, the documented optional bloatware set can be disabled with:

    sh /sdcard/Download/sony-cinema/cyt.sh debloat --confirmed-x850d

   If your actual retail model differs, leave this off. Do not copy another Sony's disable list by guesswork. The script excludes Sony TVX/HDMI, Play Store, streaming apps, Chromecast, Settings and Android core.
10. When finished, disable ADB debugging and revoke ADB authorizations to close plaintext port 5555.

## Read-only status / recovery

Before changes, "check" writes enabled and disabled package state, Home and animation settings to:

    /sdcard/Download/sony-cinema/backup/

Do not delete that folder. To see which Home is active:

    sh /sdcard/Download/sony-cinema/cyt.sh status

To return to the stock Home and undo packages disabled by this helper:

    sh /sdcard/Download/sony-cinema/cyt.sh restore

Restore enables the stock launcher before doing anything to Cinema. It deliberately **does not uninstall or disable Cinema**; you can remove it later only after the stock Home works.

If "home try" fails to start the app or Android refuses Home selection, stop there. If theme copying fails, leave the existing launcher alone instead of forcing writable system paths.

## Compatibility and limitations

This is for Android TV, not LG webOS. The former Sony example is at examples/sony-xbr-55x850d and was owner-tested with Android 8.0 / Sony firmware 6.827. The app's normal minSdk is 26. We preserve TVX (com.sony.dtv.tvx), the Sony HDMI input handler. This build has not been installed on your actual Sony TV.

The GitHub Actions workflow runs Python tests, launcher unit tests, Android lint, APK verification and a size gate. It downloads the wallpaper from the exact pinned GitHub commit f005dd0 in your LG fork, then checks its Git blob hash before adding it to the kit. No private TV settings, APK signing passwords or ADB keys are included in the public repository.
