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
  <a href="#download">Download</a> •
  <a href="#features">Features</a> •
  <a href="#credits">Credits</a>
</p>

<p align="center">
  <a href="https://raw.githubusercontent.com/health-validator/Hammer/main/assets/hammer-intro.mov">
    <img
      src="https://raw.githubusercontent.com/health-validator/Hammer/main/assets/hammer-intro.gif"
      alt="Hammer demo"
      width="500px"
    />
  </a>
</p>

<!-- keeping for website version
<div class="center">
  <video class="hammer-intro" muted autoplay loop playsinline>
    <source src="/assets/hammer-intro.webm" type="video/webm">
    <source src="/assets/hammer-intro.mp4" type="video/mp4">
  </video>
</div>
-->

You've got a FHIR resource. You want to validate it, but how?

Use Hammer. Drag & drop a resource into the app, hit `Validate`, and let it do its magic.

## Features

### Simple, intuitive design
> <img src="https://raw.githubusercontent.com/health-validator/Hammer/main/assets/images/hammer-main-window.webp" width="500">
<br/><br/><br/>

### Dual-validation by the best FHIR validators
> <img src="https://raw.githubusercontent.com/health-validator/Hammer/main/assets/images/dual-validation.webp" width="500">
<br/><br/><br/>


### Both JSON and XML supported
> <img src="https://raw.githubusercontent.com/health-validator/Hammer/main/assets/images/json-xml-example.webp" width="500">
<br/><br/><br/>

### STU3 and R4 supported
> <img src="https://raw.githubusercontent.com/health-validator/Hammer/main/assets/images/stu3-and-r4-supported.webp" width="500">
<br/><br/><br/>

### Copy validation report as CSV
> <img src="https://raw.githubusercontent.com/health-validator/Hammer/main/assets/images/csv-export.webp" width="500">
<br/><br/><br/>

### Filter by errors/warnings/info
> <img src="https://raw.githubusercontent.com/health-validator/Hammer/main/assets/images/filter-errors.webp" width="500">
<br/><br/><br/>

### Open-source and Free

### Windows, macOS, and Linux

## Download

Recommended: Windows [installer](https://github.com/health-validator/Hammer/releases/download/Hammer-1.0.0/Hammer-1.0.0-installer.exe) or [zip](https://github.com/health-validator/Hammer/releases/download/Hammer-1.0.0/Hammer-1.0.0-windows-installerfree.zip) | [macOS](https://github.com/health-validator/Hammer/releases/download/Hammer-1.0.0/Hammer-1.0.0-macos.zip) | [Linux](https://github.com/health-validator/Hammer/releases/download/Hammer-1.0.0/hammer-linux.zip)

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

