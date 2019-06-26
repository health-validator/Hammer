#!/bin/sh

brew install tree

tree .

curl --silent --output "dotnet-sdk.tar.gz" "https://download.visualstudio.microsoft.com/download/pr/079e5b24-187f-4087-9a54-18285382f3e6/2ae97c55aae5e2c9472555839a48a83c/dotnet-sdk-3.0.100-preview6-012264-osx-x64.tar.gz"

tree .

tar --extract --file "dotnet-sdk.tar.gz" --directory ".dotnetsdk"

tree .
