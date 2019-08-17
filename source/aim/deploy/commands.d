module aim.deploy.commands;

private
{
    import jaster.cli;
    import aim.common, aim.deploy, aim.secrets;
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
    static const DIR_DIST = "dist";
    static const DIR_DOWNLOADS = "downloads";

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
        import jaster.cli    : Shell;
        import std.algorithm : all;
        import std.ascii     : isWhite;

        string value;
        while(value is null || value.length == 0 || value.all!isWhite)
            value = Shell.getInput!string(prompt);

        return value;
    }
}

@Command("deploy trigger", "Triggers a deployment attempt.")
final class AimDeployTrigger : BaseCommand
{
    // NOTE: Currently this code is all the logic for an AspCore project.
    //       If I ever want to bother with another project type, then I need to move the logic into services/some kind of factory service.
    const     FILE_PACKAGE                = PATH(AimDeployInit.DIR_DOWNLOADS, "package.tar");
    immutable TEMPLATE_NGINX_SERVER_BLOCK = import("deploy/nginx_server_block.txt");
    immutable TEMPLATE_SYSTEMD_SERVICE    = import("deploy/systemd_service.txt");

    private IFileDownloader _downloader;
    private IAimCliConfig!AimDeployConfig _config;
    private IAimCliConfig!AimSecretsDefineValues _secrets;
    private IAimDeployPacker _packer;

    @CommandNamedArg("f|force", "Forces a deployment, even if the current one is up to date.")
    Nullable!bool force;

    this(
        IFileDownloader                       downloader, 
        IAimCliConfig!AimDeployConfig         config, 
        IAimDeployPacker                      packer, 
        IAimCliConfig!AimSecretsDefineValues  secrets
    )
    {
        this._downloader = downloader;
        this._config = config;
        this._packer = packer;
        this._secrets = secrets;
    }

    override int onExecute()
    {
        import std.stdio : writeln;
        super.onExecute();

        this._config.value.enforceHasBeenInit();

        string tag;
        auto shouldStop = this.downloadPackage(tag);
        if(shouldStop)
            return 0;

        scope(success) this._config.edit((scope ref config){ config.gitlab.lastTagUsed = tag; });

        failAssertOnNonLinux();
        this.checkCommands();
        this.setupNginx();
        this.setupService();

        writeln("Success");
        return 0;
    }

    private void setupNginx()
    {
        import std.conv   : to;
        import std.file   : write;
        import std.format : format;
        import std.array  : replace;
        import jaster.cli : Shell;
        import aim.common : Templater;

        Shell.verboseLogf("NOTICE: Platform is Linux, so NGINX will be used.");

        Shell.verboseLogf("Creating NGINX server block file.");
        auto nginxFile = this.createNginxFilePath(this._config.value.name);
        write(
            nginxFile, 
            Templater.resolveTemplate(
                [
                    "$DOMAIN": this._config.value.domain,
                    "$PORT":   this._config.value.port.to!string
                ],
                TEMPLATE_NGINX_SERVER_BLOCK
            )
        );

        Shell.verboseLogf("Linking NGINX server block file to sites-enabled.");
        Shell.executeEnforceStatusPositive(
            "ln -s \"%s\" \"%s\"".format(
                nginxFile,
                nginxFile.replace("sites-available", "sites-enabled")
            )
        );

        Shell.verboseLogf("Restarting Nginx.");
        Shell.executeEnforceStatusZero("service nginx restart");

        Shell.verboseLogf("Setting up Certbot.");
        Shell.executeEnforceStatusZero(
            "certbot --nginx -d %s --non-interactive -m %s".format(
                this._config.value.domain,
                "bradley.chatha@gmail.com" // TEMP UNTIL I HAVE A CONFIG OPTION
            )
        );

        Shell.verboseLogf("Restarting Nginx.");
        Shell.executeEnforceStatusZero("service nginx restart");
    }

