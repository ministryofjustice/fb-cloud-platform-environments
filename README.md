# fb-cloud-platform-environments

Generate Cloud Platform Environments k8s and terraform config for Form Builder namespaces

## Pre-requisites

- Node
- Helm

## Installation

`npm install`

## Usage

`scripts/generate-config.sh`

By default, this generates the necessary namespace configuration for the publisher, platform apps and services in all platform environments

- test
- integration
- live

for all deployment environments

- dev
- staging
- production

To see available options, run the script with `-h` flag

## Templates and values

### Platform apps

Used to create formbuilder-platform-$PLATFORM_ENV-$DEPLOYMENT_ENV namespace

- `formbuilder-platform/templates`
- `formbuilder-platform/resources`
- `formbuilder-platform/values/$PLATFORM_ENV-$DEPLOYMENT_ENV-values.yaml`

### Services

Used to create formbuilder-services-$PLATFORM_ENV-$DEPLOYMENT_ENV namespace

- `formbuilder-services/templates`
- `formbuilder-services/values/$PLATFORM_ENV-$DEPLOYMENT_ENV-values.yaml`

### Publisher

Used to create formbuilder-publisher-$PLATFORM_ENV namespace

- `formbuilder-publisher/templates`
- `formbuilder-publisher/resources`
- `formbuilder-publisher/values/$PLATFORM_ENV-values.yaml`

NB. there is only one publisher namespace for a platform which can deploy to all the deployment environments within it.