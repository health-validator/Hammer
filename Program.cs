using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Diagnostics.CodeAnalysis;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Threading.Tasks;
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
  [SuppressMessage("ReSharper", "MemberCanBePrivate.Global")]
  public class AppModel
  {
    private static AppModel _instance;
    public static AppModel Instance => _instance ?? (_instance = new AppModel());

    public static bool HasInstance => _instance != null;

    public AppModel()
    {
      _instance = this;
    }

    private readonly IResourceResolver _coreSource = new CachedResolver(ZipSource.CreateValidationSource());

    private IResourceResolver _combinedSource;

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

    private bool _javaValidationCrashed;
    [NotifySignal]
    public bool JavaValidationCrashed
    {
      get => _javaValidationCrashed;
      set => this.SetProperty(ref _javaValidationCrashed, value);
    }
    #endregion

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

    private void ResetResults()
    {
      JavaResult = new ValidationResult { ValidatorType = ValidatorType.Java };
      DotnetResult = new ValidationResult { ValidatorType = ValidatorType.Dotnet };
      JavaValidationCrashed = false;
    }

    private void SetOutcome(OperationOutcome outcome, ValidatorType type)
    {
      if (type == ValidatorType.Java) {
        JavaResult = new ValidationResult { ValidatorType = type };
        JavaResult.Issues = convertIssues(outcome.Issue);
        // warnings have to be set before errors for some reason, otherwise not transferred to QML
        JavaResult.WarningCount = outcome.Warnings;
        JavaResult.ErrorCount = outcome.Errors + outcome.Fatals;
      } else {
        DotnetResult = new ValidationResult { ValidatorType = type };
        DotnetResult.Issues = convertIssues(outcome.Issue);
        // warnings have to be set before errors for some reason, otherwise not transferred to QML
        DotnetResult.WarningCount = outcome.Warnings;
        DotnetResult.ErrorCount = outcome.Errors + outcome.Fatals;
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
    }

    public void UpdateText(string newText)
    {
      ResourceText = newText;
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
        convertedIssues.Add(new Issue
        {
          Severity = issue.Severity.ToString().ToLowerInvariant(),
          Text = issue.Details?.Text ?? issue.Diagnostics ?? "(no details)",
          Location = String.Join(" via ", issue.Location)
        });

        var location = issue.Location.FirstOrDefault();
        if (location == null) {
          continue;
        }

        var resource = FhirJsonNode.Parse(ResourceText, settings: new FhirJsonParsingSettings { AllowJsonComments = true })
                .ToTypedElement(new Hl7.Fhir.Specification.StructureDefinitionSummaryProvider(_combinedSource ?? _coreSource));
        var result = resource.Select(location);

        if (!result.Any()) {
          continue;
        }

        // Console.WriteLine(result.FirstOrDefault().Annotation<IPositionInfo>().LineNumber);
        var nav = result.FirstOrDefault();
        Console.WriteLine($"{nav.GetJsonSerializationDetails().LineNumber}");
        // var posInfo = (nav as IAnnotated)?.Annotation<MedicationAdministration>();

        // if (posInfo != null) {
        //   Console.WriteLine(posInfo.LineNumber);
        // }
        // var posInfo = (nav as IAnnotated)?.Annotation<T>();
        // Assert.IsNotNull(posInfo);
        // Assert.AreNotEqual(-1, posInfo.LineNumber);
        // Assert.AreNotEqual(-1, posInfo.LinePosition);
        // Assert.AreNotEqual(0, posInfo.LineNumber);
        // Assert.AreNotEqual(0, posInfo.LinePosition);
      }

      return convertedIssues;
    }

    public void LoadResourceFile(string text)
    {
      if (text == null) {
        Console.Error.WriteLine("LoadResourceFile: no text passed");
        return;
      }

      // input already pruned - accept as-is
      if (!text.StartsWith("file://", StringComparison.InvariantCulture)) {
        ResourceText = text;
        return;
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
        return;
      }

      ResourceText = File.ReadAllText(filePath);
      if (ScopeDirectory == null) {
        ScopeDirectory = Path.GetDirectoryName(filePath);
      }
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

        foreach (var issue in DotnetResult.Issues) {
          csv.WriteField(issue.Severity);
          csv.WriteField(issue.Text);
          csv.WriteField(issue.Location);
          csv.WriteField(".NET");
          csv.NextRecord();
        }

        foreach (var issue in JavaResult.Issues)
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

    public OperationOutcome ValidateWithDotnet()
    {
      Console.WriteLine("Beginning .NET validation");
      try
      {
        var externalTerminology = new ExternalTerminologyService(new FhirClient(TerminologyService));
        var localTerminology = new LocalTerminologyService(_combinedSource ?? _coreSource);
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
          var reader = SerializationUtil.XmlReaderFromXmlText(ResourceText);
          result = validator.Validate(reader);
        }
        else
        {
          var poco = (new FhirJsonParser()).Parse<Resource>(ResourceText);
          result = validator.Validate(poco);
        }

        sw.Stop();
        Console.WriteLine($".NET validation performed in {sw.ElapsedMilliseconds}ms");
        return result;
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

    public OperationOutcome ValidateWithJava()
    {
      Console.WriteLine("Beginning Java validation");
      var resourcePath = SerializeResource(ResourceText, InstanceFormat);

      var validatorPath = Path.Combine(Path.GetDirectoryName(Assembly.GetEntryAssembly().Location),
        "org.hl7.fhir.validator.jar");
      var scopePath = ScopeDirectory;
      var outputJson = $"{Path.GetTempFileName()}.json";
      var finalArguments = $"-jar {validatorPath} -version 3.0 -tx \"{TerminologyService}\" -ig \"{scopePath}\" -output {outputJson} {resourcePath}";


      OperationOutcome result;

      var sw = new Stopwatch();
      sw.Start();
      string validatorOutput, resultText;
      using (var validator = new Process())
      {
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
            return result;
        }

        sw.Stop();
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
      ResetResults();
      ValidatingDotnet = true;
      ValidatingJava = true;
      // () wrapper so older MS Build (15.9.20) works
      Task<OperationOutcome> validateWithJava = Task.Run(() => ValidateWithJava());
      // .ContinueWith(System.Threading.Tasks.Task <OperationOutcome> t =>
      // {
      //   setOutcome(t.Result, ValidatorType.Java);
      //   ValidatingJava = false;
      // });
      // TaskScheduler.FromCurrentSynchronizationContext()
      Task<OperationOutcome> validateWithDotnet = Task.Run(() => ValidateWithDotnet());

      var allTasks = new List<Task> { validateWithJava, validateWithDotnet };
      while (allTasks.Any())
      {
        var finished = await Task.WhenAny(allTasks);
        if (finished == validateWithJava)
        {
          allTasks.Remove(validateWithJava);
          var result = await validateWithJava;
          SetOutcome(result, ValidatorType.Java);
          ValidatingJava = false;
        }
        else if (finished == validateWithDotnet)
        {
          allTasks.Remove(validateWithDotnet);
          var result = await validateWithDotnet;
          SetOutcome(result, ValidatorType.Dotnet);
          ValidatingDotnet = false;
        }
        else
        {
          allTasks.Remove(finished);
        }
      }
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
        Qml.Net.Qml.RegisterType<AppModel>("appmodel");
        engine.Load("Main.qml");

        return app.Exec();
      }
    }
  }
}
