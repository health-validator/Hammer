﻿extern alias stu3;
extern alias r4;

using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;
using CommandLine;
using CsvHelper;
using Hl7.Fhir.ElementModel;
using Hl7.Fhir.Model;
using stu3::Hl7.Fhir.Rest;
using r4::Hl7.Fhir.Rest;
using Hl7.Fhir.Serialization;
using Hl7.Fhir.Specification.Source;
using stu3::Hl7.Fhir.Specification.Terminology;
using r4::Hl7.Fhir.Specification.Terminology;
using Hl7.Fhir.Utility;
using stu3::Hl7.Fhir.Validation;
using r4::Hl7.Fhir.Validation;
using Hl7.FhirPath;
using Qml.Net;
using Qml.Net.Runtimes;
using TextCopy;
using Task = System.Threading.Tasks.Task;
using System.Globalization;
using System.Net.Http;
using Newtonsoft.Json.Linq;

class Program
{
    [Signal("validationStarted")]
    [Signal("examplesLoaded")]
    [Signal("updateAvailable", NetVariantType.String)]
    public class AppModel : IDisposable
    {
        private static AppModel _instance;
        public static AppModel Instance => _instance ?? (_instance = new AppModel());

        public static bool HasInstance => _instance != null;

        public AppModel()
        {
            _instance = this;
        }

        public void Dispose()
        {
            if (_validatorCancellationSource != null)
            {
                _validatorCancellationSource.Dispose();
                _validatorCancellationSource = null;
            }
            GC.SuppressFinalize(this);
        }

        public enum ResourceFormat
        {
            Xml = 1,
            Json = 2,
            Unknown = 3
        }

        // this only gets populated on use, so it's OK to setup beforehand
        private readonly Hl7.Fhir.Specification.Source.IResourceResolver _coreSourceStu3 = new Hl7.Fhir.Specification.Source.CachedResolver(new stu3.Hl7.Fhir.Specification.Source.ZipSource(Path.Combine(Extensions.GetApplicationLocation(), "specification_Fhir3_0.zip")));
        private readonly Hl7.Fhir.Specification.Source.IResourceResolver _coreSourceR4 = new Hl7.Fhir.Specification.Source.CachedResolver(new r4.Hl7.Fhir.Specification.Source.ZipSource(Path.Combine(Extensions.GetApplicationLocation(), "specification_Fhir4_0.zip")));

        private Hl7.Fhir.Specification.Source.IResourceResolver _combinedSource;

        // ReSharper disable MemberCanBePrivate.Global
        #region QML-accessible properties
        private ResourceFormat _instanceFormat;

        private string _validateButtonText = "Validate";
        [NotifySignal]
        public string ValidateButtonText
        {
            get => _validateButtonText;
            set => this.SetProperty(ref _validateButtonText, value);
        }

        private string _applicationVersion = Assembly.GetEntryAssembly().GetName().Version.ToString();
        [NotifySignal]
        public string ApplicationVersion
        {
            get => _applicationVersion;
            set => this.SetProperty(ref _applicationVersion, value);
        }

        private string _noJavaInstall = "No Java install detected - Java validator couldn't run. Would you like to install Java?";
        [NotifySignal]
        public string NoJavaInstall
        {
            get => _noJavaInstall;
            set => this.SetProperty(ref _noJavaInstall, value);
        }

        private string _javaInstallLink = "https://adoptium.net/releases.html?variant=openjdk16&jvmVariant=hotspot";
        [NotifySignal]
        public string JavaInstallLink
        {
            get => _javaInstallLink;
            set => this.SetProperty(ref _javaInstallLink, value);
        }

        private string _scopeDirectory;
        [NotifySignal]
        public string ScopeDirectory
        {
            get => _scopeDirectory;
            set
            {
                _scopeDirectory = value;
                this.ActivateProperty(x => x.ScopeDirectory);

                if (_scopeDirectory == null)
                {
                    return;
                }

                if (FhirVersion == "STU3")
                {
                    var directorySource = new CachedResolver(
                        new stu3.Hl7.Fhir.Specification.Source.DirectorySource(_scopeDirectory, new stu3.Hl7.Fhir.Specification.Source.DirectorySourceSettings { IncludeSubDirectories = true }));

                    // Finally, we combine both sources, so we will find profiles both from the core zip as well as from the directory.
                    // By mentioning the directory source first, anything in the user directory will override what is in the core zip.
                    _combinedSource = new Hl7.Fhir.Specification.Source.MultiResolver(directorySource, _coreSourceStu3);
                }
                else
                {
                    var directorySource = new CachedResolver(
                        new r4.Hl7.Fhir.Specification.Source.DirectorySource(_scopeDirectory, new r4.Hl7.Fhir.Specification.Source.DirectorySourceSettings { IncludeSubDirectories = true }));
                    _combinedSource = new Hl7.Fhir.Specification.Source.MultiResolver(directorySource, _coreSourceR4);
                }
            }
        }

        private string _resourceText;
        [NotifySignal]
        public string ResourceText
        {
            get => _resourceText;
            set
            {
                if (_resourceText == value)
                {
                    return;
                }

                _resourceText = value;
                UpdateResourceType(_resourceText);
                this.ActivateProperty(x => x.ResourceText);
            }
        }

