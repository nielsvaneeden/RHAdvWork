#!/bin/bash
# Setup Production Project (initial active services: Green)
if [ "$#" -ne 1 ]; then
    echo "Usage:"
    echo "  $0 GUID"
    exit 1
fi

GUID=$1
echo "Setting up Parks Production Environment in project ${GUID}-parks-prod"

# Code to set up the parks production project. It will need a StatefulSet MongoDB, and two applications each (Blue/Green) for NationalParks, MLBParks and Parksmap.
# The Green services/routes need to be active initially to guarantee a successful grading pipeline run.

# To be Implemented by Student
oc policy add-role-to-user view --serviceaccount=default -n $GUID-parks-prod
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n $GUID-parks-prod
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n $GUID-parks-prod

MONGODB_DATABASE="mongodb"
MONGODB_USERNAME="mongodb_user"
MONGODB_PASSWORD="mongodb_password"
MONGODB_SERVICE_NAME="mongodb"
MONGODB_ADMIN_PASSWORD="mongodb_admin_password"
MONGODB_VOLUME="4Gi"

oc new-app -f ./Infrastructure/templates/mongo-stateful.template.yaml \
    -n $GUID-parks-prod\
    --param MONGODB_DATABASE=${MONGODB_DATABASE}\
    --param MONGODB_USERNAME=${MONGODB_USERNAME}\
    --param MONGODB_PASSWORD=${MONGODB_PASSWORD}\
    --param MONGODB_ADMIN_PASSWORD=${MONGODB_ADMIN_PASSWORD}\
    --param MONGODB_VOLUME=${MONGODB_VOLUME}\
    --param MONGODB_SERVICE_NAME=${MONGODB_SERVICE_NAME}

# config map
oc create configmap parks-mongodb-config \
    --from-literal=DB_HOST=${MONGODB_SERVICE_NAME}\
    --from-literal=DB_PORT=27017\
    --from-literal=DB_USERNAME=${MONGODB_USERNAME}\
    --from-literal=DB_PASSWORD=${MONGODB_PASSWORD}\
    --from-literal=DB_NAME=${MONGODB_DATABASE}\
    --from-literal=DB_REPLICASET=rs0 \
    -n $GUID-parks-prod

# parksmap
oc new-app $GUID-parks-prod/parksmap-green:0.0 --name=parksmap-green \
    --allow-missing-imagestream-tags=true \
    --allow-missing-images=true \
    -l type=parksmap-frontend \
    -e APPNAME="ParksMap (Green)"\
    -n $GUID-parks-prod
oc set triggers dc/parksmap-green --remove-all -n $GUID-parks-prod
oc rollout cancel dc/parksmap-green -n $GUID-parks-prod
oc set probe dc/parksmap-green --readiness \
    --get-url=http://:8080/ws/appname/ --initial-delay-seconds=60 \
    --failure-threshold 5 -n $GUID-parks-prod
oc set probe dc/parksmap-green --liveness \
    --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=60 \
    --failure-threshold 5 -n $GUID-parks-prod

oc new-app $GUID-parks-prod/parksmap-blue:0.0 --name=parksmap-blue \
    --allow-missing-imagestream-tags=true \
    --allow-missing-images=true \
    -l type=parksmap-frontend \
    -e APPNAME="ParksMap (Blue)"\
    -n $GUID-parks-prod
oc set triggers dc/parksmap-blue --remove-all -n $GUID-parks-prod
oc rollout cancel dc/parksmap-blue -n $GUID-parks-prod
oc set probe dc/parksmap-blue --readiness \
    --get-url=http://:8080/ws/appname/ --initial-delay-seconds=60 \
    --failure-threshold 5 -n $GUID-parks-prod
oc set probe dc/parksmap-blue --liveness \
    --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=60 \
    --failure-threshold 5 -n $GUID-parks-prod

oc expose dc/parksmap-green --port=8080 -l type=parksmap-frontend -n $GUID-parks-prod
oc expose dc/parksmap-blue --port=8080 -l type=parksmap-frontend -n $GUID-parks-prod
oc expose svc/parksmap-green --name=parksmap -n $GUID-parks-prod

# nationalparks
oc new-app $GUID-parks-prod/nationalparks-green:0.0 --name=nationalparks-green \
    --allow-missing-imagestream-tags=true \
    --allow-missing-images=true \
    -l type=parksmap-backend \
    -e APPNAME="National Parks (Green)" \
    -e DB_HOST=$MONGODB_SERVICE_NAME \
    -e DB_PORT=27017 \
    -e DB_USERNAME=$MONGODB_USERNAME \
    -e DB_PASSWORD=$MONGODB_PASSWORD \
    -e DB_NAME=$MONGODB_DATABASE \
    -n $GUID-parks-prod
oc set triggers dc/nationalparks-green --remove-all -n $GUID-parks-prod
oc rollout cancel dc/nationalparks-green -n $GUID-parks-prod
oc set env dc/nationalparks-green --from configmap/parks-mongodb-config -n $GUID-parks-prod
oc set probe dc/nationalparks-green --readiness \
    --get-url=http://:8080/ws/info/ --initial-delay-seconds=30 \
    --failure-threshold 3 -n $GUID-parks-prod
