#!/usr/bin/env bash

sed -i 's|// import appmodel 1.0|import appmodel 1.0|g' Main.qml
echo "Prepared file for packaging"

dotnet pack
echo "Created package"

sed -i 's|import appmodel 1.0|// import appmodel 1.0|g' Main.qml
echo "Revesed Main.qml changes"

echo "Done!"