        private string _resourceFont;
        [NotifySignal]
        public string ResourceFont
        {
            get => _resourceFont;
            set
            {
                if (_resourceFont == value)
                {
                    return;
                }

                _resourceFont = value;
                this.ActivateProperty(x => x.ResourceFont);
            }
        }

        private string _terminologyService = "https://tx.fhir.org/r3";
        [NotifySignal]
        public string TerminologyService
        {
            get => _terminologyService;
            set
            {
                if (_terminologyService == value)
                {
                    return;
                }

                _terminologyService = value;
                this.ActivateProperty(x => x.TerminologyService);
            }
        }

        // TODO replace with Firely SDK enum. Can be STU3 or R4
        // TODO also map to the terminologyService and java validator command line properly
        private string _fhirVersion = "STU3";
        [NotifySignal]
        public string FhirVersion
        {
            get => _fhirVersion;
            set
            {
                if (_fhirVersion == value)
                {
                    return;
                }

                if (TerminologyService.EndsWith("r3", StringComparison.CurrentCultureIgnoreCase) ||
                    TerminologyService.EndsWith("r4", StringComparison.CurrentCultureIgnoreCase))
                {
                    TerminologyService = TerminologyService.Remove(TerminologyService.Length - 2);

                    TerminologyService = value
                    switch
                    {
                        "STU3" => TerminologyService + "r3",
                        "R4" => TerminologyService + "r4",
                        _ => TerminologyService,
                    };
                }

                _fhirVersion = value;
                this.ActivateProperty(x => x.FhirVersion);

                // reset stu3/r4 spec + folder we're validating against
                ScopeDirectory = ScopeDirectory;
            }
        }

        private bool _validatingDotnet;
        [NotifySignal]
        public bool ValidatingDotnet
        {
            get => _validatingDotnet;
            set => this.SetProperty(ref _validatingDotnet, value);
        }

        private bool _validatingJava;
        [NotifySignal]
        public bool ValidatingJava
        {
            get => _validatingJava;
            set => this.SetProperty(ref _validatingJava, value);
        }

        private List<Issue> _javaIssues = new List<Issue>();
        [NotifySignal]
        public List<Issue> JavaIssues
        {
            get => _javaIssues;
            set => this.SetProperty(ref _javaIssues, value);
        }

        private List<Issue> _dotnetIssues = new List<Issue>();
        [NotifySignal]
        public List<Issue> DotnetIssues
        {
            get => _dotnetIssues;
            set => this.SetProperty(ref _dotnetIssues, value);
        }

        // exposes examples to QML
        private List<Example> _examples = new List<Example>();
        [NotifySignal]
        public List<Example> Examples
        {
            get => _examples;
            set => this.SetProperty(ref _examples, value);
        }

        // loads examples from disk
        public class DiskExample
        {
            public string Filename { get; set; }
            public string Title { get; set; }
            public string Description { get; set; }
        }

        private bool _javaValidationCrashed;
        [NotifySignal]
        public bool JavaValidationCrashed
        {
            get => _javaValidationCrashed;
            set => this.SetProperty(ref _javaValidationCrashed, value);
        }

        private bool _animateQml = true;
        /// <summary>Set to false to suppress animations in QML</summary>
        [NotifySignal]
        public bool AnimateQml
        {
            get => _animateQml;
            set => this.SetProperty(ref _animateQml, value);
        }

        private ValidationResult _javaResult = new ValidationResult();
        [NotifySignal]
        public ValidationResult JavaResult
        {
            get => _javaResult;
            set => this.SetProperty(ref _javaResult, value);
        }

        private ValidationResult _dotnetResult = new ValidationResult();
        [NotifySignal]
        public ValidationResult DotnetResult
        {
            get => _dotnetResult;
            set => this.SetProperty(ref _dotnetResult, value);
        }
        #endregion

        private readonly string RepoOrg = "health-validator";

        private readonly string RepoName = "Hammer";

        private ITypedElement _parsedResource;

        private CancellationTokenSource _validatorCancellationSource;

        private readonly List<Process> _validatorProcesses = new List<Process>();

        private void ResetResults()
        {
            JavaIssues = new List<Issue>();
            DotnetIssues = new List<Issue>();
            JavaValidationCrashed = false;
        }

        public enum ValidatorType { Dotnet = 1, Java = 2 }

        public class ValidationResult
        {
            private ValidatorType _validatorType;
            [NotifySignal]
            public ValidatorType ValidatorType
            {
                get => _validatorType;
                set => this.SetProperty(ref _validatorType, value);
            }

            private List<Issue> _issues = new List<Issue>();

            [NotifySignal]
            public List<Issue> Issues
            {
                get => _issues;
                set => this.SetProperty(ref _issues, value);
            }

            private int _errorCount;
            [NotifySignal]
            public int ErrorCount
            {
                get => _errorCount;
                set => this.SetProperty(ref _errorCount, value);
            }

            private int _warningCount;
            [NotifySignal]
            public int WarningCount
            {
                get => _warningCount;
                set => this.SetProperty(ref _warningCount, value);
            }
        }

