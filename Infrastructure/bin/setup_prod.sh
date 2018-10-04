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
oc policy add-role-to-group system:image-puller system:serviceaccounts:$GUID-parks-prod -n $GUID-parks-prod
oc policy add-role-to-user edit system:serviceaccount:$GUID-jenkins:jenkins -n $GUID-parks-prod
oc policy add-role-to-user admin system:serviceaccount:gpte-jenkins:jenkins -n $GUID-parks-prod

#mongodb
MONGODB_DATABASE="mongodb"
MONGODB_USERNAME="mongodb"
MONGODB_PASSWORD="mongodb"
MONGODB_SERVICE_NAME="mongodb"
MONGODB_ADMIN_PASSWORD="mongodb"
MONGODB_VOLUME="4Gi"

oc new-app -f ./Infrastructure/templates/mongo-stateful.template.yaml \
    -n $GUID-parks-prod\
    --param MONGODB_DATABASE=${MONGODB_DATABASE}\
    --param MONGODB_USERNAME=${MONGODB_USERNAME}\
    --param MONGODB_PASSWORD=${MONGODB_PASSWORD}\
    --param MONGODB_ADMIN_PASSWORD=${MONGODB_ADMIN_PASSWORD}\
    --param MONGODB_VOLUME=${MONGODB_VOLUME}\
    --param MONGODB_SERVICE_NAME=${MONGODB_SERVICE_NAME}

#configmaps
oc create configmap mlbparks-blue-config --from-env-file=./Infrastructure/templates/MLBParks-blue.env -n ${GUID}-parks-prod
oc create configmap nationalparks-blue-config --from-env-file=./Infrastructure/templates/NationalParks-blue.env -n ${GUID}-parks-prod
oc create configmap parksmap-blue-config --from-env-file=./Infrastructure/templates/ParksMap-blue.env -n ${GUID}-parks-prod
oc create configmap mlbparks-green-config --from-env-file=./Infrastructure/templates/MLBParks-green.env -n ${GUID}-parks-prod
oc create configmap nationalparks-green-config --from-env-file=./Infrastructure/templates/NationalParks-green.env -n ${GUID}-parks-prod
oc create configmap parksmap-green-config --from-env-file=./Infrastructure/templates/ParksMap-green.env -n ${GUID}-parks-prod

#blue
oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=mlbparks-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=nationalparks-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=parksmap-blue --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

oc set triggers dc/mlbparks-blue --remove-all -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-blue --remove-all -n ${GUID}-parks-prod
oc set triggers dc/parksmap-blue --remove-all -n ${GUID}-parks-prod

oc set env dc/mlbparks-blue --from=configmap/mlbparks-blue-config -n ${GUID}-parks-prod
oc set env dc/nationalparks-blue --from=configmap/nationalparks-blue-config -n ${GUID}-parks-prod
oc set env dc/parksmap-blue --from=configmap/parksmap-blue-config -n ${GUID}-parks-prod

oc set probe dc/parksmap-blue --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/parksmap-blue --readiness --failure-threshold 5 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/mlbparks-blue --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/mlbparks-blue --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/nationalparks-blue --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/nationalparks-blue --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod

#green
oc new-app ${GUID}-parks-dev/mlbparks:0.0 --name=mlbparks-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/nationalparks:0.0 --name=nationalparks-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod
oc new-app ${GUID}-parks-dev/parksmap:0.0 --name=parksmap-green --allow-missing-imagestream-tags=true -n ${GUID}-parks-prod

oc set triggers dc/mlbparks-green --remove-all -n ${GUID}-parks-prod
oc set triggers dc/nationalparks-green --remove-all -n ${GUID}-parks-prod
oc set triggers dc/parksmap-green --remove-all -n ${GUID}-parks-prod

oc set env dc/mlbparks-green --from=configmap/mlbparks-green-config -n ${GUID}-parks-prod
oc set env dc/nationalparks-green --from=configmap/nationalparks-green-config -n ${GUID}-parks-prod
oc set env dc/parksmap-green --from=configmap/parksmap-green-config -n ${GUID}-parks-prod

oc set probe dc/parksmap-green --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/parksmap-green --readiness --failure-threshold 5 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/mlbparks-green --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/mlbparks-green --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod
oc set probe dc/nationalparks-green --liveness --failure-threshold 5 --initial-delay-seconds 30 -- echo ok -n ${GUID}-parks-prod
oc set probe dc/nationalparks-green --readiness --failure-threshold 3 --initial-delay-seconds 60 --get-url=http://:8080/ws/healthz/ -n ${GUID}-parks-prod

#expose
oc expose dc mlbparks-green --port 8080 -n ${GUID}-parks-prod
oc expose dc nationalparks-green --port 8080 -n ${GUID}-parks-prod
oc expose dc parksmap-green --port 8080 -n ${GUID}-parks-prod

oc expose dc mlbparks-blue --port 8080 -n ${GUID}-parks-prod
oc expose dc nationalparks-blue --port 8080 -n ${GUID}-parks-prod
oc expose dc parksmap-blue --port 8080 -n ${GUID}-parks-prod

#set green live
oc expose svc mlbparks-green --name mlbparks -n ${GUID}-parks-prod --labels="type=parksmap-backend"
oc expose svc nationalparks-green --name nationalparks -n ${GUID}-parks-prod --labels="type=parksmap-backend"
oc expose svc parksmap-green --name parksmap -n ${GUID}-parks-prod

oc set deployment-hook dc/mlbparks-green  -n ${GUID}-parks-prod --post -c mlbparks-green --failure-policy=ignore -- curl http://mlbparks-green.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/nationalparks-green  -n ${GUID}-parks-prod --post -c nationalparks-green --failure-policy=ignore -- curl http://nationalparks-green${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/parksmap-green  -n ${GUID}-parks-prod --post -c parksmap-green --failure-policy=ignore -- curl http://mlbparks-green.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/

oc set deployment-hook dc/mlbparks-blue  -n ${GUID}-parks-prod --post -c mlbparks-blue --failure-policy=ignore -- curl http://mlbparks-blue.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/nationalparks-blue  -n ${GUID}-parks-prod --post -c nationalparks-blue --failure-policy=ignore -- curl http://nationalparks-blue.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
oc set deployment-hook dc/parksmap-blue  -n ${GUID}-parks-prod --post -c parksmap-blue --failure-policy=ignore -- curl http://mlbparks-blue.${GUID}-parks-prod.svc.cluster.local:8080/ws/data/load/
