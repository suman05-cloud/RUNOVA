# Windows Android setup

The repository-local Flutter SDK is installed at `.tooling/flutter` and ignored
by Git. Flutter Doctor currently reports that the Android SDK is missing.

## Required setup

1. Install the current stable Android Studio.
2. In SDK Manager, install Android SDK Platform 36, Build Tools, Command-line
   Tools, and Platform Tools.
3. Run `.tooling\flutter\bin\flutter.bat doctor --android-licenses` and review
   and accept the Android SDK licences.
4. Run `.tooling\flutter\bin\flutter.bat doctor -v`.
5. Enable USB debugging on a physical Android phone and verify it with
   `.tooling\flutter\bin\flutter.bat devices`.

Visual Studio is not required because Runova is not targeting Windows desktop.
The Flutter and Dart PATH warnings are optional while repository-local command
paths are used.