    private void setupService()
    {
        import std.algorithm : reduce, map, splitter, filter;
        import std.array     : array, replace;
        import std.range     : chain;
        import std.file      : writeFile = write;
        import std.path      : buildNormalizedPath;
        import std.file      : getcwd;
        import std.conv      : to;
        import std.format    : format;

        failAssertOnNonLinux();
        Shell.verboseLogf("Setting up service.");

        struct EnvVar
        {
            string name;
            string value;
        }
        auto predefinedVars = 
        [
            EnvVar("ASPNETCORE_HTTPS_PORT", "443"),
            EnvVar("AIMDEPLOY:DOMAIN",      this._config.value.domain)
        ];

        Shell.verboseLogf("NOTICE: Platform is Linux, so systemctl will be used."); // TODO: Eventually support different service systems.

        Shell.verboseLogf("Creating service file.");
        writeFile(
            buildNormalizedPath("/etc/systemd/system/", this._config.value.name~".service"),
            Templater.resolveTemplate(
                [
                    "$NAME":             this._config.value.name,
                    "$WORKING_DIR":      buildNormalizedPath(getcwd(), AimDeployInit.DIR_DIST, IAimDeployPacker.DATA_DIR_NAME),
                    "$PORT":             this._config.value.port.to!string,
                    "$ENVIRONMENT_LIST": this._secrets
                                             .value
                                             .values
                                             .map!(d => EnvVar(d.name, d.value))
                                             .chain(predefinedVars)
                                             .map!(v => "Environment='%s=%s'"
                                                         .format(v.name.replace(":", "__"), v.value)
                                             )
                                             .reduce!((s1, s2) => s1~"\n"~s2)
                ],
                TEMPLATE_SYSTEMD_SERVICE
            )
        );

        Shell.executeEnforceStatusZero("systemctl restart "~this._config.value.name~".service");
    }

    private void checkCommands()
    {
        Shell.enforceCommandExists("certbot");
        Shell.enforceCommandExists("dotnet");
        Shell.enforceCommandExists("systemctl");
        Shell.enforceCommandExists("nginx");
    }

    private string createNginxFilePath(string name)
    {
        import std.path : buildNormalizedPath;

        failAssertOnNonLinux();
        return buildNormalizedPath("/etc/nginx/sites-available/", name);
    }

    private bool downloadPackage(ref string tag)
    {
        import core.thread   : Thread;
        import core.time     : msecs;
        import std.algorithm : sort;
        import std.array     : array;
        import std.file      : rmdirRecurse, mkdirRecurse, exists;
        import std.string    : splitLines;
        import std.exception : enforce;
        import asdf          : deserialize;
        import vibe.http.client, vibe.stream.operations;

        static struct Tag
        {
            string name;
        }

        Shell.verboseLogf("Getting tags: %s", this._config.value.gitlab.getTagsUrl());
        Tag[] tags;
        requestHTTP(URL(this._config.value.gitlab.getTagsUrl()),
            (scope req){ req.method = HTTPMethod.GET; },
            (scope res)
            { 
                enforce(res.statusCode == HTTPStatus.ok, "Did not get OK 200 back from tag URL: " ~ res.bodyReader.readAllUTF8()); 
                tags = res.bodyReader.readAllUTF8().deserialize!(Tag[])();
                tags = tags.sort!((t1, t2) => t1.name < t2.name).array;
            }
        );
        Shell.verboseLogf("Tags: %s", tags);

        if(tags.length == 0)
        {
            Shell.verboseLogf("NO TAGS. Won't continue.");
            return true;
        }

        if(tags[$-1].name == this._config.value.gitlab.lastTagUsed && !this.force)
        {
            Shell.verboseLogf("Latest tag is the same as current deployment. Won't continue. Pass -f to bypass this.");
            return true;
        }
        tag = tags[$-1].name;

        Shell.verboseLogf("Downloading distribution package: %s", this._config.value.gitlab.getPackageDownloadUrl(tags[$-1].name));
        this._downloader.downloadStreaming(this._config.value.gitlab.getPackageDownloadUrl(tags[$-1].name), FILE_PACKAGE);

        Shell.verboseLogf("Stopping existing project service.");
        Shell.execute("systemctl stop "~this._config.value.name~".service");

        Shell.verboseLogf("Recreating distribution directory and then unpacking distribution package");
        if(AimDeployInit.DIR_DIST.exists)
        {
            AimDeployInit.DIR_DIST.rmdirRecurse();
            Thread.sleep(500.msecs); // Give the OS time to catch up.
        }
        AimDeployInit.DIR_DIST.mkdirRecurse();
        this._packer.unpack(FILE_PACKAGE, AimDeployInit.DIR_DIST);

        return false;
    }
}