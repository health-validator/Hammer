#!/usr/bin/env bash

set -e
sed -i 's|// import appmodel 1.0|import appmodel 1.0|g' Main.qml

dotnet pack
echo "Created package"

sed -i 's|import appmodel 1.0|// import appmodel 1.0|g' Main.qml
echo "Revesed Main.qml changes"

echo "Done!"
