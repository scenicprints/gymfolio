#!/usr/bin/env bash
# Regenerate the android/ project and apply the three patches this app needs.
#
# The repo tracks lib/, assets/, test/ and pubspec.yaml only — android/ is
# generated, so anything it needs has to be applied here rather than committed.
# CI runs this, and so can you locally, which means the build you test is the
# build that ships.
set -euo pipefail

ORG=com.scenicprints
NAME=gymfolio

if [ ! -d android ]; then
  echo "==> Generating android/"
  rm -rf _scaffold
  flutter create --platforms=android --org "$ORG" --project-name "$NAME" _scaffold
  cp -r _scaffold/android ./android
  rm -rf _scaffold
else
  echo "==> android/ already present, patching in place"
fi

M=android/app/src/main/AndroidManifest.xml

# 1. Permissions. Flutter only puts INTERNET in the DEBUG manifest, so a release
#    build silently loses all networking — the update check included.
echo "==> Permissions"
for P in INTERNET REQUEST_INSTALL_PACKAGES POST_NOTIFICATIONS VIBRATE \
         RECEIVE_BOOT_COMPLETED; do
  grep -q "android.permission.$P" "$M" || \
    sed -i "s|<application|<uses-permission android:name=\"android.permission.$P\"/>\n    <application|" "$M"
done

# 1b. Launcher label — flutter create uses the lowercase project name.
echo "==> Label"
sed -i 's|android:label="gymfolio"|android:label="GymFolio"|' "$M"

# 2. flutter_local_notifications needs core library desugaring, or the release
#    build fails at dex time with a java.time error that says nothing useful.
echo "==> Core library desugaring"
G=android/app/build.gradle.kts
if ! grep -q "isCoreLibraryDesugaringEnabled" "$G"; then
  sed -i "s|    compileOptions {|    compileOptions {\n        isCoreLibraryDesugaringEnabled = true|" "$G"
fi
if ! grep -q "coreLibraryDesugaring" "$G"; then
  cat >> "$G" <<'EOF'

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.4")
}
EOF
fi

# 3. The scheduled-notification receivers live in the plugin's own manifest and
#    merge in automatically; nothing to add. Print the result so a failed build
#    can be diagnosed from the log alone.
echo "==> Manifest head"
head -n 12 "$M"
echo "==> compileOptions"
grep -A4 "compileOptions" "$G" | head -8
echo "==> dependencies"
tail -n 5 "$G"
