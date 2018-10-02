#!/bin/bash
# Setup Sonarqube Project
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Sonarqube in project $GUID-sonarqube"
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n $GUID-sonarqube
oc policy add-role-to-user edit system:serviceaccount:gpte-jenkins:jenkins -n $GUID-sonarqube

# Code to set up the SonarQube project.
# Ideally just calls a template
# oc new-app -f ./Infrastructure/templates/sonarqube.yaml --param .....

# To be Implemented by Student
oc new-app -f ./Infrastructure/templates/sonarqube.template.yaml\
  --param GUID=$GUID\
  -n $GUID-sonarqube