        // not a struct due to https://github.com/qmlnet/qmlnet/issues/135
        public class Issue
        {
            private string _severity;
            [NotifySignal]
            public string Severity
            {
                get => _severity;
                set => this.SetProperty(ref _severity, value);
            }

            private string _text;
            [NotifySignal]
            public string Text
            {
                get => _text;
                set => this.SetProperty(ref _text, value);
            }

            private string _location;
            [NotifySignal]
            public string Location
            {
                get => _location;
                set => this.SetProperty(ref _location, value);
            }

            private int _lineNumber;
            [NotifySignal]
            public int LineNumber
            {
                get => _lineNumber;
                set => this.SetProperty(ref _lineNumber, value);
            }

            private int _linePosition;
            [NotifySignal]
            public int LinePosition
            {
                get => _linePosition;
                set => this.SetProperty(ref _linePosition, value);
            }
        }

        public class Example
        {
            private string _filepath;
            [NotifySignal]
            public string Filepath
            {
                get => _filepath;
                set => this.SetProperty(ref _filepath, value);
            }

            private string _title;
            [NotifySignal]
            public string Title
            {
                get => _title;
                set => this.SetProperty(ref _title, value);
            }

            private string _description;
            [NotifySignal]
            public string Description
            {
                get => _description;
                set => this.SetProperty(ref _description, value);
            }
        }

        private class MarkdownIssue
        {
            public string Severity;
            public string Text;
            public string Location;
        }

        public ResourceFormat InstanceFormat
        {
            get => _instanceFormat;
            set
            {
                _instanceFormat = value;
                switch (_instanceFormat)
                {
                    case ResourceFormat.Xml:
                        ValidateButtonText = "Validate (xml)";
                        break;
                    case ResourceFormat.Json:
                        ValidateButtonText = "Validate (json)";
                        break;
                    case ResourceFormat.Unknown:
                        ValidateButtonText = "Validate";
                        break;
                }
            }
        }

        private bool terminologyDisabled()
        {
            string[] disabledTerminology = {"don't check with any server", "n/a", "off", "none"};
            return disabledTerminology.Contains(TerminologyService, StringComparer.OrdinalIgnoreCase);
        }

        private string getJavaTxString()
        {
            if (terminologyDisabled())
            {
                return "n/a";
            }

            return TerminologyService;
        }

        private bool useDotnetExternalTx()
        {
            if (!terminologyDisabled())
            {
                return true;
            }

            return false;
        }

        private List<Issue> convertIssues(List<OperationOutcome.IssueComponent> issues)
        {
            List<Issue> convertedIssues = new List<Issue>();

            foreach (var issue in issues)
            {
                var simplifiedIssue = new Issue
                {
                    Severity = issue.Severity.ToString().ToLowerInvariant(),
                    Text = issue.Details?.Text ?? issue.Diagnostics ?? "(no details)",
                    Location = String.Join(" via ", issue.Location)
                };
                convertedIssues.Add(simplifiedIssue);

                // read Java details
                var javaLineNumber = issue.GetIntegerExtension("http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-line");
                var javaLinePosition = issue.GetIntegerExtension("http://hl7.org/fhir/StructureDefinition/operationoutcome-issue-col");
                if (javaLineNumber.HasValue && javaLinePosition.HasValue)
                {
                    simplifiedIssue.LineNumber = javaLineNumber.Value;
                    simplifiedIssue.LinePosition = javaLinePosition.Value;
                    continue;
                }

                // read .NET details
                var serializationDetails = GetPositionInfo(issue);
                if (serializationDetails == null)
                {
                    continue;
                }

                simplifiedIssue.LineNumber = serializationDetails.LineNumber;
                simplifiedIssue.LinePosition = serializationDetails.LinePosition;



            }

            return convertedIssues;
        }

        private IPositionInfo GetPositionInfo(OperationOutcome.IssueComponent issue)
        {
            IPositionInfo serializationDetails;

            if (!issue.Location.Any())
            {
                return null;
            }
            var location = SanitizeLocation(issue.Location.First());
            if (location == null)
            {
                return null;
            }

            List<ITypedElement> elementWithError = null;
            try
            {
                elementWithError = _parsedResource.Select(location).ToList();
            }
            catch (FormatException)
            {
                // if the FHIRPath is invalid, don't return position info for it
            }

            if (elementWithError == null || !elementWithError.Any())
            {
                return null;
            }

            switch (InstanceFormat)
            {
                case ResourceFormat.Json:
                    serializationDetails = elementWithError.First().GetJsonSerializationDetails();
                    break;
                case ResourceFormat.Xml:
                    serializationDetails = elementWithError.First().GetXmlSerializationDetails();
                    break;
                case ResourceFormat.Unknown:
                    return null;
                default:
                    return null;
            }

            return serializationDetails;
        }

        private static MatchCollection ExtractLocation(string rawLocation)
        {
            const string pattern = @"([^\(]+)";
            return Regex.Matches(rawLocation, pattern);
        }

        private static MatchCollection ExtractReleaseVersion(string rawVersion)
        {
            const string pattern = @"Hammer-(.+)$";
            return Regex.Matches(rawVersion, pattern);
        }

