#!/usr/bin/env bash

set -e

buildname='windows'
qt_version='5.15.1-7fc8b10'
dotnet_platform='win-x64'

sed -i 's|// import appmodel 1.0|import appmodel 1.0|g' Main.qml
echo "Prepared Main.qml for packaging"

if [ ! -d qt-runtime ]; then
  if [ ! -e qt-runtime.tar.gz ]; then
    curl --location --output qt-runtime.tar.gz "https://github.com/qmlnet/qt-runtimes/releases/download/releases/qt-${qt_version}-${dotnet_platform}-runtime.tar.gz"
  fi
  mkdir -p qt-runtime/
  tar -xf qt-runtime.tar.gz -C qt-runtime/
fi
echo "Qt runtime downloaded & unpacked"

dotnet pack
echo "Created package"

sed -i 's|import appmodel 1.0|// import appmodel 1.0|g' Main.qml
echo "Revesed Main.qml changes"

echo "Done!"
