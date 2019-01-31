#!/bin/sh

HERE=$0

usage () {
  if [ "$FB_DEPLOYMENT_ENV" != "none" ]; then
    DEPLOYMENT_ENV_EXAMPLE="[-d deployment] "
    DEPLOYMENT_ENV_USAGE="
  -d, --deployment (optional)

    dev|staging|production

    Deployment environment to deploy to
    If not specified, defaults to all environments
  "
  fi
  echo "
USAGE

  deploy_platform.sh -p platform $DEPLOYMENT_ENV_EXAMPLE[-c context] [-nh]

PARAMETERS

  -p, --platform

    Platform environments to create namespace configuration for

    If not specified, defaults to all default platform environments

    test|integration|live

  -d, --deployment (optional)

    Deployment environments to create namespace configuration for

    If not specified, defaults to all deployment environments

    dev|staging|production

  --publisher [true|false] (optional)

    Whether to generate equivalent publisher namespace for platform environment

    If true, platform-deployment namespaces will be skipped if --deplopyment is not set explicitly

  -r, --cpe-repo (optional)

    Path to Cloud Platform Environments repo (cloud-platform-environments)
    If not specified, defaults to the assumption that is in the same directory as fb-cloud-platform-environments

FLAGS

  -n, --dry-run        show commands that would be run
  -h, --help           help
"

  EXIT_CODE=$1
  [ "$EXIT_CODE" = "" ] && EXIT_CODE=0
  exit $EXIT_CODE
}

PLATFORM_ENVS=($FB_PLATFORM_ENV)
DEPLOYMENT_ENVS=($FB_DEPLOYMENT_ENV)

while [ "$1" != "" ]; do
    INPUT=$1
    PARAM=`echo $1 | awk -F= '{print $1}'`
    VALUE=`echo $1 | sed 's/^[^=]*=//g'`
    shift
    if [ "$VALUE" = "$PARAM" ]; then
      VALUE=""
    fi
    case $PARAM in
        -h | --help)
            usage
            exit
            ;;
        -p | --platform)
            if [ "$VALUE" = "" ]; then
              VALUE=$1
              shift
            fi
            PLAT_LENGTH=${#PLATFORM_ENVS[@]}
            PLATFORM_ENVS[$PLAT_LENGTH]=$VALUE
            ;;
        -d | --deployment)
            if [ "$VALUE" = "" ]; then
              VALUE=$1
              shift
            fi
            DEP_LENGTH=${#DEPLOYMENT_ENVS[@]}
            DEPLOYMENT_ENVS[$DEP_LENGTH]=$VALUE
            ;;
        --publisher)
            if [ "$VALUE" = "" ]; then
              VALUE=$1
              shift
            fi
            FB_PUBLISHER=$VALUE
            ;;
        -r | --cpe-repo)
            if [ "$VALUE" = "" ]; then
              VALUE=$1
              shift
            fi
            CPE_DIR=$VALUE
            ;;
        # -n | --dry-run)
        #     DRY_RUN=true
        #     ;;
        *)
            echo "Unknown parameter \"$PARAM\""
            # usage 1
            ;;
    esac
done

# if [ "$PLATFORM_ENV" = "" ]; then
#   echo "
# --platform must be set

#   "
#   usage 1
# fi



if [ "$CPE_DIR" = "" ]; then
  CHANGEPATH=$(dirname "$HERE")
  CHANGEPATH="$CHANGEPATH/../../cloud-platform-environments"
  CPE_DIR=$( cd "$CHANGEPATH" ; pwd -P )
fi

if [ ! -d "$CPE_DIR" ]; then
  echo "
No deployment repo found at $CPE_DIR

  "
  usage 2
fi

check_config_exists () {
  if [ ! -f "$1" ]; then
    echo "$1 does not exist"
    exit 1
  fi
}

