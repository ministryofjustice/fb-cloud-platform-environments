#!/bin/sh

HERE=$0

usage () {
  echo "
USAGE

  generate_config.sh -p platform [-d deployment] [-c context] [-fh]

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

  -f, --force          generate stub values files if they do not already exist
  -h, --help           help
"

# -n, --dry-run        show commands that would be run

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
        -f | --force)
            FORCE=true
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
    if [ "$FORCE" = "true" ]; then
      if [ "$2" = "" ]; then
        echo "$1 does not exist"
        exit 1
      fi
      if [ "$3" = "" ]; then
        environmentName="$2"
        echo "environmentName: $environmentName" >> "$1"
      else
        environmentName="$2-$3"
        platformEnvironment="$2"
        deploymentEnvironment="$3"
        echo "environmentName: $environmentName" >> "$1"
        echo "platformEnvironment: $platformEnvironment" >> "$1"
        echo "deploymentEnvironment: $deploymentEnvironment" >> "$1"
      fi
    else
      echo "$1 does not exist"
      exit 1
    fi
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
CPE_DIR=$CPE_DIR/namespaces/live-1.cloud-platform.service.justice.gov.uk

for PLATFORM_ENV in ${PLATFORM_ENVS[*]};
do

  if [ "$FB_PUBLISHER" != "false" ]; then
    PUBLISHER_DIR=$CPE_DIR/formbuilder-publisher-$PLATFORM_ENV
    mkdir -p $PUBLISHER_DIR/resources
    for CONFIG in $(basename -s .yaml -- ./formbuilder-publisher/templates/*.yaml);
    do
      PUBLISHER_VALUES="./formbuilder-publisher/values/$PLATFORM_ENV-values.yaml"
      check_config_exists $PUBLISHER_VALUES $PLATFORM_ENV
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

    for CONFIG in $(basename -s .yaml -- ./formbuilder-platform/templates/*.yaml);
    do
      PLATFORM_FILE="./formbuilder-platform/values/$PLATFORM_ENV-$DEPLOYMENT_ENV-values.yaml"
      check_config_exists $PLATFORM_FILE $PLATFORM_ENV $DEPLOYMENT_ENV
      helm template formbuilder-platform -f $PLATFORM_FILE -x templates/$CONFIG.yaml > $PLATFORM_DIR/$CONFIG.yaml
    done

    for PLATFORM_RESOURCE in $(basename -s .tf -- ./formbuilder-platform/resources/*.tf);
    do
      if [[ "$PLATFORM_RESOURCE" == 'variables' ]]; then
        continue
      fi

      PLATFORM_RESOURCE_FILE="./formbuilder-platform/resources/$PLATFORM_RESOURCE.tf"
      check_config_exists $PLATFORM_RESOURCE_FILE
      cp $PLATFORM_RESOURCE_FILE $PLATFORM_DIR/resources/$PLATFORM_RESOURCE.tf
    done
    node scripts/generate-terraform-variables.js --chart formbuilder-platform --env $PLATFORM_ENV-$DEPLOYMENT_ENV > $PLATFORM_DIR/resources/variables.tf

    SERVICES_DIR=$CPE_DIR/formbuilder-services-$PLATFORM_ENV-$DEPLOYMENT_ENV
    mkdir -p $SERVICES_DIR
    for CONFIG in $(basename -s .yaml -- ./formbuilder-services/templates/*.yaml);
    do
      SERVICES_FILE="./formbuilder-services/values/$PLATFORM_ENV-$DEPLOYMENT_ENV-values.yaml"
      check_config_exists $SERVICES_FILE $PLATFORM_ENV $DEPLOYMENT_ENV
      helm template formbuilder-services -f $SERVICES_FILE -x templates/$CONFIG.yaml > $SERVICES_DIR/$CONFIG.yaml
    done
  done
done
