module aim.deploy.data;

private
{
    import aim.common, aim.deploy.addons;
}

struct AimDeployDockerSource
{
    string repository;
    string imageName;
    string tagInUse;
    string username;
    string passwordOrToken;
    string loginUrl;
}

struct AimDeployGithubDeploymentTrigger
{
    string deployToken;
    string repoOwner;
    string repoName;
}

struct AimDeployConfig
{
    static const CONF_FILE = PATH(DIR_GIT_IGNORE, "deploy_config.json");

    enum Type
    {
        ERROR_UNKNOWN,
        Docker   
    }

    string name;
    string domain;
    ushort port;
    Type   projectType;

    AimDeployAddons[]                addons;
    AimDeployDockerSource            docker;
    AimDeployGithubDeploymentTrigger triggerOnGithubDeployment;

    void enforceHasBeenInit()
    {
        import std.exception : enforce;
        enforce(this.projectType != Type.ERROR_UNKNOWN, "Deployment project has not been initialised. Hint: Use 'aim deploy init' first.");
    }
}