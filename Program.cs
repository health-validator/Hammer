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
using Hl7.Fhir.Model;
using Hl7.Fhir.Rest;
using Hl7.Fhir.Serialization;
using Hl7.Fhir.Specification.Source;
using Hl7.Fhir.Specification.Terminology;
using Hl7.Fhir.Utility;
using Hl7.Fhir.Validation;
using Hl7.Fhir.ElementModel;
using Qml.Net;
using Qml.Net.Runtimes;
using Hl7.FhirPath;
using TextCopy;
using Task = System.Threading.Tasks.Task;

class Program
{
  [Signal("validationStarted")]
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
      if (_validatorCancellationSource != null) {
        _validatorCancellationSource.Dispose();
        _validatorCancellationSource = null;
      }
      GC.SuppressFinalize(this);
    }

    private readonly IResourceResolver _coreSource = new CachedResolver(ZipSource.CreateValidationSource());

    private IResourceResolver _combinedSource;

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

    private string _scopeDirectory;
    [NotifySignal]
    public string ScopeDirectory
    {
      get => _scopeDirectory;
      set
      {
        if (_scopeDirectory == value)
        {
          return;
        }

        _scopeDirectory = value;
        this.ActivateProperty(x => x.ScopeDirectory);

        var directorySource = new CachedResolver(
          new DirectorySource(_scopeDirectory, new DirectorySourceSettings { IncludeSubDirectories = true }));

        // Finally, we combine both sources, so we will find profiles both from the core zip as well as from the directory.
        // By mentioning the directory source first, anything in the user directory will override what is in the core zip.
        _combinedSource = new MultiResolver(directorySource, _coreSource);
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
        if (_resourceFont == value) {
          return;
        }

        _resourceFont = value;
        this.ActivateProperty(x => x.ResourceFont);
      }
    }

    private string _terminologyService = "http://tx.fhir.org";
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
        this.ActivateProperty(x => x._terminologyService);
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

    private int _javaErrorCount;
    [NotifySignal]
    public int JavaErrorCount {
      get => _javaErrorCount;
      set => this.SetProperty(ref _javaErrorCount, value);
    }

    private int _javaWarningCount;
    [NotifySignal]
    public int JavaWarningCount {
      get => _javaWarningCount;
      set => this.SetProperty(ref _javaWarningCount, value);
    }

    private List<Issue> _javaIssues = new List<Issue>();
    [NotifySignal]
    public List<Issue> JavaIssues {
      get => _javaIssues;
      set => this.SetProperty(ref _javaIssues, value);
    }

    private int _dotnetErrorCount;
    [NotifySignal]
    public int DotnetErrorCount {
      get => _dotnetErrorCount;
      set => this.SetProperty(ref _dotnetErrorCount, value);
    }

    private int _dotnetWarningCount;
    [NotifySignal]
    public int DotnetWarningCount {
      get => _dotnetWarningCount;
      set => this.SetProperty(ref _dotnetWarningCount, value);
    }
    
    private List<Issue> _dotnetIssues = new List<Issue>();
    [NotifySignal]
    public List<Issue> DotnetIssues {
      get => _dotnetIssues;
      set => this.SetProperty(ref _dotnetIssues, value);
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
    public bool AnimateQml {
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
    
    private ITypedElement _parsedResource;
    
    private CancellationTokenSource _validatorCancellationSource;
    
    private readonly List<Process> _validatorProcesses = new List<Process>();

    private void ResetResults()
    {
      JavaErrorCount     = 0;
      JavaWarningCount   = 0;
      JavaIssues         = new List<Issue>();
      DotnetErrorCount   = 0;
      DotnetWarningCount = 0;
      DotnetIssues       = new List<Issue>();
      JavaValidationCrashed = false;
    }

    private void SetOutcome(OperationOutcome outcome, ValidatorType type)
    {
      if (type == ValidatorType.Java) {
        JavaResult = new ValidationResult
        {
          ValidatorType = type,
          Issues = convertIssues(outcome.Issue),
          WarningCount = outcome.Warnings,
          ErrorCount = outcome.Errors + outcome.Fatals
        };
        // warnings have to be set before errors for some reason, otherwise not transferred to QML
      } else {
        DotnetResult = new ValidationResult
        {
          ValidatorType = type,
          Issues = convertIssues(outcome.Issue),
          WarningCount = outcome.Warnings,
          ErrorCount = outcome.Errors + outcome.Fatals
        };
        // warnings have to be set before errors for some reason, otherwise not transferred to QML
      }

      // Console.WriteLine(outcome.ToString());
    }

    public enum ValidatorType { Dotnet = 1, Java = 2 }

    public class ValidationResult {
      private ValidatorType _validatorType;
      [NotifySignal]
      public ValidatorType ValidatorType
        { get => _validatorType; set => this.SetProperty(ref _validatorType, value); }

      private List<Issue> _issues
        = new List<Issue>();

      [NotifySignal]
      public List<Issue> Issues
      {
        get => _issues;
        set => this.SetProperty(ref _issues, value);
      }

      private int _errorCount;
      [NotifySignal]
      public int ErrorCount
        { get => _errorCount; set => this.SetProperty(ref _errorCount, value); }

      private int _warningCount;
      [NotifySignal]
      public int WarningCount
        { get => _warningCount; set => this.SetProperty(ref _warningCount, value); }
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

        var serializationDetails = GetPositionInfo(issue);
        if (serializationDetails == null) { continue; }
        
        simplifiedIssue.LineNumber = serializationDetails.LineNumber;
        simplifiedIssue.LinePosition = serializationDetails.LinePosition;
      }

      return convertedIssues;
    }

    private IPositionInfo GetPositionInfo(OperationOutcome.IssueComponent issue)
    {
      IPositionInfo serializationDetails;
      
      if (!issue.Location.Any()) { return null; }
      var location = SanitizeLocation(issue.Location.First());
      if (location == null) { return null; }

      List<ITypedElement> elementWithError = null;
      try
      {
        elementWithError = _parsedResource.Select(location).ToList();
      }
      catch (FormatException)
      {
        // if the FHIRPath is invalid, don't return position info for it
      }

      if (elementWithError == null || !elementWithError.Any()) { return null; }
      
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
      if (!matches.Any()) { return null; }
      var location = matches.First().Groups[0].ToString().Trim();
      return location;
    }

    public bool LoadResourceFile(string text)
    {
      if (text == null) {
        Console.Error.WriteLine("LoadResourceFile: no text passed");
        return false;
      }

      // input already pruned - accept as-is
      if (!text.StartsWith("file://", StringComparison.InvariantCulture)) {
        ResourceText = text;
        return true;
      }

      var filePath = text;
      filePath = filePath.RemovePrefix(RuntimeInformation
        .IsOSPlatform(OSPlatform.Windows) ? "file:///" : "file://");
      filePath = filePath.Replace("\r", "", StringComparison.InvariantCulture)
        .Replace("\n", "", StringComparison.InvariantCulture);
      filePath = Uri.UnescapeDataString(filePath);
      Console.WriteLine($"Loading '{filePath}'...");

      if (!File.Exists(filePath)) {
        Console.WriteLine($"File to load doesn't actually exist: {filePath}");
        return false;
      }

      ResourceText = File.ReadAllText(filePath);
      if (ScopeDirectory == null) {
        ScopeDirectory = Path.GetDirectoryName(filePath);
      }

      return true;
    }

    public void LoadScopeDirectory(string text)
    {
      // input already pruned - accept as-is
      if (!text.StartsWith("file://", StringComparison.InvariantCulture)) {
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

    public void CopyValidationReport()
    {
      using (var writer = new StringWriter())
      using (var csv = new CsvWriter(writer))
      {
        // write fields out manually since we need to add the engine type column
        csv.WriteField("Severity");
        csv.WriteField("Text");
        csv.WriteField("Location");
        csv.WriteField("Validator engine");
        csv.NextRecord();

        foreach (var issue in DotnetIssues) {
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

        Clipboard.SetText(writer.ToString());
      }
    }

    public OperationOutcome ValidateWithDotnet(CancellationToken token)
    {
      Console.WriteLine("Beginning .NET validation");
      try
      {
        var externalTerminology = new ExternalTerminologyService(new FhirClient(TerminologyService));
        var localTerminology = new LocalTerminologyService(_combinedSource ?? _coreSource);
        var summaryProvider = new Hl7.Fhir.Specification.StructureDefinitionSummaryProvider(_combinedSource ?? _coreSource);
        var combinedTerminology = new FallbackTerminologyService(localTerminology, externalTerminology);

        var settings = new ValidationSettings
        {
          ResourceResolver = _combinedSource ?? _coreSource,
          GenerateSnapshot = true,
          EnableXsdValidation = true,
          Trace = false,
          ResolveExteralReferences = true,
          TerminologyService = combinedTerminology
        };

        var validator = new Validator(settings);
        // validator.OnExternalResolutionNeeded += onGetExampleResource;

        // In this case we use an XmlReader as input, but the validator has
        // overloads for using POCO's too
        Stopwatch sw = new Stopwatch();
        OperationOutcome result;

        sw.Start();
        if (InstanceFormat == ResourceFormat.Xml)
        {
          _parsedResource = FhirXmlNode.Parse(ResourceText, new FhirXmlParsingSettings { PermissiveParsing = true })
            .ToTypedElement(summaryProvider);
        }
        else if (InstanceFormat == ResourceFormat.Json)
        {
          _parsedResource = FhirJsonNode.Parse(ResourceText, settings: new FhirJsonParsingSettings { AllowJsonComments = true })
            .ToTypedElement(summaryProvider);
        }
        else
        {
          throw new Exception("This resource format isn't recognised");
        }
        
        result = validator.Validate(_parsedResource);
        sw.Stop();
        token.ThrowIfCancellationRequested();
        Console.WriteLine($".NET validation performed in {sw.ElapsedMilliseconds}ms");
        
        return result;
      }
      catch (OperationCanceledException) {
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

        return result;
      }
    }

    private string SerializeResource(string resourceText, ResourceFormat instanceFormat)
    {
      var fileName = $"{Path.GetTempFileName()}.{(instanceFormat == ResourceFormat.Json ? "json" : "xml")}";
      File.WriteAllText(fileName, resourceText);

      return fileName;
    }

    // in case the Java validator crashes (which it can if it doesn't like something)
    // it won't produce an OperationOutcome for us. Take what we've got and make one ourselves
    private OperationOutcome ConvertJavaStdout(string output)
    {
      var result = new OperationOutcome();
      using (var reader = new StringReader(output))
      {
        for (var line = reader.ReadLine(); line != null; line = reader.ReadLine())
        {
          result.Issue.Add(new OperationOutcome.IssueComponent
          {
            Severity = OperationOutcome.IssueSeverity.Error,
            Details = new CodeableConcept
            {
              Text = line
            },
            Code = OperationOutcome.IssueType.Processing
          });
        }
      }

      return result;
    }

    public OperationOutcome ValidateWithJava(CancellationToken token)
    {
      Console.WriteLine("Beginning Java validation");
      var resourcePath = SerializeResource(ResourceText, InstanceFormat);

      var validatorPath = Path.Combine(Path.GetDirectoryName(Assembly.GetEntryAssembly()?.Location),
        "org.hl7.fhir.validator.jar");
      var scopeArgument = string.IsNullOrEmpty(ScopeDirectory) ? "" :  $" -ig \"{ScopeDirectory}\"";
      var outputJson = $"{Path.GetTempFileName()}.json";
      var finalArguments = $"-jar {validatorPath} -version 3.0 -tx \"{TerminologyService}\"{scopeArgument} -output {outputJson} {resourcePath}";


      OperationOutcome result;

      var sw = new Stopwatch();
      sw.Start();
      string validatorOutput, resultText;
      using (var validator = new Process())
      {
        _validatorProcesses.Add(validator);

        validator.StartInfo.FileName = "java";
        validator.StartInfo.Arguments = finalArguments;
        validator.StartInfo.UseShellExecute = false;
        validator.StartInfo.RedirectStandardOutput = true;
        validator.StartInfo.RedirectStandardError = true;

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
            if (ex.Message == "The system cannot find the file specified")
            {
                result.Issue.Add(new OperationOutcome.IssueComponent
                {
                    Severity = OperationOutcome.IssueSeverity.Error,
                    Diagnostics = "Java could not be found. Is your Java installed and working correctly? See https://www.java.com/en/download/help/version_manual.xml",
                    Code = OperationOutcome.IssueType.Exception
                });
            } else {
                result.Issue.Add(new OperationOutcome.IssueComponent
                {
                    Severity = OperationOutcome.IssueSeverity.Error,
                    Diagnostics = ex.Message,
                    Code = OperationOutcome.IssueType.Exception
                });
            }

            sw.Stop();
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
      }

      var parser = new FhirJsonParser();
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
        try {
          var finished = await Task.WhenAny(allTasks);
          if (finished == validateWithJava)
          {
            allTasks.Remove(validateWithJava);
            var result = await validateWithJava;
            JavaErrorCount   = result.Errors + result.Fatals;
            JavaWarningCount = result.Warnings;
            JavaIssues       = convertIssues(result.Issue);
            SetOutcome(result, ValidatorType.Java);
            ValidatingJava = false;
          }
          else if (finished == validateWithDotnet)
          {
            allTasks.Remove(validateWithDotnet);
            var result = await validateWithDotnet;
            DotnetErrorCount   = result.Errors + result.Fatals;
            DotnetWarningCount = result.Warnings;
            DotnetIssues       = convertIssues(result.Issue);
            SetOutcome(result, ValidatorType.Dotnet);
            ValidatingDotnet = false;
          }
          else
          {
            allTasks.Remove(finished);
          }
        } catch (OperationCanceledException) {
          // When we signalled to cancel the validation, the
          // OperationCanceledException is thrown whenever we await the task.
          // This prevents processing the results, effectively decoupling the
          // task. We don't need to handle the exception itself.
		    } catch (Exception) {
          ValidatingJava = false;
          ValidatingDotnet = false;
        }
      }
    }

    public void CancelValidation()
    {
      // Signal the CancellationToken in the tasks that we want to cancel.
      if (_validatorCancellationSource != null) {
        _validatorCancellationSource.Cancel();
        _validatorCancellationSource.Dispose();
      }
      _validatorCancellationSource = null;
      
      // We can actively kill the Java validator as this is an external
      // process. The .NET validator needs to run its course until completion,
      // we'll just ignore the results.
      foreach (var process in _validatorProcesses) {
        process.Kill();
      }

      ValidatingDotnet = false;
      ValidatingJava   = false;
    }
  }

  /// <summary>
  /// Helper class to handle the CLI options and arguments.
  /// It is based on the CommandLine library.
  /// </summary>
  public class CLIParser {
    private readonly ParserResult<CLIOptions> _cliOptions;

    /// <summary>
    /// Data storage class to store the command line options and arguments.
    /// </summary>
    public class CLIOptions
    {
      [Option('s', "scopedir", Required = false, HelpText = "Set the scope directory")]
      public string ScopeDir {get; set;}

      [Value(0, MetaName = "resource_file", HelpText = "The resource file to validate")]
      public string ResourceFile { get; set; }
    }

    /// <summary>
    /// Instantiate with the arguments from the command line.
    /// <param name="args">The list of command line arguments as passed to the application</param>
    /// </summary>
    public CLIParser(string[] args)
    {
      _cliOptions = Parser.Default.ParseArguments<CLIOptions>(args);
    }

    public bool ParsedSuccessfully {
      get {
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
      _cliOptions.WithParsed(result => {
        AppModel.Instance.AnimateQml = false;

        if (result.ScopeDir != null) {
          var scopeUri = new System.Uri(System.IO.Path.GetFullPath(result.ScopeDir));
          AppModel.Instance.LoadScopeDirectory(scopeUri.ToString());
        }
        if (result.ResourceFile != null) {
          var resourceUri = new System.Uri(System.IO.Path.GetFullPath(result.ResourceFile));
          if (AppModel.Instance.LoadResourceFile(resourceUri.ToString())) {
            AppModel.Instance.StartValidation();
          }
        }

        AppModel.Instance.AnimateQml = true;
      });
    }
  }

  static int Main(string[] args)
  {
    RuntimeManager.DiscoverOrDownloadSuitableQtRuntime();

    QQuickStyle.SetStyle("Universal");
    QCoreApplication.SetAttribute(ApplicationAttribute.EnableHighDpiScaling, true);

    using (var app = new QGuiApplication(args))
    {
      using (var engine = new QQmlApplicationEngine())
      {
        // We first need to register the AppModel type in QML in order to have
        // an instance that we can work on programmatically.
        Qml.Net.Qml.RegisterType<AppModel>("appmodel");

        // Now we can check command line options to see if we should bail
        // out before we start rendering the interface.
        var cliParser = new CLIParser(args);
        if (!cliParser.ParsedSuccessfully) {
          return 1;
        }

        // Now we can load the GUI
        engine.Load("Main.qml");

        // Once the GUI is loaded, we can start working with the AppModel
        // instance.
        cliParser.Process();

        return app.Exec();
      }
    }
  }
}
