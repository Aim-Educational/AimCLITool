module tool.data;

private
{
    import std.typecons : Flag;
    import jaster.cli.helptext;
    import asdf;
}

struct SecretsDefinition
{
    enum Version
    {
        v1 = 1
    }

    struct Value
    {
        string description;
        ArgIsOptional isOptional;
    }

    Version       fileVersion;
    Value[string] values;

    static SecretsDefinition fromFile(string path)
    {
        return genericFromFile!SecretsDefinition(path);
    }

    void toFile(string path)
    {
        genericToFile(path, this);
    }
}

struct SecretsStore
{
    enum Version
    {
        v1 = 1
    }

    Version        fileVersion;
    string[string] values;

    static SecretsStore fromFile(string path)
    {
        return genericFromFile!SecretsStore(path);
    }

    void toFile(string path)
    {
        genericToFile(path, this);
    }
}

struct SecretsConfig
{
    enum Version
    {
        v1 = 1
    }

    Version  fileVersion;
    string[] definitionFiles;

    static SecretsConfig fromFile(string path)
    {
        return genericFromFile!SecretsConfig(path);
    }

    void toFile(string path)
    {
        genericToFile(path, this);
    }
}

private T genericFromFile(T)(string path)
{
    import std.file : readText;

    return path.readText().deserialize!T();
}

private void genericToFile(T)(string path, T value)
{
    import std.path : dirName;
    import std.file : write, mkdirRecurse;

    path.dirName.mkdirRecurse();
    path.write(value.serializeToJsonPretty());
}