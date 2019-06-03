using System;
using System.IO;
using Qml.Net;
using Qml.Net.Runtimes;
using Hl7.Fhir.ElementModel;
using Hl7.Fhir.Model;
using Hl7.Fhir.Rest;
using Hl7.Fhir.Serialization;
using Hl7.Fhir.Specification.Navigation;
using Hl7.Fhir.Specification.Source;
using Hl7.Fhir.Specification.Terminology;
using Hl7.Fhir.Validation;
using System.Collections.Concurrent;
using System.Collections.Generic;
using System.Diagnostics;
using System.Linq;
using System.Threading.Tasks.Dataflow;
using System.Xml.Linq;
// using Furore.Fhir.ValidationDemo.Properties;
using Hl7.Fhir.Support;
using Hl7.Fhir.Utility;
using System.Threading.Tasks;

class Program
{
  public class AppModel
  {
    private static AppModel _instance;
    public static AppModel Instance => _instance ?? (_instance = new AppModel());

    public static bool HasInstance => _instance != null;

    public AppModel()
    {
      _instance = this;
    }

    private IResourceResolver CoreSource = new CachedResolver(ZipSource.CreateValidationSource());

    private IResourceResolver CombinedSource;

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
        CombinedSource = new MultiResolver(directorySource, CoreSource);
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

    private void resetResults()
    {
      JavaResult = new ValidationResult { ValidatorType = ValidatorType.Java };
      DotnetResult = new ValidationResult { ValidatorType = ValidatorType.Dotnet };
      JavaValidationCrashed = false;
    }

    private void setOutcome(OperationOutcome outcome, ValidatorType type)
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

    public enum ValidatorType { Dotnet = 1, Java = 2 };

    public class ValidationResult {
      private ValidatorType _validatorType;
      [NotifySignal]
      public ValidatorType ValidatorType
        { get => _validatorType; set => this.SetProperty(ref _validatorType, value); }

      private List<AppModel.Issue> _issues
        = new List<AppModel.Issue> { };

      [NotifySignal]
      public List<AppModel.Issue> Issues
      {
        get => _issues;
        set => this.SetProperty(ref _issues, value);
      }

      private int _errorCount = 0;
      [NotifySignal]
      public int ErrorCount
        { get => _errorCount; set => this.SetProperty(ref _errorCount, value); }

      private int _warningCount = 0;
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

    public Hl7.Fhir.Rest.ResourceFormat InstanceFormat
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

    private List<AppModel.Issue> convertIssues(List<Hl7.Fhir.Model.OperationOutcome.IssueComponent> issues)
    {
      List<AppModel.Issue> convertedIssues = new List<AppModel.Issue> { };

      foreach (var issue in issues)
      {
        convertedIssues.Add(new AppModel.Issue
        {
          Severity = issue.Severity.ToString().ToLower(),
          Text = issue.Details?.Text ?? "(no details)",
          Location = String.Join(" via ", issue.Location)
        });
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
      if (!text.StartsWith("file://")) {
        ResourceText = text;
        return;
      }

      var filePath = text;
      if (System.Runtime.InteropServices.RuntimeInformation
        .IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows)) {
        filePath = filePath.RemovePrefix("file:///");
      } else {
        filePath = filePath.RemovePrefix("file://");
      }
      filePath = filePath.Replace("\r", "").Replace("\n", "");
      filePath = System.Uri.UnescapeDataString(filePath);
      Console.WriteLine($"Loading '{filePath}'...");
      ResourceText = System.IO.File.ReadAllText(filePath);

      ScopeDirectory = System.IO.Path.GetDirectoryName(filePath);
    }

