module aim.secrets.data;

private
{
    import std.typecons : Flag;
    import jaster.cli.helptext;
    import aim.common.data;
}

struct SecretsDefinition
{
    mixin VersionedData!(GenericFileVersion.v1, NO_PREVIOUS_VERSION);

    struct Value
    {
        string description;
        ArgIsOptional isOptional;
    }

    Value[string] values;
}

struct SecretsStore
{
    mixin VersionedData!(GenericFileVersion.v1, NO_PREVIOUS_VERSION);

    string[string] values;
}

struct SecretsConfig
{
    mixin VersionedData!(GenericFileVersion.v1, NO_PREVIOUS_VERSION);

    string[] definitionFiles;
}