        ///<summary>Trims Java FHIRpath of its position information, which isn't always correct
        /// we have to compute it ourselves for .NET, might as well do it for Java</summary>
        private string SanitizeLocation(string rawLocation)
        {
            // heuristic for the Java validator
            if (rawLocation == "(document)")
            {
                return _parsedResource.Name;
            }

            var matches = ExtractLocation(rawLocation);
            if (!matches.Any())
            {
                return null;
            }
            var location = matches.First().Groups[0].ToString().Trim();
            return location;
        }

        public bool LoadResourceFile(string text)
        {
            if (text == null)
            {
                Console.Error.WriteLine("LoadResourceFile: no text passed");
                return false;
            }

            // input already pruned - accept as-is
            if (!text.StartsWith("file://", StringComparison.InvariantCulture))
            {
                ResourceText = text;
                return true;
            }

            var filePath = text;
            // Windows can use three leading slashes, while others can use two
            // examples load with just two on windows as well - so simpler to
            // try both variants
            filePath = filePath.RemovePrefix("file:///");
            filePath = filePath.RemovePrefix("file://");
            if (!RuntimeInformation.IsOSPlatform(OSPlatform.Windows)) {
                filePath = filePath.Prepend("/");
            }
            filePath = filePath.Replace("\r", "", StringComparison.InvariantCulture)
                .Replace("\n", "", StringComparison.InvariantCulture);
            filePath = Uri.UnescapeDataString(filePath);
            Console.WriteLine($"Loading '{filePath}'...");

            if (!File.Exists(filePath))
            {
                Console.WriteLine($"File to load doesn't actually exist: {filePath}");
                return false;
            }

            ResourceText = File.ReadAllText(filePath);
            if (ScopeDirectory == null)
            {
                ScopeDirectory = Path.GetDirectoryName(filePath);
            }

            return true;
        }

        public void LoadScopeDirectory(string text)
        {
            // input already pruned - accept as-is
            if (!text.StartsWith("file://", StringComparison.InvariantCulture))
            {
                ScopeDirectory = text;
                return;
            }

            var filePath = text;
            filePath = filePath.RemovePrefix(RuntimeInformation
                .IsOSPlatform(OSPlatform.Windows) ? "file:///" : "file://");
            filePath = filePath.Replace("\r", "", StringComparison.InvariantCulture)
                .Replace("\n", "", StringComparison.InvariantCulture);
            filePath = Uri.UnescapeDataString(filePath);
            ScopeDirectory = filePath;
        }

        public void UpdateResourceType(string resourcetext)
        {
            var text = resourcetext;
            if (!String.IsNullOrEmpty(text))
            {
                if (SerializationUtil.ProbeIsXml(text))
                    InstanceFormat = ResourceFormat.Xml;
                else if (SerializationUtil.ProbeIsJson(text))
                    InstanceFormat = ResourceFormat.Json;
                else
                    InstanceFormat = ResourceFormat.Unknown;
            }
            else
                InstanceFormat = ResourceFormat.Unknown;
        }

        public async Task copyToClipboard(string message)
        {
            await ClipboardService.SetTextAsync(message);
        }

        public async Task CopyValidationReportCsv()
        {
            using var writer = new StringWriter();
            using var csv = new CsvWriter(writer, CultureInfo.InvariantCulture);

            // write fields out manually since we need to add the engine type column
            csv.WriteField("Severity");
            csv.WriteField("Text");
            csv.WriteField("Location");
            csv.WriteField("Validator engine");
            csv.NextRecord();

            foreach (var issue in DotnetIssues)
            {
                csv.WriteField(issue.Severity);
                csv.WriteField(issue.Text);
                csv.WriteField(issue.Location);
                csv.WriteField(".NET");
                csv.NextRecord();
            }

            foreach (var issue in JavaIssues)
            {
                csv.WriteField(issue.Severity);
                csv.WriteField(issue.Text);
                csv.WriteField(issue.Location);
                csv.WriteField("Java");
                csv.NextRecord();
            }

            await ClipboardService.SetTextAsync(writer.ToString());
        }

        public async Task CopyValidationReportMarkdown()
        {
            List<MarkdownIssue> ConvertToMarkdown(List<Issue> rawIssues)
            {
                var markdownIssues = new List<MarkdownIssue> { };
                foreach (var issue in rawIssues)
                {
                    markdownIssues.Add(new MarkdownIssue()
                    {
                        Severity = issue.Severity,
                        Text = issue.Text,
                        Location = (issue.LineNumber == 0 && issue.LinePosition == 0) ?
                            "" :
                            $"{issue.Location} (line {issue.LineNumber}:{issue.LinePosition})"
                    });
                }

                return markdownIssues;
            }

            var report = "";

            if (!ValidatingDotnet)
            {
                report += $@"**.NET Validator**

{ConvertToMarkdown(DotnetIssues).ToMarkdownTable()}

";
            }

            if (!ValidatingJava)
            {
                report += $@"** Java Validator**

{ConvertToMarkdown(JavaIssues).ToMarkdownTable()}

";
            }

            await ClipboardService.SetTextAsync(report);
        }

