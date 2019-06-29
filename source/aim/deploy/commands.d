module aim.deploy.commands;

private
{
    import jaster.cli.core, jaster.cli.udas, jaster.cli.util;
    import aim.secrets.commands, aim.secrets.data, aim.deploy.data, aim.common.util, aim.common.templater;
    import aim.secrets.common : STORE_FILE_LOCATION, SecretsCommon = Common;

    immutable NGINX_SERVER_BLOCK_TEMPLATE = import("deploy/nginx_server_block.txt");
    immutable SYSTEMD_SERVICE_TEMPLATE    = import("deploy/systemd_service.txt");

    immutable DOTNET_PUBLISH_DIR = ".aim/git_ignore/deploy/build/";
}

@Command("deploy expose", "'Exposes' a secret to the project during publishing.")
struct Expose
{
    @CommandPositionalArg(0, "key", "The key/name of the secret to expose.")
    string key;

    void onExecute()
    {
        import std.algorithm : map, any;
        import std.exception : enforce;
        
        auto config = DeployConfig.createOrGetFromFile(DEPLOY_CONFIG_PATH);
        if(config.secretsToExpose.any!(s => s == this.key))
            return;

        enforce(
            SecretsCommon.readAllDefinitionFiles()
                         .map!(f => f.values)
                         .any!(v => this.key in v), 
            "There is no secret named '"~this.key~"'. Cannot continue."
        );

        config.secretsToExpose ~= this.key;
        config.toFile(DEPLOY_CONFIG_PATH);
    }
}

@Command("deploy unexpose", "Unexposes a secret.")
struct Unexpose
{
    @CommandPositionalArg(0, "key", "The key/name of the secret to unexpose.")
    string key;

    void onExecute()
    {
        import std.algorithm : filter;
        import std.array     : array;

        auto config = DeployConfig.createOrGetFromFile(DEPLOY_CONFIG_PATH);
        config.secretsToExpose = config.secretsToExpose.filter!(s => s != this.key).array;
        config.toFile(DEPLOY_CONFIG_PATH);
    }
}

@Command("deploy publish", "Compiles the project, and sets it up as a service.")
struct Publish
{
    void onExecute()
    {
        failAssertOnNonLinux();

        foreach(command; ["nginx", "git", "dotnet", "certbot", "ln", "systemctl", "aim"])
            Shell.enforceCommandExists(command);

        Shell.executeEnforceStatusZero("aim secrets verify");

        this.setupProxy();
        this.compile();
        this.setupService();
    }

    void setupProxy()
    {
        import std.conv      : to;
        import std.exception : enforce;
        import std.file      : writeFile = write;
        import std.array     : replace;
        import std.format    : format;

        failAssertOnNonLinux();
        Shell.verboseLogf("<STEP: Setting up proxy...>");

        Shell.verboseLogf("<SUBSTEP: Reading Config and enforcing that certain values exist.>");
        auto config = DeployConfig.createOrGetFromFile(DEPLOY_CONFIG_PATH);
        enforce(config.name !is null,   "This project hasn't been given a name. Can't continue. Please use `aim deploy set-name`.");
        enforce(config.domain !is null, "This project hasn't been set to a domain. Can't continue. Please use `aim deploy set-domain`.");
        enforce(!config.port.isNull,    "This project hasn't been set a port. Can't continue. Please us `aim deploy set-port`.");

        version(linux)
        {
            Shell.verboseLogf("NOTICE: Platform is Linux, so NGINX will be used.");

            Shell.verboseLogf("<SUBSTEP: Creating NGINX server block file.>");
            auto nginxFile = this.nginxFilePath(config);
            writeFile(
                nginxFile, 
                Templater.resolveTemplate(
                    [
                        "$DOMAIN": config.domain,
                        "$PORT":   config.port.get.to!string
                    ],
                    NGINX_SERVER_BLOCK_TEMPLATE
                )
            );

            Shell.verboseLogf("<SUBSTEP: Linking NGINX server block file to sites-enabled.>");
            Shell.executeEnforceStatusPositive(
                "ln -s \"%s\" \"%s\"".format(
                    nginxFile,
                    nginxFile.replace("sites-available", "sites-enabled")
                )
            );

            Shell.verboseLogf("<SUBSTEP: Restarting Nginx.>");
            Shell.executeEnforceStatusZero("service nginx restart");

            Shell.verboseLogf("<SUBSTEP: Setting up Certbot.>");
            Shell.executeEnforceStatusZero(
                "certbot --nginx -d %s --non-interactive -m %s".format(
                    config.domain,
                    "bradley.chatha@gmail.com" // TEMP UNTIL I HAVE A CONFIG OPTION
                )
            );

            Shell.verboseLogf("<SUBSTEP: Restarting Nginx.>");
            Shell.executeEnforceStatusZero("service nginx restart");
        }
    }

