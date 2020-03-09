module aim.deploy.data;

private
{
    import aim.common, aim.deploy.addons, aim.deploy.triggers;
}

struct AimDeployDockerSource
{
    string repository;
    string imageName;
    string tagInUse;
    string username;
    string passwordOrToken;
    string loginUrl;
    string memoryLimit;
}

struct AimDeployConfig
{
    static const CONF_FILE = PATH(DIR_GIT_IGNORE, "deploy_config.json");

    enum Type
    {
        ERROR_UNKNOWN,
        Docker   
    }

    enum Triggers
    {
        ERROR,
        GithubDeployment
    }

    string name;
    string domain;
    ushort port;
    Type   projectType;

    AimDeployAddons[]     addons;
    AimDeployTriggers[]   triggers;
    AimDeployDockerSource docker; // Technically this should get the addon and trigger treatment, but I'm probably not going to add another source type anytime soon.

    void enforceHasBeenInit()
    {
        import std.exception : enforce;
        enforce(this.projectType != Type.ERROR_UNKNOWN, "Deployment project has not been initialised. Hint: Use 'aim deploy init' first.");
    }
}