        private stu3.Hl7.Fhir.Validation.Validator CreateValidatorStu3(stu3.Hl7.Fhir.Rest.FhirClient fhirClient = null)
        {
            var resolver = _combinedSource ?? _coreSourceStu3;
            var localTerminology = new stu3.Hl7.Fhir.Specification.Terminology.LocalTerminologyService(resolver.AsAsync());

            var externalTerminology = (fhirClient != null) ? new stu3.Hl7.Fhir.Specification.Terminology.ExternalTerminologyService(fhirClient) : null;

            var combinedTerminology = (fhirClient != null) ? new stu3.Hl7.Fhir.Specification.Terminology.FallbackTerminologyService(localTerminology, externalTerminology) : null;

            var settings = new stu3.Hl7.Fhir.Validation.ValidationSettings
            {
                ResourceResolver = _combinedSource ?? _coreSourceStu3,
                GenerateSnapshot = true,
                EnableXsdValidation = true,
                Trace = false,
                ResolveExternalReferences = true,
                TerminologyService = combinedTerminology
            };

            return new stu3.Hl7.Fhir.Validation.Validator(settings);
        }

        private r4.Hl7.Fhir.Validation.Validator CreateValidatorR4(r4.Hl7.Fhir.Rest.FhirClient fhirClient = null)
        {
            var resolver = _combinedSource ?? _coreSourceR4;
            var localTerminology = new r4.Hl7.Fhir.Specification.Terminology.LocalTerminologyService(resolver.AsAsync());

            var externalTerminology = (fhirClient != null) ? new r4.Hl7.Fhir.Specification.Terminology.ExternalTerminologyService(fhirClient) : null;

            var combinedTerminology = (fhirClient != null) ? new r4.Hl7.Fhir.Specification.Terminology.FallbackTerminologyService(localTerminology, externalTerminology) : null;

            var settings = new r4.Hl7.Fhir.Validation.ValidationSettings
            {
                ResourceResolver = _combinedSource ?? _coreSourceR4,
                GenerateSnapshot = true,
                EnableXsdValidation = true,
                Trace = false,
                ResolveExternalReferences = true,
                TerminologyService = combinedTerminology
            };

            return new r4.Hl7.Fhir.Validation.Validator(settings);
        }

        public OperationOutcome ValidateWithDotnet(CancellationToken token)
        {
            Console.WriteLine("Beginning .NET validation");
            try
            {
                OperationOutcome result;

                Stopwatch sw = new Stopwatch();
                sw.Start();

                ISourceNode untyped;
                if (InstanceFormat == ResourceFormat.Xml)
                {
                    untyped = FhirXmlNode.Parse(ResourceText, new FhirXmlParsingSettings { PermissiveParsing = true });
                }
                else if (InstanceFormat == ResourceFormat.Json)
                {
                    untyped = FhirJsonNode.Parse(ResourceText, settings: new FhirJsonParsingSettings { AllowJsonComments = true });
                }
                else
                {
                    throw new Exception("This resource format isn't recognised");
                }

                if (FhirVersion == "STU3")
                {
                    var summaryProviderStu3 = new stu3.Hl7.Fhir.Specification.StructureDefinitionSummaryProvider(_combinedSource ?? _coreSourceStu3);
                    _parsedResource = untyped.ToTypedElement(summaryProviderStu3);

                    using var fhirClient = useDotnetExternalTx() ? new stu3.Hl7.Fhir.Rest.FhirClient(TerminologyService) : null;
                    var validator = CreateValidatorStu3(useDotnetExternalTx() ? fhirClient : null);
                    result = validator.Validate(_parsedResource);
                }
                else
                {
                    var summaryProviderR4 = new r4.Hl7.Fhir.Specification.StructureDefinitionSummaryProvider(_combinedSource ?? _coreSourceR4);
                    _parsedResource = untyped.ToTypedElement(summaryProviderR4);

                    using var fhirClient = useDotnetExternalTx() ? new r4.Hl7.Fhir.Rest.FhirClient(TerminologyService) : null;
                    var validator = CreateValidatorR4(useDotnetExternalTx() ? fhirClient : null);
                    result = validator.Validate(_parsedResource);
                }

                sw.Stop();
                token.ThrowIfCancellationRequested();
                Console.WriteLine($".NET validation performed in {sw.ElapsedMilliseconds}ms");

                return result;
            }
            catch (OperationCanceledException)
            {
                throw;
            }
            catch (Exception ex)
            {
                var result = new OperationOutcome();
                result.Issue.Add(new OperationOutcome.IssueComponent
                {
                    Severity = OperationOutcome.IssueSeverity.Error,
                    Diagnostics = $"{ex.GetType().Name}: {ex.Message}",
                    Code = OperationOutcome.IssueType.Exception
                });

                TextWriter errorWriter = Console.Error;
                errorWriter.WriteLine(ex.Message);
                errorWriter.WriteLine(ex.StackTrace);

                return result;
            }
        }