    public void LoadScopeDirectory(string text)
    {
      // input already pruned - accept as-is
      if (!text.StartsWith("file://")) {
        ScopeDirectory = text;
        return;
      }

      var filePath = text;
      if (System.Runtime.InteropServices.RuntimeInformation
        .IsOSPlatform(System.Runtime.InteropServices.OSPlatform.Windows))
      {
        filePath = filePath.RemovePrefix("file:///");
      }
      else
      {
        filePath = filePath.RemovePrefix("file://");
      }
      filePath = filePath.Replace("\r", "").Replace("\n", "");
      filePath = System.Uri.UnescapeDataString(filePath);
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

    public OperationOutcome ValidateWithDotnet()
    {
      Console.WriteLine("Beginning .NET validation");
      try
      {
        var settings = new ValidationSettings()
        {
          ResourceResolver = CombinedSource != null ? CombinedSource : CoreSource,
          GenerateSnapshot = true,
          EnableXsdValidation = true,
          Trace = false,
          ResolveExteralReferences = true
        };

        var validator = new Validator(settings);
        // validator.OnExternalResolutionNeeded += onGetExampleResource;

        // In this case we use an XmlReader as input, but the validator has
        // overloads for using POCO's too
        Stopwatch sw = new Stopwatch();
        OperationOutcome result = null;

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

    private string SerializeResource(string ResourceText, Hl7.Fhir.Rest.ResourceFormat InstanceFormat)
    {
      var fileName = $"{Path.GetTempFileName()}.{(InstanceFormat == ResourceFormat.Json ? "json" : "xml")}";
      System.IO.File.WriteAllText(fileName, ResourceText);

      return fileName;
    }

    // in case the Java validator crashes (which it can if it doesn't like something)
    // it won't produce an OperationOutcome for us. Take what we've got and make one ourselves
    private OperationOutcome ConvertJavaStdout(string output)
    {
      var result = new OperationOutcome();
      using (var reader = new StringReader(output))
      {
        for (string line = reader.ReadLine(); line != null; line = reader.ReadLine())
        {
          result.Issue.Add(new OperationOutcome.IssueComponent
          {
            Severity = OperationOutcome.IssueSeverity.Error,
            Details = new CodeableConcept() {
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

      var validatorPath = Path.Combine(System.IO.Path.GetDirectoryName(System.Reflection.Assembly.GetEntryAssembly().Location),
        "org.hl7.fhir.validator.jar");
      var scopePath = ScopeDirectory;
      var outputJson = $"{Path.GetTempFileName()}.json";
      var finalArguments = $"-jar {validatorPath} -version 3.0 -tx n/a -ig {scopePath} -output {outputJson} {resourcePath}";


      var sw = new Stopwatch();
      sw.Start();
      string validatorOutput, resultText;
      using (Process validator = new Process())
      {
        validator.StartInfo.FileName = "java";
        validator.StartInfo.Arguments = finalArguments;
        validator.StartInfo.UseShellExecute = false;
        validator.StartInfo.RedirectStandardOutput = true;
        validator.StartInfo.RedirectStandardError = true;
        validator.Start();
        validator.WaitForExit();
        validatorOutput = validator.StandardOutput.ReadToEnd();
        validatorOutput += validator.StandardError.ReadToEnd();

        sw.Stop();
        Console.WriteLine($"Java validation performed in {sw.ElapsedMilliseconds}ms");

        if (validator.ExitCode != 0 || !System.IO.File.Exists(outputJson))
        {
          // JavaValidationCrashed = true;
          return ConvertJavaStdout(validatorOutput);
        }
        else
        {
          resultText = System.IO.File.ReadAllText(outputJson);
        }
      }

      var parser = new FhirJsonParser();
      OperationOutcome result;
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
      resetResults();
      ValidatingDotnet = true;
      ValidatingJava = true;
      // () wrapper so older MS Build (15.9.20) works
      Task<OperationOutcome> validateWithJava = System.Threading.Tasks.Task.Run(() => ValidateWithJava());
      // .ContinueWith(System.Threading.Tasks.Task <OperationOutcome> t =>
      // {
      //   setOutcome(t.Result, ValidatorType.Java);
      //   ValidatingJava = false;
      // });
      // TaskScheduler.FromCurrentSynchronizationContext()
      Task<OperationOutcome> validateWithDotnet = System.Threading.Tasks.Task.Run(() => ValidateWithDotnet());

      var allTasks = new List<System.Threading.Tasks.Task> { validateWithJava, validateWithDotnet };
      while (allTasks.Any())
      {
        var finished = await System.Threading.Tasks.Task.WhenAny(allTasks);
        if (finished == validateWithJava)
        {
          allTasks.Remove(validateWithJava);
          var result = await validateWithJava;
          setOutcome(result, ValidatorType.Java);
          ValidatingJava = false;
        }
        else if (finished == validateWithDotnet)
        {
          allTasks.Remove(validateWithDotnet);
          var result = await validateWithDotnet;
          setOutcome(result, ValidatorType.Dotnet);
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
    QGuiApplication.SetAttribute(Qml.Net.ApplicationAttribute.EnableHighDpiScaling, true);

    using (var app = new QGuiApplication(args))
    {
      using (var engine = new QQmlApplicationEngine())
      {
        Qml.Net.Qml.RegisterType<AppModel>("appmodel", 1, 0);

        engine.Load("Main.qml");

        QCoreApplication.OrganizationDomain = "domain";
        QCoreApplication.OrganizationName = "name";

        return app.Exec();
      }
    }
  }
}