oc set probe dc/nationalparks-green --liveness \
    --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30 \
    --failure-threshold 3 -n $GUID-parks-prod

oc new-app $GUID-parks-prod/nationalparks-blue:0.0 --name=nationalparks-blue \
    --allow-missing-imagestream-tags=true \
    --allow-missing-images=true \
    -l type=parksmap-backend \
    -e APPNAME="National Parks (Blue)" \
    -e DB_HOST=$MONGODB_SERVICE_NAME \
    -e DB_PORT=27017 \
    -e DB_USERNAME=$MONGODB_USERNAME \
    -e DB_PASSWORD=$MONGODB_PASSWORD \
    -e DB_NAME=$MONGODB_DATABASE \
    -n $GUID-parks-prod
oc set triggers dc/nationalparks-blue --remove-all -n $GUID-parks-prod
oc rollout cancel dc/nationalparks-blue -n $GUID-parks-prod
oc set env dc/nationalparks-blue --from configmap/parks-mongodb-config -n $GUID-parks-prod
oc set probe dc/nationalparks-blue --readiness \
    --get-url=http://:8080/ws/info/ --initial-delay-seconds=30 \
    --failure-threshold 3 -n $GUID-parks-prod
oc set probe dc/nationalparks-blue --liveness \
    --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30 \
    --failure-threshold 3 -n $GUID-parks-prod

# oc create service clusterip nationalparks-green --tcp=8080 -n $GUID-parks-prod
# oc create service clusterip nationalparks-blue --tcp=8080 -n $GUID-parks-prod
oc expose dc/nationalparks-green --port=8080 -l type=parksmap-backend -n $GUID-parks-prod
oc expose dc/nationalparks-blue --port=8080 -l type=parksmap-backend -n $GUID-parks-prod
oc expose svc/nationalparks-green --name=nationalparks -n $GUID-parks-prod

# mlbparks
oc new-app $GUID-parks-prod/mlbparks-green:0.0 --name=mlbparks-green \
    --allow-missing-imagestream-tags=true \
    --allow-missing-images=true \
    -l type=parksmap-backend \
    -e APPNAME="MLB Parks (Green)" \
    -e DB_HOST=$MONGODB_SERVICE_NAME \
    -e DB_PORT=27017 \
    -e DB_USERNAME=$MONGODB_USERNAME \
    -e DB_PASSWORD=$MONGODB_PASSWORD \
    -e DB_NAME=$MONGODB_DATABASE \
    -n $GUID-parks-prod
oc set triggers dc/mlbparks-green --remove-all -n $GUID-parks-prod
oc rollout cancel dc/mlbparks-green -n $GUID-parks-prod
oc set env dc/mlbparks-green --from configmap/parks-mongodb-config -n $GUID-parks-prod
oc set probe dc/mlbparks-green --readiness \
    --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30 -n $GUID-parks-prod
oc set probe dc/mlbparks-green --liveness \
    --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30 -n $GUID-parks-prod

oc new-app $GUID-parks-prod/mlbparks-blue:0.0 --name=mlbparks-blue \
    --allow-missing-imagestream-tags=true \
    --allow-missing-images=true \
    -l type=parksmap-backend \
    -e APPNAME="MLB Parks (Blue)" \
    -e DB_HOST=$MONGODB_SERVICE_NAME \
    -e DB_PORT=27017 \
    -e DB_USERNAME=$MONGODB_USERNAME \
    -e DB_PASSWORD=$MONGODB_PASSWORD \
    -e DB_NAME=$MONGODB_DATABASE \
    -n $GUID-parks-prod
oc set triggers dc/mlbparks-blue --remove-all -n $GUID-parks-prod
oc rollout cancel dc/mlbparks-blue -n $GUID-parks-prod
oc set env dc/mlbparks-blue --from configmap/parks-mongodb-config -n $GUID-parks-prod
oc set probe dc/mlbparks-blue --readiness \
    --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30 -n $GUID-parks-prod
oc set probe dc/mlbparks-blue --liveness \
    --get-url=http://:8080/ws/healthz/ --initial-delay-seconds=30 -n $GUID-parks-prod

oc expose dc/mlbparks-green --port=8080 -l type=parksmap-backend -n $GUID-parks-prod
oc expose dc/mlbparks-blue --port=8080 -l type=parksmap-backend -n $GUID-parks-prod
oc expose svc/mlbparks-green --name=mlbparks -n $GUID-parks-prod

# set resource limits
oc set resources dc/parksmap-blue --limits=memory=1Gi --requests=memory=0.5Gi -n $GUID-parks-prod
oc set resources dc/parksmap-green --limits=memory=1Gi --requests=memory=0.5Gi -n $GUID-parks-prod
oc set resources dc/mlbparks-blue --limits=memory=1Gi --requests=memory=0.5Gi -n $GUID-parks-prod
oc set resources dc/mlbparks-green --limits=memory=1Gi --requests=memory=0.5Gi -n $GUID-parks-prod
oc set resources dc/nationalparks-green --limits=memory=1Gi --requests=memory=0.5Gi -n $GUID-parks-prod
oc set resources dc/nationalparks-blue --limits=memory=1Gi --requests=memory=0.5Gi -n $GUID-parks-prod
