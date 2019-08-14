module aim.secrets.commands;

private
{
    import jaster.cli;
    import aim.common, aim.secrets;
}

@Command("secrets define", "Defines a new secret.")
final class AimSecretsDefine : BaseCommand
{
    private IAimCliConfig!AimSecretsConfig _config;

    @CommandPositionalArg(0, "name", "The name of the secret.")
    string name;

    @CommandPositionalArg(1, "description", "The description of the secret.")
    string description;

    @CommandNamedArg("o|optional", "Specifies that the secret is optional.")
    Nullable!bool isOptional;

    this(IAimCliConfig!AimSecretsConfig config)
    {
        assert(config !is null);
        this._config = config;
    }

    override void onExecute()
    {
        super.onExecute();
        Shell.verboseLogf("Name: %s\nDescription: %s\nIsOptional: %s", this.name, this.description, this.isOptional.get(false));

        this._config.edit((scope ref config)
        {
            if(!config.definitionExists(this.name))
                config.definitions ~= AimSecretsConfig.Def(this.name, this.description, this.isOptional.get(false));
            else
                Shell.verboseLogf("Definition called '%s' already exists, skipping.", this.name);
        });
    }
}

@Command("secrets set", "Sets the value of a secret.")
final class AimSecretsSet : BaseCommand
{
    private IAimCliConfig!AimSecretsDefineValues _values;
    private IAimCliConfig!AimSecretsConfig _config;

    @CommandPositionalArg(0, "name", "The name of the secret to set the value of.")
    string name;

    @CommandPositionalArg(1, "value", "The value to give the secret.")
    string value;

    this(IAimCliConfig!AimSecretsDefineValues values, IAimCliConfig!AimSecretsConfig config)
    {
        assert(values !is null);
        this._values = values;
        this._config = config;
    }

    override void onExecute()
    {
        super.onExecute();
        Shell.verboseLogf("Name: %s\nValue: %s", this.name, this.value);

        this._values.edit((scope ref values)
        {
            import std.exception : enforce;
            import std.algorithm : countUntil;
            enforce(this._config.value.definitionExists(this.name), "The secret '"~this.name~"' is not defined.");

            auto existingValueIndex = values.values.countUntil!(v => v.name == this.name);
            if(existingValueIndex > -1)
                values.values[existingValueIndex] = AimSecretsDefineValues.Def(this.name, this.value);
            else
                values.values ~= AimSecretsDefineValues.Def(this.name, this.value);
        });
    }
}