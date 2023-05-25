#!/bin/bash
set -e

mkdir -p releases

DEPLOY="$GITHUB_WORKSPACE/fdroid"
DIR=$(pwd)
LATEST=$(curl --silent "https://api.github.com/repos/vector-im/element-android/releases/latest" | jq -r .tag_name)
echo "Latest Version $LATEST"

if compgen -G "releases/*$LATEST*.apk" > /dev/null; then
        echo "Version already present."
        exit 0
fi

if [[ ! "$LATEST" =~ ^v[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "New RC $LATEST .. skipping as no release .."
        exit 0
fi


echo "Building Latest Version $LATEST"

sudo rm -rf "$DIR/element-android"

if [ ! -d "$DIR/element-android" ]; then
        echo "Cloning repository .."
        git clone -q https://github.com/vector-im/element-android
fi

echo "Switching to $LATEST"
cd element-android && git clean -f -x -q && git reset -q --hard && git fetch -q && git checkout -q $LATEST && git clean -q -d -x -f

cd $DIR/element-android
echo "Applying Modifications in $DIR/element-android"
# Rename App
sed -i 's/resValue \"string\", \"app_name\", \"Element\"/resValue "string", "app_name", "Matrix (KIT)"/g' vector-app/build.gradle
# Change color of App Icon
sed -i -e 's/.*launcher_background.*/<color name="launcher_background">#31AD93<\/color>/g' vector-app/src/main/res/values/colors.xml

sed -i 's/\/\/ signingConfig signingConfigs.release/signingConfig signingConfigs.release/g' vector-app/build.gradle
sed -i 's/fdroid {/fdroid {\n            applicationIdSuffix \".fkit\"/g' vector-app/build.gradle

# Fix package_name for google services
sed -i 's/gplay {/gplay {\n            applicationIdSuffix \".gkit\"/g' vector-app/build.gradle
sed -i 's/\"package_name\": \"im.vector.app\"/"package_name": "im.vector.app.gkit"/g' vector-app/src/gplay/release/google-services.json

# Setup Signing
cp ../apps.jks .
sed -i '/signing.element.storePath.*/d' gradle.properties
sed -i '/signing.element.storePassword.*/d' gradle.properties
sed -i '/signing.element.keyId.*/d' gradle.properties
sed -i '/signing.element.keyPassword.*/d' gradle.properties
cat ../keystore.properties >> gradle.properties

cd $DIR

echo "RUN Build"
docker run -t --rm -v $DIR/element-android:/app androidsdk/android-31 bash -c "cd /app/ && /app/gradlew assembleFdroidRustCryptoRelease assembleGplayRustCryptoRelease"

echo "Saving Release $LATEST"
cp element-android/vector-app/build/outputs/apk/fdroidRustCrypto/release/vector-fdroid-*-arm64-v8a-release.apk "releases/matrix-fdroid-$LATEST.apk"
cp element-android/vector-app/build/outputs/apk/gplayRustCrypto/release/vector-gplay-*-arm64-v8a-release.apk "releases/matrix-gplay-$LATEST.apk"
sudo rm -rf "$DIR/element-android"

echo "Saving Release for Deployment to $DEPLOY"
mkdir -p $DEPLOY/repo
install releases/matrix-fdroid-$LATEST.apk $DEPLOY/repo/
install releases/matrix-gplay-$LATEST.apk $DEPLOY/repo/

rm releases/*$LATEST*.apk
VER=$(date +%s)
echo $VER > releases/element-$LATEST.apk

cd $DEPLOY
META=$DEPLOY/metadata/im.vector.app.fkit.yml
if [ -f "$META" ]; then
        echo "Updating Meta Data"
        sed -i "s/CurrentVersionCode.*/CurrentVersionCode: $VER/g" $META
else
        echo "Meta Data not present. Please update on your own"
fi

META=$DEPLOY/metadata/im.vector.app.gkit.yml
if [ -f "$META" ]; then
        echo "Updating Meta Data"
        sed -i "s/CurrentVersionCode.*/CurrentVersionCode: $VER/g" $META
else
        echo "Meta Data not present. Please update on your own"
fi

sudo apt-get update && sudo apt-get install fdroidserver -y
fdroid update