        private static string SerializeResource(string resourceText, ResourceFormat instanceFormat)
        {
            var fileName = $"{Path.GetTempFileName()}.{(instanceFormat == ResourceFormat.Json ? "json" : "xml")}";
            File.WriteAllText(fileName, resourceText);

            return fileName;
        }

        // in case the Java validator crashes (which it can if it doesn't like something),
        // it won't produce an OperationOutcome for us - take what we've got and make one ourselves
        private static OperationOutcome ConvertJavaStdout(string output)
        {
            var result = new OperationOutcome();
            result.Issue.Add(new OperationOutcome.IssueComponent
            {
                Severity = OperationOutcome.IssueSeverity.Error,
                Details = new CodeableConcept
                {
                    Text = output
                },
                Code = OperationOutcome.IssueType.Processing
            });

            return result;
        }

        // credit: https://github.com/dotnet/runtime/issues/13051#issuecomment-514774802
        public static class Extensions
        {
            [System.Runtime.InteropServices.DllImport("kernel32.dll")]
            static extern uint GetModuleFileName(IntPtr hModule, System.Text.StringBuilder lpFilename, int nSize);
            const int MAX_PATH = 255;
            // reports the location of our application when running from Hammer.exe and the like
            private static string GetExecutablePath()
            {
                if (System.Runtime.InteropServices.RuntimeInformation.IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
                {
                    var sb = new System.Text.StringBuilder(MAX_PATH);
                    GetModuleFileName(IntPtr.Zero, sb, MAX_PATH);
                    return Path.GetDirectoryName(sb.ToString());
                }
                else
                {
                    return Path.GetDirectoryName(System.Diagnostics.Process.GetCurrentProcess().MainModule.FileName);
                }
            }

            // reports the location of our application when running from Hammer.dll
            private static string GetDllPath()
            {
                return Path.GetDirectoryName(Assembly.GetEntryAssembly()?.Location);
            }

            public static string GetApplicationLocation()
            {
                string executablePath = GetExecutablePath();
                string dllPath = GetDllPath();

                return (File.Exists(Path.Combine(executablePath, "Main.qml"))) ? executablePath : dllPath;
            }
        }

        public OperationOutcome ValidateWithJava(CancellationToken token)
        {
            var resourcePath = SerializeResource(ResourceText, InstanceFormat);

            var validatorPath = Path.Combine(Extensions.GetApplicationLocation(), "org.hl7.fhir.validator.jar");
            var scopeArgument = string.IsNullOrEmpty(ScopeDirectory) ? "" : $" -ig \"{ScopeDirectory}\"";
            var outputJson = $"{Path.GetTempFileName()}.json";
            var finalArguments = $"-jar {validatorPath} -version {(FhirVersion == "STU3" ? "3.0" : "4.0")} -tx \"{getJavaTxString()}\"{scopeArgument} -output {outputJson} {resourcePath}";
            Console.WriteLine($"Beginning Java validation: java {finalArguments}");

            OperationOutcome result;

            var sw = new Stopwatch();
            sw.Start();
            string validatorOutput, resultText;
            using var validator = new Process();

            _validatorProcesses.Add(validator);

            validator.StartInfo.FileName = "java";
            validator.StartInfo.Arguments = finalArguments;
            validator.StartInfo.UseShellExecute = false;
            validator.StartInfo.RedirectStandardOutput = true;
            validator.StartInfo.RedirectStandardError = true;
            validator.StartInfo.CreateNoWindow = true;

            try
            {
                validator.Start();
                validatorOutput = validator.StandardOutput.ReadToEnd();
                validatorOutput += validator.StandardError.ReadToEnd();
                validator.WaitForExit();
            }
            catch (Exception ex)
            {
                result = new OperationOutcome();
                if (ex.Message == "The system cannot find the file specified" ||
                    ex.Message == "No such file or directory")
                {
                    result.Issue.Add(new OperationOutcome.IssueComponent
                    {
                        Severity = OperationOutcome.IssueSeverity.Error,
                        Diagnostics = AppModel.Instance.NoJavaInstall,
                        Code = OperationOutcome.IssueType.Exception
                    });
                }
                else
                {
                    result.Issue.Add(new OperationOutcome.IssueComponent
                    {
                        Severity = OperationOutcome.IssueSeverity.Error,
                        Diagnostics = ex.Message,
                        Code = OperationOutcome.IssueType.Exception
                    });
                }

                sw.Stop();
                _validatorProcesses.Remove(validator);
                Console.WriteLine($"Java validation performed in {sw.ElapsedMilliseconds}ms");
                return result;
            }

            sw.Stop();
            _validatorProcesses.Remove(validator);
            token.ThrowIfCancellationRequested();
            Console.WriteLine($"Java validation performed in {sw.ElapsedMilliseconds}ms");

            if (validator.ExitCode != 0 || !File.Exists(outputJson))
            {
                // JavaValidationCrashed = true;
                return ConvertJavaStdout(validatorOutput);
            }

            resultText = File.ReadAllText(outputJson);

            var parser = new stu3.Hl7.Fhir.Serialization.FhirJsonParser();
            try
            {
                result = parser.Parse<OperationOutcome>(resultText);
            }
            catch (FormatException fe)
            {
                result = new OperationOutcome();
                result.Issue.Add(new OperationOutcome.IssueComponent
                {
                    Severity = OperationOutcome.IssueSeverity.Error,
                    Diagnostics = fe.InnerException.InnerException.Message,
                    Code = OperationOutcome.IssueType.Exception
                });
            }

            return result;
        }

