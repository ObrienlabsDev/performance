#!/bin/bash
# https://github.com/ObrienlabsDev/performance/issues/42
# Michael O'Brien
# docker login -u username with token before running - to push

TAG=0.0.1-arm
#TAG=0.0.1-ia64
SERVER=127.0.0.1
DOCKERHUB_REPO=obrienlabs

BUILD_ID=10001
BUILD_DIR=builds
mkdir ../../$BUILD_DIR
TARGET_DIR=../../$BUILD_DIR/$BUILD_ID
mkdir $TARGET_DIR
CONTAINER_IMAGE=java-vector-api-cli

# take the hit - as I forgot twice to rebuild - just ENV the parameters into spring boot
cd ../../
mvn clean install -U -DskipTests=true
cd src/docker

cp ../../target/*.jar $TARGET_DIR
cp DockerFile $TARGET_DIR
# use following to generate credentials
# gcloud auth application-default login 
#cp ~/.config/gcloud/application_default_credentials.json $TARGET_DIR

cd $TARGET_DIR
#docker build --no-cache --build-arg build-id=$BUILD_ID -t $CONTAINER_IMAGE -f DockerFile .
docker build --no-cache --build-arg build-id=$BUILD_ID -t $DOCKERHUB_REPO/$CONTAINER_IMAGE -f DockerFile .
#docker tag $CONTAINER_IMAGE:latest $CONTAINER_IMAGE:latest
docker tag $DOCKERHUB_REPO/$CONTAINER_IMAGE $DOCKERHUB_REPO/$CONTAINER_IMAGE:$TAG
# dockerhub
docker push $DOCKERHUB_REPO/$CONTAINER_IMAGE:$TAG


# locally
#CONTAINER_IMAGE2=biometric-nbi
docker stop $CONTAINER_IMAGE
docker rm $CONTAINER_IMAGE
docker run --name $CONTAINER_IMAGE -d -p 8888:8080 $DOCKERHUB_REPO/$CONTAINER_IMAGE:$TAG 
sleep 1
docker ps -a
docker logs $CONTAINER_IMAGE
#docker stop $CONTAINER_IMAGE2
#docker rm $CONTAINER_IMAGE2
#docker stop  mysql-dev0
#docker rm  mysql-dev0

#echo "starting: $CONTAINER_IMAGE"
#docker run --name $CONTAINER_IMAGE \
#    -d -p 8888:8080 \
#    -e os.environment.configuration.dir=/ \
#    -e os.environment.ecosystem=sbx \
#    $DOCKERHUB_REPO/$CONTAINER_IMAGE:$TAG
##docker run --name $CONTAINER_IMAGE2 \
#    -d -p 8889:8080 \
#    -e os.environment.configuration.dir=/ \
#    -e os.environment.ecosystem=sbx \
#    $DOCKERHUB_REPO/$CONTAINER_IMAGE:$TAG


cd ../../src/docker

#echo "http://127.0.0.1:8888/nbi/forward/packet?dnsFrom=host.docker.internal&dnsTo=host.docker.internal&from=8889&to=8888&delay=1000"
#echo "http://127.0.0.1:8888/nbi/forward/reset"
#echo "http://127.0.0.1:8889/nbi/forward/reset"

# mysql
# create network once
#docker network create --driver=bridge mysql
#docker run --network="mysql" --name mysql-dev0 -v mysql-data:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=$MYSQL_ROOT_PASSWORD -d -p 3506:3306 arm64v8/mysql:8.0.38
 

#echo "export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/application_default_credentials.json"
## --network="host"
#export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/application_default_credentials.json
#echo "docker run -d -p 8888:8080 --name biometric-nbi -e GOOGLE_APPLICATION_CREDENTIALS=application_default_credentials.json obrienlabs/$CONTAINER_IMAGE:$TAG"
#docker run -d -p 8888:8080 --network="mysql" --name biometric-nbi $DOCKERHUB_REPO/$CONTAINER_IMAGE:$TAG
#echo "curl -X GET \"http:/$SERVER:8888/nbi/api/getGps?ac=0&action=u2&arx=0&ary=0&arz=0&be=0&grx=0&gry=0&grz=0&gsx=0&gsy=0&gsz=0&hr1=0&hr2=0&hrd1=0&hrd2=0&hu=0&lax=0&lay=0&laz=0&li=0&lg=-75.940427&lt=45.343839&al=095.706317&mfx=0&mfy=0&mfz=0&p=0&pr=0&px=0&rvx=0&rvy=0&rvz=0&s=0&te=0&ts=0&u=202408040&up=0\" -H \"accept: */*\""
#echo "sleep 10 then check containers"
#sleep 10
#docker ps
#curl -X GET "http://$SERVER:8888/nbi/api/getGps?ac=0&action=u2&arx=0&ary=0&arz=0&be=0&grx=0&gry=0&grz=0&gsx=0&gsy=0&gsz=0&hr1=0&hr2=0&hrd1=0&hrd2=0&hu=0&lax=0&lay=0&laz=0&li=0&lg=-75.940427&lt=45.343839&al=095.706317&mfx=0&mfy=0&mfz=0&p=0&pr=0&px=0&rvx=0&rvy=0&rvz=0&s=0&te=0&ts=0&u=202408042&up=0" -H "accept: */*"
#sleep 3
#docker logs --tail 6 $CONTAINER_IMAGE
