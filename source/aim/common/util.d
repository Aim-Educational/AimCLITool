module aim.common.util;

private
{
    import std.exception : enforce;
    import jaster.cli;
}

public import std.path : PATH = buildNormalizedPath;

const DIR_GIT_KEEP      = ".aim/git_keep/";
const DIR_GIT_IGNORE    = ".aim/git_ignore/";

abstract class BaseCommand
{
    @CommandNamedArg("v|verbose", "Show verbose output.")
    Nullable!bool verbose;

    void onExecute()
    {
        Shell.useVerboseOutput = this.verbose.get(false);
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