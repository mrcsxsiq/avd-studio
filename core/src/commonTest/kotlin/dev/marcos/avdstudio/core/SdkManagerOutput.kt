package dev.marcos.avdstudio.core

/**
 * A trimmed copy of what `sdkmanager --list` (cmdline-tools 23.0.0) prints on a Mac with a few things installed:
 * the deprecation banner, a progress bar, both sections and the " (+1)" revision markers.
 * Paths use `/`, columns are separated by runs of spaces and there is no `|`.
 */
internal val SDKMANAGER_LIST =
    """
    WARNING: The SDK Manager CLI tool (sdkmanager) is deprecated. Android CLI will be used instead.
    [=======================================] 100% Fetch remote repository...
    Installed packages:
      emulator                                                      37.2.13    Android Emulator
      platforms/android-36                                          2.0.0      Android SDK Platform 36
      system-images/android-23/default/armeabi-v7a                  6.0.0      ARM EABI v7a System Image
      system-images/android-36/google_apis_playstore/arm64-v8a      7.0.0      Google Play ARM 64 v8a System Image
    Available packages:
      add-ons/addon-google_apis-google-10                           2.0.0      Google APIs
      emulator                                                      37.2.13    Android Emulator
      platforms/android-34                                          3.0.0 (+1)  Android SDK Platform 34
      system-images/android-23/default/armeabi-v7a                  6.0.0      ARM EABI v7a System Image
      system-images/android-24/google_apis/arm64-v8a                29.0.0 (+1)  Google APIs ARM 64 v8a System Image
      system-images/android-30/android-wear/arm64-v8a               12.0.0     Wear OS 3 ARM 64 v8a System Image
      system-images/android-30/google_atd/arm64-v8a                 2.0.0      Google APIs ATD ARM 64 v8a System Image
      system-images/android-34/android-tv/arm64-v8a                 3.0.0      Android TV ARM 64 v8a System Image
      system-images/android-34/google-xr/arm64-v8a                  7.0.0      Google Play XR ARM 64 v8a System Image (Developer Preview)
      system-images/android-35/google_apis_playstore_tablet/arm64-v8a  9.0.0   Google Play Tablet ARM 64 v8a System Image
      system-images/android-36-ext18/google_apis_playstore/arm64-v8a  1.0.0    Google Play ARM 64 v8a System Image
      system-images/android-36.1/google_apis_playstore/arm64-v8a    4.0.0      Google Play ARM 64 v8a System Image
      system-images/android-36/ai-glasses/arm64-v8a                 6.0.0      Intelligent Eyewear ARM 64 v8a System Image (Developer Preview)
      system-images/android-36/default/arm64-v8a                    2.0.0      ARM 64 v8a System Image
      system-images/android-36/google-tv/arm64-v8a                  4.0.0      Google TV ARM 64 v8a System Image
      system-images/android-36/google_apis/arm64-v8a                7.0.0      Google APIs ARM 64 v8a System Image
      system-images/android-36/google_apis/x86_64                   7.0.0      Google APIs Intel x86_64 Atom System Image
      system-images/android-36/google_apis_playstore/arm64-v8a      7.0.0      Google Play ARM 64 v8a System Image
      system-images/android-36/google_apis_playstore_ps16k/arm64-v8a  7.0.0    16 KB Page Size Google Play ARM 64 v8a System Image
      system-images/android-37.0/google_apis_playstore/arm64-v8a    8.0.0      Google Play ARM 64 v8a System Image
      system-images/android-37.0/google_apis_playstore/x86_64       8.0.0      Google Play Intel x86_64 Atom System Image
      system-images/android-canary-20261007/google_apis_playstore_ps16k/arm64-v8a  17.0.0  16 KB Page Size Google Play ARM 64 v8a System Image
    """.trimIndent()

/** The same idea in the layout older sdkmanager versions print: `|` separators, `;` paths, a header and an updates section. */
internal val SDKMANAGER_LIST_OLD_FORMAT =
    """
    Installed packages:=====================] 100% Computing updates...
      Path                                         | Version | Description                              | Location
      -------                                      | ------- | -------                                  | -------
      build-tools;28.0.3                           | 28.0.3  | Android SDK Build-Tools 28.0.3           | build-tools/28.0.3
      emulator                                     | 29.4.6  | Android Emulator                         | emulator
      system-images;android-28;google_apis;x86     | 9       | Google APIs Intel x86 Atom System Image  | system-images/android-28/google_apis/x86

    Available Packages:
      Path                                         | Version | Description
      -------                                      | ------- | -------
      add-ons;addon-google_apis-google-15          | 3       | Google APIs
      system-images;android-28;google_apis;x86     | 9       | Google APIs Intel x86 Atom System Image
      system-images;android-29;google_apis_playstore;arm64-v8a | 8 | Google Play ARM 64 v8a System Image

    Available Updates:
      ID                                           | Installed | Available
      -------                                      | -------   | -------
      system-images;android-28;google_apis;x86     | 9         | 10
    """.trimIndent()
