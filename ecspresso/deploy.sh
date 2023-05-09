#!/usr/bin/env bash
ECR_REPOSITORY=newanigram-api
REMOTE_ORIGIN=git@github.com:tuananhhedspibk/NewAnigram-BE-DDD.git

BRANCH_NAME=$1

if [[ -z "$BRANCH_NAME" ]];
then
  echo "Must specify branch name"
  exit 0
fi

SHA1=$(git ls-remote $REMOTE_ORIGIN $BRANCH_NAME | awk '{ print $1 }')

if [[ -z $SHA1 ]];
then
  echo "Can not get sha1 of branch: $BRANCH_NAME"
  exit 0
fi

check_ecr_image() {
  echo "Getting ecr image of sha1: ${SHA1}..."

  APP_IMAGE=$(aws ecr list-images --repository-name $ECR_REPOSITORY --query "imageIds[*].imageTag")

  if echo $APP_IMAGE | jq .[] | xargs echo | grep -q $SHA1; then
    echo "Got ecr image of sha1: ${SHA1}"
  else
    echo "Can not get ecr image of sha1: ${SHA1}"
    exit 0
  fi
}

get_commit_message() {
  if [ ${#SHA1} -gt 0 ]; then
    echo "git fetching ..."
    $(git fetch $REMOTE_ORIGIN $BRANCH_NAME &>/dev/null)
    COMMIT_MESSAGE=$(git log --format=%B -n 1 $SHA1 2>/dev/null | awk 'NR==1')
  fi
  COMMIT_MESSAGE=${COMMIT_MESSAGE:-"Can not get commit message"}
}

check_ecr_image
get_commit_message

ECSPRESSO_CONFIG="ecs_config/config.yaml"

export TARGET_COMMIT=$SHA1

ecspresso deploy --config $ECSPRESSO_CONFIG
