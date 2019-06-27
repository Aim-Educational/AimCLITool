module aim.deploy.data;

private
{
    import std.typecons : Flag, Nullable;
    import jaster.cli.helptext;
    import aim.common.data;
}

const DEPLOY_CONFIG_PATH = ".aim/git_keep/deploy_config.json";

struct DeployConfig
{
    mixin VersionedData!(GenericFileVersion.v1, NO_PREVIOUS_VERSION);

    string name;
    string domain;
    Nullable!ushort port;
    string[] secretsToExpose;
}