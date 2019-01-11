#!/bin/sh

CPE_DIR=$1

CPE_DIR=$CPE_DIR/namespaces/cloud-platform-live-0.k8s.integration.dsd.io

PLATFORM_ENVS=("test")
# PLATFORM_ENVS=("test" "integration" "live")

for PLATFORM_ENV in ${PLATFORM_ENVS[*]};
do
  PUBLISHER_DIR=$CPE_DIR/formbuilder-publisher-$PLATFORM_ENV
  mkdir -p $PUBLISHER_DIR
  helm template fb-publisher -f ./fb-publisher/values/$PLATFORM_ENV-values.yaml > $PUBLISHER_DIR/k8.yaml
  # TODO: copy resources to $PUBLISHER_DIR/resources

  DEPLOYMENT_ENVS=("dev")
  # DEPLOYMENT_ENVS=("dev" "staging" "production")
  for DEPLOYMENT_ENV in ${DEPLOYMENT_ENVS[*]};
  do
    PLATFORM_DIR=$CPE_DIR/formbuilder-platform-$PLATFORM_ENV-$DEPLOYMENT_ENV
    mkdir -p $PLATFORM_DIR
    # TODO: values for $PLATFORM_ENV or $PLATFORM_ENV-$DEPLOYMENT_ENV?
    # helm template fb-platform -f ./fb-platform/values/$PLATFORM_ENV-values.yaml > $PLATFORM_DIR/k8.yaml
    # TODO: copy resources to $PLATFORM_DIR/resources

    SERVICES_DIR=$CPE_DIR/formbuilder-services-$PLATFORM_ENV-$DEPLOYMENT_ENV
    mkdir -p $SERVICES_DIR
    # TODO: values for $PLATFORM_ENV or $PLATFORM_ENV-$DEPLOYMENT_ENV?
    # helm template fb-services -f ./fb-services/values/$PLATFORM_ENV-values.yaml > $SERVICES_DIR/k8.yaml
    # TODO: copy resources to $SERVICES_DIR/resources
    
  done
done