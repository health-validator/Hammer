#!/bin/bash
cd "$(dirname "$0")" || exit

dotnet Hammer.dll
