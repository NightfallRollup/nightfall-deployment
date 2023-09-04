const { Stack, SecretValue, PhysicalName } = require('aws-cdk-lib');
const { Artifact } = require('aws-cdk-lib').aws_codepipeline;
const { GitHubSourceAction, GitHubTrigger } = require('aws-cdk-lib').aws_codepipeline_actions;
const iam = require('aws-cdk-lib').aws_iam;
//const { SimpleSynthAction, CdkPipeline, CodePipeline } = require('aws-cdk-lib').pipelines;
const { CodeBuildStep, CodePipeline, CodePipelineSource } = require('aws-cdk-lib').pipelines;

class PipelineStack extends Stack {
  constructor(scope, id, props) {
    super(scope, id, props);

    // Get GitHub access token from Secrets Manager
    const githubAccessToken = SecretValue.secretsManager("nightfall/github/deployment/token");

    // Artifacts
    const sourceArtifact = new Artifact();
    const cloudAssemblyArtifact = new Artifact();

    // Oversimplified policy
    const codePipelineRole = new iam.Role(this, 'CodePipelineRole', {
        assumedBy: new iam.ServicePrincipal('codepipeline.amazonaws.com'),
        roleName: PhysicalName.GENERATE_IF_NEEDED,
        inlinePolicies: {
            rootPermissions: new iam.PolicyDocument({
                statements: [
                    new iam.PolicyStatement({
                            resources: ['*'],
                            actions: ['*'],
                        }),
                ],
            }),
        }
    })

/*
    // Initialize CDK pipeline
    const pipeline = new CdkPipeline(this, "TestCDKPipeline", {
      pipelineName: "TestCDKPipeline",
      cloudAssemblyArtifact,
      role: codePipelineRole.withoutPolicyUpdates(),
      sourceAction: new GitHubSourceAction({
        actionName: "GitHub",
        output: sourceArtifact,
        oauthToken: githubAccessToken,
        owner: "NightfallRollup",
        repo: "nightfall-deployment",
        branch: "main",
        trigger: GitHubTrigger.WEBHOOK,
      }),

      // Build cloud assembly artifact
      synthAction: SimpleSynthAction.standardNpmSynth({
        sourceArtifact: sourceArtifact,
        cloudAssemblyArtifact,
        //installCommand: "npm install",
        installCommand: "cd aws/scripts && ENV_NAME=test REGION=eu-central-1 ./create-env.sh",
        buildCommand: "make deploy-diff",
      }),
    });

  */

     // Set your Github username and repository name
     const branch = 'main';
     const gitHubUsernameRepository = 'NightfallRollup/nightfall-deployment';

     const pipeline = new CodePipeline(this, 'Pipeline', {
         pipelineName: "TestCDKPipeline",
         role: codePipelineRole.withoutPolicyUpdates(),
         synth: new CodeBuildStep('SynthStep', {
             input: CodePipelineSource.gitHub(gitHubUsernameRepository, branch, {
                 authentication: githubAccessToken,
             }),
             installCommands: [
                 'cd aws/scripts && ENV_NAME=test REGION=eu-central-1 ./create-env.sh'
             ],
             commands: [
                'npm ci',
                'npm run build',
                'npx cdk synth'
            ]
         })
     });
 }
}

module.exports = { PipelineStack };