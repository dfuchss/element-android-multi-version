#!/bin/bash
START=$(pwd)

VERSION=$(curl --silent "https://api.github.com/repos/vector-im/element-android/releases/latest" | jq -r .tag_name)
git clone --depth 1 --branch $VERSION https://github.com/vector-im/element-android
cd element-android
sed -i 's/resValue \"string\", \"app_name\", \"Element\"/resValue "string", "app_name", "Matrix (KIT)"/g' vector-app/build.gradle
sed -i 's/\/\/ signingConfig signingConfigs.release/signingConfig signingConfigs.release/g' vector-app/build.gradle
sed -i 's/fdroid {/fdroid {\n            applicationIdSuffix \".fkit\"/g' vector-app/build.gradle
sed -i 's/gplay {/gplay {\n            applicationIdSuffix \".gkit\"/g' vector-app/build.gradle
// Set signing ..

docker run -t --rm -v $(pwd):/app androidsdk/android-31 bash -c "cd /app/ && /app/gradlew -q assembleFdroidRelease"

cd $START
