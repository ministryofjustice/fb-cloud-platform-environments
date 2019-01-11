#!/bin/sh

# set CPE_DIR to any value passed in
# if none, use any existing value set for the CPE_DIR ENV var
[[ "$1" != "" ]] && CPE_DIR="$1" || CPE_DIR="$CPE_DIR"
# Stop if no value for CPE_DIR
[[ "$CPE_DIR" = "" ]] && echo "Usage\n\nPass the path to your Cloud Platforms Environment repo or export it as CPE_DIR\n\n\tscripts/generate-config.sh path/to/cpe\n\n\tCPE_DIR=path/to/cpe scripts/generate-config.sh" && exit 1

# add path to namespaces
CPE_DIR=$CPE_DIR/namespaces/cloud-platform-live-0.k8s.integration.dsd.io

PLATFORM_ENVS=("test")
# PLATFORM_ENVS=("test" "integration" "live")

for PLATFORM_ENV in ${PLATFORM_ENVS[*]};
do
  PUBLISHER_DIR=$CPE_DIR/formbuilder-publisher-$PLATFORM_ENV
  mkdir -p $PUBLISHER_DIR
  PUBLISHER_CONFIG=("00-namespace" "01-rbac" "02-limitrange" "03-resourcequota" "04-networkpolicy" "publisher-workers-service-account")
  for CONFIG in ${PUBLISHER_CONFIG[*]};
  do
    helm template formbuilder-publisher -f ./formbuilder-publisher/values/$PLATFORM_ENV-values.yaml -x templates/$CONFIG.yaml > $PUBLISHER_DIR/$CONFIG.yaml
  done
  # TODO: template and copy resources to $PUBLISHER_DIR/resources

  DEPLOYMENT_ENVS=("dev")
  # DEPLOYMENT_ENVS=("dev" "staging" "production")
  for DEPLOYMENT_ENV in ${DEPLOYMENT_ENVS[*]};
  do
    PLATFORM_DIR=$CPE_DIR/formbuilder-platform-$PLATFORM_ENV-$DEPLOYMENT_ENV
    mkdir -p $PLATFORM_DIR
    PLATFORM_CONFIG=("00-namespace" "01-rbac" "02-limitrange" "03-resourcequota" "04-networkpolicy" "service-token-cache-service-account" "submitter-workers-service-account" "user-datastore-service-account")
    for CONFIG in ${PLATFORM_CONFIG[*]};
    do
      # TODO: values for $PLATFORM_ENV or $PLATFORM_ENV-$DEPLOYMENT_ENV?
      helm template formbuilder-platform -f ./formbuilder-platform/values/$PLATFORM_ENV-$DEPLOYMENT_ENV-values.yaml -x templates/$CONFIG.yaml > $PLATFORM_DIR/$CONFIG.yaml
    done
    # TODO: template and copy resources to $PLATFORM_DIR/resources

    SERVICES_DIR=$CPE_DIR/formbuilder-services-$PLATFORM_ENV-$DEPLOYMENT_ENV
    mkdir -p $SERVICES_DIR
    SERVICES_CONFIG=("00-namespace" "01-rbac" "02-limitrange" "03-resourcequota" "04-networkpolicy")
    for CONFIG in ${SERVICES_CONFIG[*]};
    do
      # TODO: values for $PLATFORM_ENV or $PLATFORM_ENV-$DEPLOYMENT_ENV?
      helm template formbuilder-services -f ./formbuilder-services/values/$PLATFORM_ENV-$DEPLOYMENT_ENV-values.yaml -x templates/$CONFIG.yaml > $SERVICES_DIR/$CONFIG.yaml
    done
    
  done
done
