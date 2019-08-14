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
}