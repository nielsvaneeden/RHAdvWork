#!/bin/bash
# Setup Jenkins Project
if [ "$#" -ne 3 ]; then
    echo "Usage:"
    echo "  $0 GUID REPO CLUSTER"
    echo "  Example: $0 wkha https://github.com/wkulhanek/ParksMap na39.openshift.opentlc.com"
    exit 1
fi

GUID=$1
REPO=$2
CLUSTER=$3
echo "Setting up Jenkins in project ${GUID}-jenkins from Git Repo ${REPO} for Cluster ${CLUSTER}"

# Code to set up the Jenkins project to execute the
# three pipelines.
# This will need to also build the custom Maven Slave Pod
# Image to be used in the pipelines.
# Finally the script needs to create three OpenShift Build
# Configurations in the Jenkins Project to build the
# three micro services. Expected name of the build configs:
# * mlbparks-pipeline
# * nationalparks-pipeline
# * parksmap-pipeline
# The build configurations need to have two environment variables to be passed to the Pipeline:
# * GUID: the GUID used in all the projects
# * CLUSTER: the base url of the cluster used (e.g. na39.openshift.opentlc.com)

# To be Implemented by Student
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n $GUID-jenkins
oc policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins -n $GUID-jenkins

oc new-app -f ./Infrastructure/templates/jenkins.template.yaml \
    --param MEMORY_LIMIT=1Gi \
    --param JENKINS_VOLUME=1Gi \
    -n $GUID-jenkins

oc rollout status dc/jenkins --watch -n $GUID-jenkins

oc new-build --name=jenkins-slave-appdev \
    --dockerfile="$(< ./Infrastructure/templates/docker/skopeo/Dockerfile)" \
    -n $GUID-jenkins

oc create -f ./Infrastructure/templates/nationalparks.pipeline.yaml -n $GUID-jenkins
oc create -f ./Infrastructure/templates/mlbparks.pipeline.yaml -n $GUID-jenkins
oc create -f ./Infrastructure/templates/parksmap.pipeline.yaml -n $GUID-jenkins

oc env bc/nationalparks-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $GUID-jenkins
oc env bc/mlbparks-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $GUID-jenkins
oc env bc/parksmap-pipeline GUID=$GUID CLUSTER=$CLUSTER -n $GUID-jenkins
