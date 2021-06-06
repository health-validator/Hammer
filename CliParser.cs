using CommandLine;

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
            Program.AppModel.Instance.AnimateQml = false;

            if (result.ScopeDir != null)
            {
                var scopeUri = new System.Uri(System.IO.Path.GetFullPath(result.ScopeDir));
                Program.AppModel.Instance.LoadScopeDirectory(scopeUri.ToString());
            }
            if (result.ResourceFile != null)
            {
                var resourceUri = new System.Uri(System.IO.Path.GetFullPath(result.ResourceFile));
                if (Program.AppModel.Instance.LoadResourceFile(resourceUri.ToString()))
                {
                    Program.AppModel.Instance.StartValidation();
                }
            }

            Program.AppModel.Instance.AnimateQml = true;
        });
    }
}
