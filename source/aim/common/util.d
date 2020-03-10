module aim.common.util;

private
{
    import std.exception : enforce;
    import jaster.cli;
}

public import std.path : PATH = buildNormalizedPath;

string CONFIG_PATH(string appName, string path)
{
    version(linux)
        return PATH("/etc/", appName, path);
    else
        return PATH(".aim/config/", appName, path);
}

const DIR_GIT_KEEP      = ".aim/git_keep/";
const DIR_GIT_IGNORE    = ".aim/git_ignore/";

abstract class BaseCommand
{
    @CommandNamedArg("v|verbose", "Show verbose output.")
    Nullable!bool verbose;

    int onExecute()
    {
        Shell.useVerboseOutput = this.verbose.get(false);
        return 0;
    }
}

void failAssertOnNonLinux()
{
    version(linux)
    {
    }
    else
        assert(false, "This command is only supported on Linux");
}