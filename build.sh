#!/bin/bash
START=$(pwd)

VERSION=$(curl --silent "https://api.github.com/repos/vector-im/element-android/releases/latest" | jq -r .tag_name)
git clone --depth 1 --branch $VERSION https://github.com/vector-im/element-android
cd element-android
sed -i 's/resValue \"string\", \"app_name\", \"Element\"/resValue "string", "app_name", "Matrix (KIT)"/g' vector-app/build.gradle
sed -i 's/\/\/ signingConfig signingConfigs.release/signingConfig signingConfigs.release/g' vector-app/build.gradle
sed -i 's/fdroid {/fdroid {\n            applicationIdSuffix \".fkit\"/g' vector-app/build.gradle
sed -i 's/gplay {/gplay {\n            applicationIdSuffix \".gkit\"/g' vector-app/build.gradle
# Fix package_name for google services
sed -i 's/\"package_name\": \"im.vector.app\"/"package_name": "im.vector.app.gkit"/g' vector-app/src/gplay/release/google-services.json

# Set signing .. TODO

# Build APKs
docker run -t --rm -v $(pwd):/app androidsdk/android-31 bash -c "cd /app/ && /app/gradlew assembleFdroidRelease assembleGplayRelease"

# Copy APKs .. TODO

cd $START
