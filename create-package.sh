#!/usr/bin/env bash

set -e
qt_version='5.15.1-7fc8b10'
dotnet_platform='win-x64'
buildnames=(win osx linux)

sed -i 's|// import appmodel 1.0|import appmodel 1.0|g' Main.qml
echo "Prepared Main.qml for packaging"

for i in "${buildnames[@]}"
do
  if [ ! -d "qt-runtime-$i" ]; then
    if [ ! -e "qt-runtime-$i.tar.gz" ]; then
      echo "download https://github.com/qmlnet/qt-runtimes/releases/download/releases/qt-${qt_version}-${i}-x64-runtime.tar.gz"
      curl --location --output "qt-runtime-$i.tar.gz" "https://github.com/qmlnet/qt-runtimes/releases/download/releases/qt-${qt_version}-${i}-x64-runtime.tar.gz"
    fi
    mkdir -p "qt-runtime-$i/"
    tar -xf "qt-runtime-$i.tar.gz" -C "qt-runtime-$i/"
  fi
done

echo "Qt runtimes downloaded & unpacked"

dotnet pack
echo "Created package"

sed -i 's|import appmodel 1.0|// import appmodel 1.0|g' Main.qml
echo "Revesed Main.qml changes"

echo "Done!"
