module aim.deploy.triggers;

import aim.common, aim.deploy;
import jaster.ioc, jaster.cli;

enum AimDeployTriggers
{
    ERROR,
    GithubDeployment
}

interface IAimDeployTriggerFactory
{
    IAimDeployTrigger getTriggerForType(AimDeployTriggers type);
}

final class AimDeployTriggerFactory : IAimDeployTriggerFactory
{
    private ServiceScopeAccessor _scope;

    this(ServiceScopeAccessor scope_)
    {
        this._scope = scope_;
    }

    override IAimDeployTrigger getTriggerForType(AimDeployTriggers type)
    {
        auto serviceScope = this._scope.serviceScope;
        final switch(type) with(AimDeployTriggers)
        {
            case ERROR: throw new Exception("Nice try");
            case GithubDeployment:
                return Injector.construct!GithubAimDeployTrigger(serviceScope);
        }
    }
}

interface IAimDeployTrigger
{
    void onAddedToProject();
    bool shouldTriggerDeploy();
    void onPostDeploy(bool success);
}

final class GithubAimDeployTrigger : IAimDeployTrigger
{
    private AimCliConfig!Config _githubConf;
    private static immutable GRAPHQL_GET_DEPLOYMENTS = `
    query($owner:String!, $name:String!) { 
        repository(name:$name,owner:$owner) {
            deployments(orderBy:{field:CREATED_AT, direction:DESC}, first:30){
                nodes{
                    databaseId
                    environment
                    state
                }
            }
        }
    }`;

    static struct Config
    {
        string deployToken;
        string repoOwner;
        string repoName;
        string deploymentId;
    }

    this()
    {
        this._githubConf = new AimCliConfig!Config();
        this._githubConf.loadFromFile(PATH(DIR_GIT_IGNORE, "trigger_github_deployment.json"));
    }

    override void onAddedToProject()
    {
        this._githubConf.edit((scope ref conf)
        {
            conf.deployToken = Shell.getInputNonEmptyString("Deploy Token: ");
            conf.repoOwner   = Shell.getInputNonEmptyString("Repo Owner: ");
            conf.repoName    = Shell.getInputNonEmptyString("Repo Name: ");
        });
    }

    override bool shouldTriggerDeploy()
    {
        import std.algorithm : filter;
        import vibe.data.json;
        import vibe.http.client;

        Shell.verboseLogfln("Sending GraphQL query to Github");
        auto response = requestHTTP(
            "https://api.github.com/graphql",
            (scope req)
            {
                req.method = HTTPMethod.POST;
                req.headers["Authorization"] = "bearer "~this._githubConf.value.deployToken;
                req.writeJsonBody(
                [
                    "query": Json(GRAPHQL_GET_DEPLOYMENTS),
                    "variables": Json(
                    [
                        "owner": Json(this._githubConf.value.repoOwner),
                        "name":  Json(this._githubConf.value.repoName)
                    ])
                ]);
            }
        ).readJson();
        Shell.verboseLogfln("Response: %s", response.toPrettyString());

        auto nodes = response["data"]["repository"]["deployments"]["nodes"];
        auto firstPendingProduction = nodes.byValue.filter!(v => v["environment"].to!string == "production" && v["state"].to!string == "PENDING");

        if(firstPendingProduction.empty)
        {
            Shell.verboseLogfln("No pending deployments found");
            return false;
        }
        Shell.verboseLogfln("Pending deployment found, id: %s", firstPendingProduction.front["databaseId"].to!string());

        this._githubConf.edit((scope ref conf)
        {
            conf.deploymentId = firstPendingProduction.front["databaseId"].to!string();            
        });

        return true;
    }

    override void onPostDeploy(bool success)
    {
        import vibe.http.client;

        auto response = requestHTTP(
            "https://api.github.com/repos/"~this._githubConf.value.repoOwner
           ~"/"~this._githubConf.value.repoName
           ~"/deployments/"
           ~this._githubConf.value.deploymentId
           ~"/statuses",
            (scope req)
            {
                req.method = HTTPMethod.POST;
                req.headers["Accept"] = "application/vnd.github.flash-preview+json";
                req.writeJsonBody(
                [
                    "state":        success ? "success" : "failure",
                    "environment":  "production",
                    "description":  "Deployed by AimCLI"
                ]);
            }
        ).readJson();
        Shell.verboseLogfln("Response: %s", response.toPrettyString());
    }
}