        public async void StartValidation()
        {
            CancelValidation();
            ResetResults();
            ValidatingDotnet = true;
            ValidatingJava = true;
            this.ActivateSignal("validationStarted");

            // Create a new CancellationTokenSource that can be used to signal to the
            // tasks that we want to cancel them.
            _validatorCancellationSource = new CancellationTokenSource();
            CancellationToken token = _validatorCancellationSource.Token;
            // () wrapper so older MS Build (15.9.20) works
            Task<OperationOutcome> validateWithJava = Task.Run(() => ValidateWithJava(token), token);
            Task<OperationOutcome> validateWithDotnet = Task.Run(() => ValidateWithDotnet(token), token);

            var allTasks = new List<Task> { validateWithJava, validateWithDotnet };
            while (allTasks.Any())
            {
                try
                {
                    var finished = await Task.WhenAny(allTasks);
                    if (finished == validateWithJava)
                    {
                        allTasks.Remove(validateWithJava);
                        var result = await validateWithJava;
                        JavaIssues = convertIssues(result.Issue);
                        ValidatingJava = false;
                    }
                    else if (finished == validateWithDotnet)
                    {
                        allTasks.Remove(validateWithDotnet);
                        var result = await validateWithDotnet;
                        DotnetIssues = convertIssues(result.Issue);
                        ValidatingDotnet = false;
                    }
                    else
                    {
                        allTasks.Remove(finished);
                    }
                }
                catch (OperationCanceledException)
                {
                    // When we signalled to cancel the validation, the
                    // OperationCanceledException is thrown whenever we await the task.
                    // This prevents processing the results, effectively decoupling the
                    // task. We don't need to handle the exception itself.
                }
                catch (Exception)
                {
                    ValidatingJava = false;
                    ValidatingDotnet = false;
                }
            }
        }

        // load examples. This should be done syncronously: https://ux.stackexchange.com/q/138673/108628
        // but if it can be made quicker, then even better
        public void LoadExamples()
        {
            JArray jsonExamples = JArray.Parse(File.ReadAllText(Path.Combine(AppModel.Extensions.GetApplicationLocation(), "assets", "examples", "metadata.json")));

            Examples = new List<Example>();
            foreach (JToken jsonExample in jsonExamples)
            {
                var diskExample = jsonExample.ToObject<DiskExample>();
                var example = new Example {
                    Filepath = $"file://{Path.Combine(AppModel.Extensions.GetApplicationLocation(), "assets", "examples", diskExample.Filename)}",
                    Title = diskExample.Title,
                    Description = diskExample.Description,

                };
                Examples.Add(example);
            }
            this.ActivateSignal("examplesLoaded");
        }

        public void CancelValidation()
        {
            // Signal the CancellationToken in the tasks that we want to cancel.
            if (_validatorCancellationSource != null)
            {
                _validatorCancellationSource.Cancel();
                _validatorCancellationSource.Dispose();
            }
            _validatorCancellationSource = null;

            // We can actively kill the Java validator as this is an external
            // process. The .NET validator needs to run its course until completion,
            // we'll just ignore the results.
            foreach (var process in _validatorProcesses)
            {
                process.Kill();
            }

            ValidatingDotnet = false;
            ValidatingJava = false;
        }

        public async void CheckForUpdates()
        {
            Debug.WriteLine($"Currently running Hammer v{ApplicationVersion}. Checking for updates...");

            string releases = await GetRepoReleases();
            if (String.IsNullOrEmpty(releases))
            {
                return;
            }

            var latestVersion = ExtractLatestVersion(releases);

            if (latestVersion == null)
            {
                return;
            }

            Version currentVersion = Version.Parse(ApplicationVersion);
            if (latestVersion > currentVersion)
            {
                Console.WriteLine($"Newer version available: {latestVersion}");
                this.ActivateSignal("updateAvailable", latestVersion.ToString());
            }
            else
            {
                Console.WriteLine($"No newer version available; latest released on Github is {latestVersion}.");
            }
        }

        public Version ExtractLatestVersion(string repoTagsRaw)
        {
            var repoTags = JArray.Parse(repoTagsRaw);

            if (!repoTags.Any())
            {
                Console.WriteLine($"No releases found over at {RepoOrg}/{RepoName}.");
                return null;
            }

            string latestReleaseName = (string)repoTags.SelectTokens("$[?(@.draft == false && @.prerelease == false)].tag_name").FirstOrDefault();

            var matches = ExtractReleaseVersion(latestReleaseName);
            if (!matches.Any())
            {
                Console.WriteLine($"Couldn't parse downloaded release '{latestReleaseName}' to extract the version.");
                return null;
            }
            var latestReleaseVersion = matches.First().Groups[1].ToString().Trim();

            Version latestVersion;
            if (!Version.TryParse(latestReleaseVersion, out latestVersion))
            {
                Console.WriteLine($"Couldn't parse latest downloaded version '{latestReleaseVersion}' into structured data.");
            }
            return latestVersion;
        }