    void compile()
    {
        import std.path : buildNormalizedPath;

        failAssertOnNonLinux();

        Shell.verboseLogf("<STEP: Compile project.>");
        Shell.verboseLogf("<SUBSTEP: Reading Config.>");
        auto config = DeployConfig.createOrGetFromFile(DEPLOY_CONFIG_PATH);

        version(linux)
        {
            Shell.verboseLogf("<SUBSTEP: Stopping existing project service.>");
            Shell.execute("systemctl stop "~config.name~".service");

            Shell.verboseLogf("<SUBSTEP: Compile using dotnet>");
            Shell.executeEnforceStatusZero("dotnet publish -o \"../"~DOTNET_PUBLISH_DIR~"\" -c Release");
        }
    }

    void setupService()
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

        Shell.verboseLogf("<STEP: Setting up service.>");
        Shell.verboseLogf("<SUBSTEP: Reading Config.>");
        auto config = DeployConfig.createOrGetFromFile(DEPLOY_CONFIG_PATH);
        auto store  = SecretsStore.createOrGetFromFile(STORE_FILE_LOCATION);

        struct EnvVar
        {
            string name;
            string value;
        }
        auto predefinedVars = 
        [
            EnvVar("ASPNETCORE_HTTPS_PORT", "443"),
            EnvVar("AIMDEPLOY:DOMAIN",      config.domain),
            EnvVar("AIMDEPLOY:GIT_TAG",     Shell.executeEnforceStatusZero("git tag")
                                                 .output
                                                 .splitter("\n")
                                                 .filter!(c => c.length > 1)
                                                 .array[$-1]
            )
        ];

        version(linux)
        {
            Shell.verboseLogf("NOTICE: Platform is Linux, so systemctl will be used."); // TODO: Eventually support different service systems.

            Shell.verboseLogf("<SUBSTEP: Creating service file.>");
            writeFile(
                buildNormalizedPath("/etc/systemd/system/", config.name~".service"),
                Templater.resolveTemplate(
                    [
                        "$NAME":             config.name,
                        "$WORKING_DIR":      buildNormalizedPath(getcwd(), DOTNET_PUBLISH_DIR),
                        "$PORT":             config.port.get.to!string,
                        "$ENVIRONMENT_LIST": config.secretsToExpose
                                                   .map!(s => EnvVar(s, store.values[s]))
                                                   .chain(predefinedVars)
                                                   .map!(v => "Environment='%s=%s'"
                                                              .format(v.name.replace(":", "__"), v.value)
                                                    )
                                                   .reduce!((s1, s2) => s1~"\n"~s2)
                    ],
                    SYSTEMD_SERVICE_TEMPLATE
                )
            );
        }
    }

    string nginxFilePath(const DeployConfig config)
    {
        import std.path : buildNormalizedPath;

        failAssertOnNonLinux();

        return buildNormalizedPath("/etc/nginx/sites-available/", config.name);
    }
}

@Command("deploy set-name", "Sets the name of the project.")
struct SetName
{
    @CommandPositionalArg(0, "Name", "The name to give the project.")
    string name;

    void onExecute()
    {
        auto conf = DeployConfig.createOrGetFromFile(DEPLOY_CONFIG_PATH);
        conf.name = this.name;
        conf.toFile(DEPLOY_CONFIG_PATH);
    }
}

@Command("deploy set-domain", "Sets the domain of the project.")
struct SetDomain
{
    @CommandPositionalArg(0, "domain", "The domain to give the project.")
    string domain;

    void onExecute()
    {
        auto conf = DeployConfig.createOrGetFromFile(DEPLOY_CONFIG_PATH);
        conf.domain = this.domain;
        conf.toFile(DEPLOY_CONFIG_PATH);
    }
}

@Command("deploy set-port", "Sets the port of the project.")
struct SetPort
{
    @CommandPositionalArg(0, "port", "The port to give the project.")
    ushort port;

    void onExecute()
    {
        auto conf = DeployConfig.createOrGetFromFile(DEPLOY_CONFIG_PATH);
        conf.port = this.port;
        conf.toFile(DEPLOY_CONFIG_PATH);
    }
}