module aim.deploy.data;

private
{
    import aim.common;
}

struct AimDeployGitlabCISource
{
    string gitlabUrl;
    string repoPath;
    string artifactRawUri;
    string artifactJob;
    string lastTagUsed;

    string getPackageDownloadUrl(string artifactRef)
    {
        import std.format : format;
        
        this.fixData();
        return "%s/%s/-/jobs/artifacts/%s/raw/%s?job=%s".format(
            this.gitlabUrl,
            this.repoPath,
            artifactRef,
            this.artifactRawUri, 
            this.artifactJob
        );
    }
    ///
    unittest
    {
        auto source = AimDeployGitlabCISource(
            "https://gitlab.com",
            "SealabJaster/AimCLITool",
            "linux-x86/aim",
            "Bundle"
        );
        assert(source.getPackageDownloadUrl("v0.1.0") == "https://gitlab.com/SealabJaster/AimCLITool/-/jobs/artifacts/v0.1.0/raw/linux-x86/aim?job=Bundle");
    }

    string getTagsUrl()
    {
        import std.format : format;
        import std.array  : replace;

        this.fixData();
        return "%s/api/v4/projects/%s/repository/tags".format(
            this.gitlabUrl,
            this.repoPath.replace("/", "%2F")
        );
    }
    ///
    unittest
    {
        auto source = AimDeployGitlabCISource(
            "https://gitlab.com",
            "SealabJaster/AimCLITool",
            "linux-x86/aim",
            "Bundle"
        );
        assert(source.getTagsUrl() == "https://gitlab.com/api/v4/projects/SealabJaster%2FAimCLITool/repository/tags", source.getTagsUrl());
    }

    private void fixData()
    {
        if(this.gitlabUrl.length > 0 && this.gitlabUrl[$-1] == '/')
            this.gitlabUrl = this.gitlabUrl[0..$-1];
    }
}

struct AimDeployConfig
{
    static const CONF_FILE = PATH(DIR_GIT_IGNORE, "deploy_config.json");

    enum Type
    {
        ERROR_UNKNOWN,
        AspCore   
    }

    string name;
    string domain;
    ushort port;
    Type projectType;
    AimDeployGitlabCISource gitlab;

    void enforceHasBeenInit()
    {
        import std.exception : enforce;
        enforce(this.projectType != Type.ERROR_UNKNOWN, "Deployment project has not been initialised. Hint: Use 'aim deploy init' first.");
    }
}