        public async Task<string> GetRepoReleases()
        {
            using var client = new HttpClient();
            string url = $"https://api.github.com/repos/{RepoOrg}/{RepoName}/releases";

            using var requestMessage = new HttpRequestMessage(HttpMethod.Get, url);
            requestMessage.Headers.Add("User-Agent", $"{RepoOrg}/{RepoName}");
            HttpResponseMessage response;
            try
            {
                response = await client.SendAsync(requestMessage);
            }
            catch (Exception exception)
            {
                Console.WriteLine($"Failed to download latest Hammer releases: {exception.Message}");
                return null;
            }

            string content = await response.Content.ReadAsStringAsync();
            return content;
        }
    }

    /// <summary>
    /// Helper class to handle the CLI options and arguments.
    /// It is based on the CommandLine library.
    /// </summary>
    public class CLIParser
    {
        private readonly ParserResult<CLIOptions> _cliOptions;

        /// <summary>
        /// Data storage class to store the command line options and arguments.
        /// </summary>
        public class CLIOptions
        {
            [Option('s', "scopedir", Required = false, HelpText = "Set the scope directory")]
            public string ScopeDir
            {
                get;
                set;
            }

            [Value(0, MetaName = "resource_file", HelpText = "The resource file to validate")]
            public string ResourceFile
            {
                get;
                set;
            }

            /// <summary>
            /// Understand Squirrel's first launch argument in order to launch right after install on Windows
            /// </summary>
            [Option("squirrel-firstrun", Hidden = true)]
            public bool SquirrelFirstRun
            {
                get;
                set;
            }
        }

        /// <summary>
        /// Instantiate with the arguments from the command line.
        /// <param name="args">The list of command line arguments as passed to the application</param>
        /// </summary>
        public CLIParser(string[] args)
        {
            _cliOptions = Parser.Default.ParseArguments<CLIOptions>(args);
        }

        public bool ParsedSuccessfully
        {
            get
            {
                var success = true;
                _cliOptions.WithNotParsed(errors => success = false);
                return success;
            }
        }

        /// <summary>
        /// Perform the actions specified by the command line.
        /// </summary>
        public void Process()
        {
            _cliOptions.WithParsed(result =>
            {
                AppModel.Instance.AnimateQml = false;

                if (result.ScopeDir != null)
                {
                    var scopeUri = new System.Uri(System.IO.Path.GetFullPath(result.ScopeDir));
                    AppModel.Instance.LoadScopeDirectory(scopeUri.ToString());
                }
                if (result.ResourceFile != null)
                {
                    var resourceUri = new System.Uri(System.IO.Path.GetFullPath(result.ResourceFile));
                    if (AppModel.Instance.LoadResourceFile(resourceUri.ToString()))
                    {
                        AppModel.Instance.StartValidation();
                    }
                }

                AppModel.Instance.AnimateQml = true;
            });
        }
    }

    static int Main(string[] args)
    {
        // support searching multiple locations in case more are needed in the future. Originally added for nuget,
        // but getting the Qt runtime into nuget is an issue
        List<string> qtRuntimes = new List<string>{ Path.Combine(AppModel.Extensions.GetApplicationLocation(), "qt-runtime") };

        var foundRuntime = false;
        foreach (var runtime in qtRuntimes)
        {
            if (Directory.Exists(runtime))
            {
                Console.WriteLine($"Using embedded Qt runtime from {runtime}");
                RuntimeManager.ConfigureRuntimeDirectory(runtime);
                foundRuntime = true;
            }
        }

        if (!foundRuntime)
        {
            if (string.IsNullOrEmpty(RuntimeManager.FindSuitableQtRuntime())) {
                Console.WriteLine($"Performing first-time setup, this'll take a couple of minutes...");
            }
            // downloaded to ~/.qmlnet-qt-runtimes by default
            RuntimeManager.DiscoverOrDownloadSuitableQtRuntime();
        }

        QQuickStyle.SetStyle("Universal");
        QCoreApplication.SetAttribute(ApplicationAttribute.EnableHighDpiScaling, true);

        using var app = new QGuiApplication(args);
        using var engine = new QQmlApplicationEngine();

        // We first need to register the AppModel type in QML in order to have
        // an instance that we can work on programmatically.
        Qml.Net.Qml.RegisterType<AppModel>("appmodel");

        // Now we can check command line options to see if we should bail
        // out before we start rendering the interface.
        var cliParser = new CLIParser(args);
        if (!cliParser.ParsedSuccessfully)
        {
            return 1;
        }

        // Now we can load the GUI
        QCoreApplication.OrganizationDomain = "Hammer.mc";
        QCoreApplication.OrganizationName = "Hammer";
        engine.Load(Path.Combine(AppModel.Extensions.GetApplicationLocation(), "Main.qml"));

        // Once the GUI is loaded, we can start working with the AppModel
        // instance.
        cliParser.Process();

        AppModel.Instance.LoadExamples();

        AppModel.Instance.CheckForUpdates();

        return app.Exec();
    }
}
