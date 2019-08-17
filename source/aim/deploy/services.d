module aim.deploy.services;

interface IAimDeployPacker
{
    static const NO_AIM_DIR = "none";
    static const DATA_DIR_NAME = "deploy-data";
    static const DEFAULT_PACKAGE_NAME = "deploy-package.tar";

    void pack(string outputFile, string dataDir, string aimDir);
}

final class AimDeployPacker : IAimDeployPacker
{
    override void pack(string outputFile, string dataDir, string aimDir)
    {
        import std.algorithm    : map, reduce;
        import std.path         : absolutePath, expandTilde, setExtension, buildNormalizedPath, dirName, relativePath;
        import std.file         : exists, isDir, remove, rename;
        import std.exception    : enforce;
        import std.format       : format;
        import jaster.cli       : Shell;

        if(aimDir is null)
            aimDir = ".aim/";

        Shell.verboseLogf("Making paths absolute...");
        outputFile = outputFile.expandTilde.absolutePath.buildNormalizedPath;
        dataDir    = dataDir.expandTilde.absolutePath.buildNormalizedPath;
        if(aimDir != NO_AIM_DIR)
            aimDir = aimDir.expandTilde.absolutePath.buildNormalizedPath;

        Shell.verboseLogf("Checking dirs exist...");
        enforce(dataDir.exists, "The data directory '%s' does not exist.".format(dataDir));
        enforce(dataDir.isDir,  "The data directory '%s' is not actually a directory.".format(dataDir));
        if(aimDir != NO_AIM_DIR)
        {
            enforce(aimDir.exists,  "The aim directory '%s' does not exist.".format(aimDir));
            enforce(aimDir.isDir,   "The aim directory '%s' is not actually a directory.".format(aimDir));
        }

        Shell.verboseLogf("Removing old package file if it exists...");
        if(outputFile.exists)
            outputFile.remove();

        Shell.verboseLogf("Temporarily renaming data directory...");
        auto newDataDir = buildNormalizedPath(dataDir.dirName, DATA_DIR_NAME);
        rename(dataDir, newDataDir);
        scope(exit) rename(newDataDir, dataDir);

        // Things are in variables to make the code a bit easier to modify in the future.
        string command = "tar";
        string[] params = ["cvf", outputFile, newDataDir.relativePath, aimDir.relativePath];

        Shell.executeEnforceStatusPositive(format("%s %s", command, params.map!(p => "\""~p~"\"").reduce!((s1, s2) => s1 ~ " " ~ s2)));
    }
}