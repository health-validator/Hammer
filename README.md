<h1 align="center">
  <br>
  <a href="https://github.com/health-validator/Hammer"><img src="https://raw.githubusercontent.com/health-validator/Hammer/master/assets/hammer-logo.png" alt="Hammer" width="200"></a>
  <br>
  Hammer
  <br>
</h1>

<h4 align="center">A modern, cross-platform validator for <a href="http://hl7.org/fhir/index.html" target="_blank">FHIR®</a>.</h4>

<p align="center">
  <a href="https://github.com/health-validator/Hammer/wiki/How-to-download-latest-development-build">
    <img src="https://travis-ci.com/health-validator/Hammer.svg?branch=master"
         alt="Build status">
  </a>
  <a href="https://chat.fhir.org/#narrow/stream/179239-tooling/topic/Hammer">
    <img src="https://img.shields.io/badge/chat-on%20zulip-green.svg">
  </a>
  <a href="https://github.com/health-validator/Hammer/issues">
    <img src="https://img.shields.io/badge/contributions-welcome-brightgreen.svg?style=flat">
  </a>
  <a href="https://lgtm.com/projects/g/health-validator/Hammer/alerts/">
    <img alt="Total alerts" src="https://img.shields.io/lgtm/alerts/g/health-validator/Hammer.svg?logo=lgtm&logoWidth=18"/>
  </a>
</p>

<p align="center">
  <a href="#key-features">Key Features</a> •
  <a href="#how-to-use">How To Use</a> •
  <a href="#download">Download</a> •
  <a href="#credits">Credits</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img alt="Hammer demo" src="https://raw.githubusercontent.com/health-validator/Hammer/master/assets/hammer-demo.gif">
</p>

## Status

Experimental and not ready for production. Try it out and [give feedback](https://github.com/health-validator/Hammer/issues)!

## Key Features

* .NET and Java dual-validation
* XML and JSON
* Dark theme
* Simple, intuitive design
* Filter by message type
* Copy validation report as CSV
* Open-source and Free
* Cross platform
  - Windows, macOS and Linux.

## Download

[Windows](https://github.com/health-validator/Hammer/releases/download/latest/Hammer-windows.zip) | [macOS](https://github.com/health-validator/Hammer/releases/download/latest/Hammer-macos.zip) | [Linux](https://github.com/health-validator/Hammer/releases/download/latest/Hammer-linux.zip)

## How To Use

### Windows
Double-click `Hammer.exe`.

### macOS and Linux

1. Install [.NET Core 3.1 Runtime](https://dotnet.microsoft.com/download)
1. Launch Hammer: double-click `run-hammer.sh`

### Validating

1. Drag and drop, paste, or open a FHIR instance.
1. Adjust the validation scope in settings if necessary - by default, it's the folder and subfolders the resource was opened from.
1. Click `Validate`.

First time Hammer launches, it needs to download the necessary components to run - so it'll take a bit of time.

## Roadmap

See the [project's roadmap](https://github.com/health-validator/Hammer/blob/master/ROADMAP.md) to get an idea of where it's headed, as well as contribute!

## Credits

Author: [Vadim Peretokin](https://www.linkedin.com/in/vadimperetokin). Join in, contributions are welcome!

This software wouldnt've been possible without these open source packages:

- [Java FHIR validator](https://www.hl7.org/fhir/validation.html#jar)
- [.NET API for FHIR](https://fire.ly/fhir-api/)
- [.NET Core](https://dotnet.microsoft.com/)
- [CsvHelper](https://joshclose.github.io/CsvHelper/)
- [Qml.Net](https://github.com/qmlnet/qmlnet)
- [Qt](https://www.qt.io/)
- [TextCopy](https://github.com/SimonCropp/TextCopy/)

This project is not related to [Firely](https://fire.ly/).

Credit to [Markdownify](https://github.com/amitmerchant1990/electron-markdownify) for the README inspiration.

## Related

[Furore.Fhir.ValidationDemo](https://github.com/FirelyTeam/Furore.Fhir.ValidationDemo) - Windows app demonstrating the use of the .NET HL7 FHIR Profile Validation API

## You may also like...

- [FHIR](http://hl7.org/fhir/) - Official HL7 FHIR® specification
- [FRED](https://github.com/smart-on-fhir/fred) - FHIR instance editor
- [Ontoserver](http://ontoserver.csiro.au/) - Production-grade terminology server
- [Simplifier](https://simplifier.net/) - The FHIR hub
- [Vonk](https://fire.ly/products/vonk) - Production-grade FHIR server

## License

MIT

---

> LinkedIn [@vadimperetokin](https://www.linkedin.com/in/vadimperetokin) &nbsp;&middot;&nbsp;
> FHIR Zulip [@Vadim Peretokin](https://chat.fhir.org/#narrow/search/user.20vadim.20peretokin)

