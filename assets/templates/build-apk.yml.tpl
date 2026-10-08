name: Build APK

on:
  push:
    branches: [main, master]
  workflow_dispatch:

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-java@v4
        with:
          distribution: temurin
          java-version: "17"

      - uses: subosito/flutter-action@v2
        with:
          channel: stable
          cache: true

      - name: Generate platform folders if missing
        run: |
          if [ ! -d android ]; then
            cp pubspec.yaml /tmp/pubspec.yaml
            cp -r lib /tmp/lib
            flutter create --platforms={{PLATFORMS}} --android-language {{ANDROID_LANG}} --project-name {{NAME}} --org {{ORG}} .
            cp /tmp/pubspec.yaml pubspec.yaml
            rm -rf lib test
            cp -r /tmp/lib lib
          fi

      - name: Configure Android project
        run: |
          MANIFEST=android/app/src/main/AndroidManifest.xml
          sed -i 's#<application#<uses-permission android:name="android.permission.INTERNET"/>\n    <application android:usesCleartextTraffic="true"#' "$MANIFEST"
          sed -i 's/android:label="[^"]*"/android:label="{{TITLE}}"/' "$MANIFEST"
          sed -i 's/flutter\.minSdkVersion/24/' android/app/build.gradle* || true
          sed -i 's/^org.gradle.jvmargs=.*/org.gradle.jvmargs=-Xmx3g -XX:MaxMetaspaceSize=1g/' android/gradle.properties || true

      - name: Gradle fixes (compileSdk)
        run: |
          mkdir -p ~/.gradle/init.d
          cp gradle_fix/fix.gradle ~/.gradle/init.d/fix.gradle

      - run: flutter pub get
      - run: flutter build apk --release --no-shrink

      - uses: actions/upload-artifact@v4
        with:
          name: {{NAME}}-apk
          path: build/app/outputs/flutter-apk/app-release.apk
