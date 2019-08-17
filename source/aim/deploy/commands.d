module aim.deploy.commands;

private
{
    import jaster.cli;
    import aim.common, aim.deploy;
}

@Command("deploy pack", "Creates a package that can then be deployed to a server.")
final class AimDeployPack : BaseCommand
{
    private IAimDeployPacker _packer;

    @CommandNamedArg("d|data-dir", "The directory containing the package's data.")
    string directory;

    @CommandNamedArg("a|aim-dir", "The path to the '.aim' directory. Use '-a none' if there is no '.aim' directory.")
    string aimDirectory;

    @CommandNamedArg("o|out-file", "The output file name. [Default="~IAimDeployPacker.DEFAULT_PACKAGE_NAME~"]")
    Nullable!string outFile;

    this(IAimDeployPacker packer)
    {
        assert(packer !is null);
        this._packer = packer;
    }

    override int onExecute()
    {
        import std.exception : assumeUnique;
        super.onExecute();
        this._packer.pack(this.outFile.get(IAimDeployPacker.DEFAULT_PACKAGE_NAME).assumeUnique, this.directory, this.aimDirectory);

        return 0;
    }
}

@Command("deploy init", "Initialises a deployment project.")
final class AimDeployInit : BaseCommand
{
    const DIR_DIST = "dist";
    const DIR_DOWNLOADS = "downloads";

    private IAimCliConfig!AimDeployConfig _config;

    this(IAimCliConfig!AimDeployConfig config)
    {
        this._config = config;
    }

    override int onExecute()
    {
        super.onExecute();

        this.createConfigFromUserInput();
        this.createDirStructure();

        return 0;
    }

    private void createDirStructure()
    {
        import std.file : mkdir;

        Shell.verboseLogf("Creating directory structure");
        mkdir(DIR_DIST);
        mkdir(DIR_DOWNLOADS);
    }

    private void createConfigFromUserInput()
    {
        import jaster.cli : Shell;

        Shell.verboseLogf("Asking the user to create the deployment config");
        this._config.edit((scope ref config)
        {
            config.name = this.getNonNullStringInput("Project Name: ");
            config.domain = this.getNonNullStringInput("Domain to host project on: ");

            while(true)
            {
                try config.port = Shell.getInput!ushort("Port to host project on locally: ");
                catch(Exception){}

                break;
            }
            
            config.projectType = AimDeployConfig.Type.AspCore; // Hard coded until we have more options.
            
            // Source is assumed to be Gitlab until we have more.
            config.gitlab.gitlabUrl = this.getNonNullStringInput("Gitlab instance URL: ");
            config.gitlab.repoPath = this.getNonNullStringInput("Repo path [usually: Username/RepoName]: ");
            config.gitlab.artifactRawUri = this.getNonNullStringInput("Path inside artifact zip to package: ");
            config.gitlab.artifactJob = this.getNonNullStringInput("Name of job to use artifact zip of: ");
        });
    }

    private string getNonNullStringInput(string prompt)
    {
        import jaster.cli : Shell;
        import std.algorithm : all;
        import std.ascii : isWhite;

        string value;
        while(value is null || value.length == 0 || value.all!isWhite)
            value = Shell.getInput!string(prompt);

        return value;
    }
}