PLAT_LENGTH=${#PLATFORM_ENVS[@]}
if [ "$PLAT_LENGTH" = "0" ]; then
  PLATFORM_ENVS=("test" "integration" "live")
fi

DEP_LENGTH=${#DEPLOYMENT_ENVS[@]}
if [ "$DEP_LENGTH" = "0" ]; then
  if [ "$FB_PUBLISHER" != "true" ]; then
    DEPLOYMENT_ENVS=("dev" "staging" "production")
  fi
fi

# add path to namespaces
CPE_DIR=$CPE_DIR/namespaces/cloud-platform-live-0.k8s.integration.dsd.io

for PLATFORM_ENV in ${PLATFORM_ENVS[*]};
do

  if [ "$FB_PUBLISHER" != "false" ]; then
    PUBLISHER_DIR=$CPE_DIR/formbuilder-publisher-$PLATFORM_ENV
    mkdir -p $PUBLISHER_DIR/resources
    PUBLISHER_CONFIG=("00-namespace" "01-rbac" "02-limitrange" "03-resourcequota" "04-networkpolicy" "publisher-workers-service-account")
    for CONFIG in ${PUBLISHER_CONFIG[*]};
    do
      PUBLISHER_VALUES="./formbuilder-publisher/values/$PLATFORM_ENV-values.yaml"
      check_config_exists $PUBLISHER_VALUES
      helm template formbuilder-publisher -f $PUBLISHER_VALUES -x templates/$CONFIG.yaml > $PUBLISHER_DIR/$CONFIG.yaml
    done
    PUBLISHER_RESOURCES=("main" "publisher")
    for PUBLISHER_RESOURCE in ${PUBLISHER_RESOURCES[*]};
    do
      RESOURCE_FILE="./formbuilder-publisher/resources/$PUBLISHER_RESOURCE.tf"
      check_config_exists $RESOURCE_FILE
      cp $RESOURCE_FILE $PUBLISHER_DIR/resources/$PUBLISHER_RESOURCE.tf
    done
    node scripts/generate-terraform-variables.js --chart formbuilder-publisher --env $PLATFORM_ENV > $PUBLISHER_DIR/resources/variables.tf
  fi

  for DEPLOYMENT_ENV in ${DEPLOYMENT_ENVS[*]};
  do
    PLATFORM_DIR=$CPE_DIR/formbuilder-platform-$PLATFORM_ENV-$DEPLOYMENT_ENV
    mkdir -p $PLATFORM_DIR/resources
    PLATFORM_CONFIG=("00-namespace" "01-rbac" "02-limitrange" "03-resourcequota" "04-networkpolicy" "service-token-cache-service-account" "submitter-workers-service-account" "user-datastore-service-account")
    for CONFIG in ${PLATFORM_CONFIG[*]};
    do
      PLATFORM_FILE="./formbuilder-platform/values/$PLATFORM_ENV-$DEPLOYMENT_ENV-values.yaml"
      check_config_exists $PLATFORM_FILE
      helm template formbuilder-platform -f $PLATFORM_FILE -x templates/$CONFIG.yaml > $PLATFORM_DIR/$CONFIG.yaml
    done
    PLATFORM_RESOURCES=("main" "service_token_cache" "submitter" "user-datastore")
    for PLATFORM_RESOURCE in ${PLATFORM_RESOURCES[*]};
    do
      PLATFORM_RESOURCE_FILE="./formbuilder-platform/resources/$PLATFORM_RESOURCE.tf"
      check_config_exists $PLATFORM_RESOURCE_FILE
      cp $PLATFORM_RESOURCE_FILE $PLATFORM_DIR/resources/$PLATFORM_RESOURCE.tf
    done
    node scripts/generate-terraform-variables.js --chart formbuilder-platform --env $PLATFORM_ENV-$DEPLOYMENT_ENV > $PLATFORM_DIR/resources/variables.tf

    SERVICES_DIR=$CPE_DIR/formbuilder-services-$PLATFORM_ENV-$DEPLOYMENT_ENV
    mkdir -p $SERVICES_DIR
    SERVICES_CONFIG=("00-namespace" "01-rbac" "02-limitrange" "03-resourcequota" "04-networkpolicy")
    for CONFIG in ${SERVICES_CONFIG[*]};
    do
      SERVICES_FILE="./formbuilder-services/values/$PLATFORM_ENV-$DEPLOYMENT_ENV-values.yaml"
      check_config_exists $SERVICES_FILE
      helm template formbuilder-services -f $SERVICES_FILE -x templates/$CONFIG.yaml > $SERVICES_DIR/$CONFIG.yaml
    done
    
  done
done
