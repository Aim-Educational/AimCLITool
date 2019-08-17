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

    override int onExecute()
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

        return 0;
    }
}

@Command("secrets undefine", "Undefines an already defined secret.")
final class AimSecretsUndefine : BaseCommand
{
    private IAimCliConfig!AimSecretsDefineValues _values;
    private IAimCliConfig!AimSecretsConfig _config;

    @CommandPositionalArg(0, "name", "The name of the secret to undefine.")
    string name;

    this(IAimCliConfig!AimSecretsDefineValues values, IAimCliConfig!AimSecretsConfig config)
    {
        assert(values !is null);
        this._values = values;
        this._config = config;
    }

    override int onExecute()
    {
        super.onExecute();

        this._config.edit((scope ref config)
        {
            import std.algorithm : filter;
            import std.array     : array;
            
            if(!config.definitionExists(this.name))
            {
                Shell.verboseLogf("Cannot undefine '%s' as it is not already defined.", this.name);
                return;
            }
            else
                Shell.verboseLogf("Undefining '%s'.", this.name);

            config.definitions = config.definitions
                                       .filter!(d => d.name != this.name)
                                       .array;
            
            this._values.edit((scope ref values)
            {
                values.values = values.values
                                      .filter!(v => v.name != this.name)
                                      .array;
            });
        });
        return 0;
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

    override int onExecute()
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

        return 0;
    }
}

@Command("secrets get", "Gets the value of a secret.")
final class AimSecretsGet : BaseCommand
{
    private IAimCliConfig!AimSecretsDefineValues _values;
    private IAimCliConfig!AimSecretsConfig _config;

    @CommandPositionalArg(0, "name", "The name of the secret to get the value of.")
    string name;

    this(IAimCliConfig!AimSecretsDefineValues values, IAimCliConfig!AimSecretsConfig config)
    {
        assert(values !is null);
        this._values = values;
        this._config = config;
    }

    override int onExecute()
    {
        import std.exception : enforce;
        import std.algorithm : filter;
        import std.stdio : writeln;

        super.onExecute();
        enforce(this._config.value.definitionExists(this.name), "The secret '"~this.name~"' is not defined.");

        auto value = this._values.value.values.filter!(v => v.name == this.name);
        enforce(!value.empty, "The secret '"~this.name~"' does not have a value.");

        writeln(value.front.value);
        return 0;
    }
}

@Command("secrets verify", "Verifies that all non-optional secrets have been given a value.")
final class AimSecretsVerify : BaseCommand
{
    private IAimCliConfig!AimSecretsDefineValues _values;
    private IAimCliConfig!AimSecretsConfig _config;

    this(IAimCliConfig!AimSecretsDefineValues values, IAimCliConfig!AimSecretsConfig config)
    {
        assert(values !is null);
        this._values = values;
        this._config = config;
    }

    override int onExecute()
    {
        import std.algorithm : filter, any, map;
        import std.stdio     : writeln;
        import std.array     : array;
        super.onExecute();

        auto missing = this._config
                           .value
                           .definitions
                           .filter!(d => !this._values.value.values.any!(v => v.name == d.name));    
        auto argInfo = missing.map!(m => HelpSectionArgInfoContent.ArgInfo([m.name], m.description, cast(ArgIsOptional)m.isOptional));

        auto text = new HelpTextBuilderTechnical();
        text.addSection("Missing")
            .addContent(new HelpSectionArgInfoContent(argInfo.array, AutoAddArgDashes.no));

        if(!missing.empty)
        {
            writeln(text.toString());
            return -2;
        }
        else
        {
            writeln("Verification successful.");
            return 0;
        }
    }
}

@Command("secrets list", "Lists all defined secrets.")
final class AimSecretsList : BaseCommand
{
    private IAimCliConfig!AimSecretsConfig _config;

    this(IAimCliConfig!AimSecretsConfig config)
    {
        assert(config !is null);
        this._config = config;
    }

    override int onExecute()
    {
        import std.algorithm : map;
        import std.array     : array;
        import std.stdio     : writeln;

        super.onExecute();

        auto text = new HelpTextBuilderTechnical();
        text.addSection("Secrets")
            .addContent(new HelpSectionArgInfoContent(
                this._config.value
                            .definitions
                            .map!(d => HelpSectionArgInfoContent.ArgInfo([d.name], d.description, cast(ArgIsOptional)d.isOptional))
                            .array,
                AutoAddArgDashes.no
        ));

        writeln(text.toString());
        return 0;
    }
}