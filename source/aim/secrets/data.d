module aim.secrets.data;

private
{
    import aim.common;
}

struct AimSecretsConfig
{
    static const CONF_FILE = PATH(DIR_GIT_KEEP, "secrets_conf.json");

    static struct Def
    {
        string name;
        string description;
        bool isOptional;
    }

    Def[] definitions;

    bool definitionExists(string defName)
    {
        import std.algorithm : any;

        return this.definitions.any!(d => d.name == defName);
    }
}

struct AimSecretsDefineValues
{
    static const CONF_FILE = PATH(DIR_GIT_IGNORE, "secrets_define_values.json");

    static struct Def
    {
        string name;
        string value;
    }

    Def[] values;

    string getValueByName(string name)
    {
        import std.algorithm : filter;
        import std.exception : enforce;

        auto value = this.values.filter!(v => v.name == name);
        enforce(!value.empty, "The secret '"~name~"' does not have a value.");

        return value.front.value;
    }
}