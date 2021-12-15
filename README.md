<h1 align="center">
  <br>
  <a href="https://github.com/health-validator/Hammer"><img src="https://raw.githubusercontent.com/health-validator/Hammer/master/assets/hammer-logo.png" alt="Hammer" width="200"></a>
  <br>
  Hammer
  <br>
</h1>

<h4 align="center">A modern, cross-platform validator for <a href="http://hl7.org/fhir/index.html" target="_blank">FHIR®</a>.</h4>

<p align="center">
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
  <a href="#what">What?</a> •
  <a href="#how-to-use">How To Use</a> •
  <a href="#download">Download</a> •
  <a href="#credits">Credits</a> •
  <a href="#roadmap">Roadmap</a> •
  <a href="#license">License</a>
</p>

<p align="center">
  <img
    src="https://raw.githubusercontent.com/health-validator/Hammer/get-firefox-to-show-video/assets/hammer-intro.gif"
    alt="Hammer demo"
    width="50%"
  />
</p>

<!-- keeping for website version
<div class="center">
  <video class="hammer-intro" muted autoplay loop playsinline>
    <source src="/assets/hammer-intro.webm" type="video/webm">
    <source src="/assets/hammer-intro.mp4" type="video/mp4">
  </video>
</div>
-->

## What?

You've got a FHIR resource. You want to validate it, but how?

Use Hammer. Drag & drop a resource into the app, hit `Validate`, and let it do its magic.

## Features

* Simple, intuitive design
* .NET and Java dual-validation
* XML and JSON supported
* Dark theme available
* Copy validation report as CSV
* Filter by errors/warnings/info
* Open-source and Free
* Cross platform
  - Windows, macOS, and Linux.

## Download

Recommended: Windows [installer](https://github.com/health-validator/Hammer/releases/download/Hammer-0.0.3/Hammer-0.0.3-installer.exe) or [zip](https://github.com/health-validator/Hammer/releases/download/Hammer-0.0.3/Hammer-0.0.3-installerfree.zip) | [macOS](https://github.com/health-validator/Hammer/releases/download/Hammer-0.0.3/hammer-macos.zip) | [Linux](https://github.com/health-validator/Hammer/releases/download/Hammer-0.0.3/hammer-linux.zip)

Alternatively, you can also install it as .NET tool:

```sh
dotnet tool install --global Hammer
```

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

This project is not related to any employer.

## License

MIT

---

> LinkedIn [@vadimperetokin](https://www.linkedin.com/in/vadimperetokin) &nbsp;&middot;&nbsp;
> FHIR Zulip [@Vadim Peretokin](https://chat.fhir.org/#narrow/search/user.20vadim.20peretokin)

