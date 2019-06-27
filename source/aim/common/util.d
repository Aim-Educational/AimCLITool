module aim.common.util;

private
{
    import std.exception : enforce;
}

void failAssertOnNonLinux()
{
    version(linux)
    {
    }
    else
        assert(false, "This command is only supported on Linux");
}