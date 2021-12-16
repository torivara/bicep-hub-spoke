# Bicep Hub Spoke (WORK IN PROGRESS)

This started as a demonstration made for an internal presentation of Bicep where I work. I am lucky to work in a place where community is important, and increasing each others competency is in focus.

## Disclaimer

>Use this as an inspiration for your own deployment, or copy the code as a starter environment. It doesn't matter, really, but please make sure you vet the code before using it for something important. This is a private project of mine, and in no way endorsed by my employer.
>It will not be maintained indefinitely, and it will contain bugs (as all code do).

## Structure

## Documentation

### Prerequisites

- An Azure Tenant (Azure Active Directory)
- An active Azure Subscription or more
  - Best case you have one subscription for platform (hub/connectivity/management/identity) and different subscriptions for each spoke.
    - This topology is inspired by Microsoft CAF Enterprise Scale Landing Zones reference design [TreyResearch](https://github.com/Azure/Enterprise-Scale/tree/main/docs/reference/treyresearch).
  - This framework is scoped for deploying to several subscriptions, but I will be deploying everything to a single subscription for example purposes.
- One or more service principals for deploying your infrastructure
- Owner permission on your wanted top level management group
  - This is not considered best practice, and effort should be made to restrict these permissions as much as possible.
  - Principle of least privilege is an important security concept.
- Repository secrets
  - AZURE_CREDENTIALS as specified [here](https://github.com/marketplace/actions/azure-login#configure-deployment-credentials).
  - Use Environment secrets if this is available to you, but this requires paying for GitHub, and not everyone does that.

## Workflows

### DevSecOps with Checkov

Down the line, I want to implement an infrastructure security check based on customizable policies from Checkov. I am not sure this is possible in Bicep yet, but will keep my eyes open for when this will be supported. I know this can be run on Terraform, and it might be runable on ARM. On second thought, I could actually build the json files and run some checking on them with ARM-TTK or Checkov while waiting for full support in Bicep. Stay tuned.

### Linting

Linting is performed by [super-linter](https://github.com/github/super-linter), both for all code and documentation. This is a simple solution which gives some extra stability and predictability for the repository.

### Validation

Validation of the code is done with a combination of Checkov, ARM-TTK and bicep validation. Secondly a more validation done with what-if-deployment.

### Deployment

Deployment is a basic management group az deployment command.