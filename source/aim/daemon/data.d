module aim.daemon.data;

private
{
    import jaster.cli;
    import aim.common, aim.deploy, aim.secrets, aim.daemon;
}

struct AimDaemonConfig
{
    string[] projectDirs;
}