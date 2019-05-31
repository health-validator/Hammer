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

    private int _errorCount = 0;
    [NotifySignal]
    public int ErrorCount
    {
      get => _errorCount;
      set => this.SetProperty(ref _errorCount, value);
    }

    private int _warningCount = 0;
    [NotifySignal]
    public int WarningCount
    {
      get => _warningCount;
      set => this.SetProperty(ref _warningCount, value);
    }

    private bool _validating;
    [NotifySignal]
    public bool Validating
    {
      get => _validating;
      set => this.SetProperty(ref _validating, value);
    }
    #endregion

    private void setOutcome(OperationOutcome outcome)
    {
      Issues = convertIssues(outcome.Issue);
      ErrorCount = outcome.Errors + outcome.Fatals;
      WarningCount = outcome.Warnings;
      Console.WriteLine(outcome.ToString());
    }

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

    private List<AppModel.Issue> _issues
      = new List<AppModel.Issue>{};

    [NotifySignal]
    public List<AppModel.Issue> Issues
    {
      get => _issues;
      set => this.SetProperty(ref _issues, value);
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

    public OperationOutcome Validate()
    {
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
        Console.WriteLine($"Validation performed in {sw.ElapsedMilliseconds}ms");
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

    public async void StartValidation()
    {
      Validating = true;
      var result = await System.Threading.Tasks.Task.Run(Validate);
      setOutcome(result);
      Validating = false;
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

        // using (Process compiler = new Process())
        // {
        //   compiler.StartInfo.FileName = "java";
        //   compiler.StartInfo.Arguments = "-jar /home/vadi/.m2/repository/ca/uhn/hapi/fhir/org.hl7.fhir.validation.cli/3.7.41-SNAPSHOT/org.hl7.fhir.validation.cli-3.7.41-SNAPSHOT.jar -version 3.0 -ig /home/vadi/Desktop/swedishnationalmedicationlist/swedishnationalmedicationlist.tgz -output /home/vadi/Desktop/output.json /home/vadi/Desktop/swedishnationalmedicationlist/MedicationRequest-example-bad.json";
        //   compiler.StartInfo.UseShellExecute = false;
        //   compiler.StartInfo.RedirectStandardOutput = true;
        //   compiler.Start();

        //   Console.WriteLine(compiler.StandardOutput.ReadToEnd());

        //   compiler.WaitForExit();
        // }


        return app.Exec();
      }
    }
  }
}
