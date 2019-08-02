#!/bin/bash

echo "Production server IP address?"
read PROD_SERVER_IP

while ! [[ $PROD_SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
do
	echo "That was not a valid IP address, try again:"
	read PROD_SERVER_IP
done

echo "Database user name?"
read DATABASE_USERNAME

echo "Database password?"
read -s DATABASE_PASSWORD

echo "Enter it again, for verification purpose:"
read -s DATABASE_PASSWORD_VERIFICATION

while [[ "$DATABASE_PASSWORD" != "$DATABASE_PASSWORD_VERIFICATION" ]]
do
	echo "Those two passwords are different, try again:"
	read -s DATABASE_PASSWORD

	echo "Of course you have to enter it one more time:"
	read -s DATABASE_PASSWORD_VERIFICATION
done

echo "Prepare to get logged into docker hub !"

echo "Docker hub username?"
read DOCKER_USERNAME

echo "Docker hub password?"
read -s DOCKER_PASSWORD


echo "--- LOGING INTO DOCKER HUB -----------"
docker login --username=$DOCKER_USERNAME --password=$DOCKER_PASSWORD
while ! [[ $? -eq 0 ]]
do 
	echo "Invalid credentials, try your docker hub username again:"
	read DOCKER_USERNAME

	echo "And your docker hub password:"
	read -s DOCKER_PASSWORD
	docker login --username=$DOCKER_USERNAME --password=$DOCKER_PASSWORD
done

echo "--- HERE WE GO MATE ! ----------------"
echo "--- CHANGING CONFIGURATION FILES -----"

sed -i -e "s|\$PROD_SERVER_IP|${PROD_SERVER_IP}|" decathlon_front/src/imports/helpers/Constants.js
sed -i -e "s|\$PROD_SERVER_IP|${PROD_SERVER_IP}|" nginx/nginx.conf
sed -i -e "s|\$PROD_SERVER_IP|${PROD_SERVER_IP}|" v4_api/app/config/parameters.yml
sed -i -e "s|\$PROD_SERVER_IP|${PROD_SERVER_IP}|" v4_api/app/config/parameters.yml.dist

sed -i -e "s|\$DATABASE_USERNAME|${DATABASE_USERNAME}|" v4_api/app/config/parameters.yml
sed -i -e "s|\$DATABASE_USERNAME|${DATABASE_USERNAME}|" v4_api/app/config/parameters.yml.dist
sed -i -e "s|\$DATABASE_USERNAME|${DATABASE_USERNAME}|" decathlon_db/Dockerfile

sed -i -e "s|\$DATABASE_PASSWORD|${DATABASE_PASSWORD}|" v4_api/app/config/parameters.yml
sed -i -e "s|\$DATABASE_PASSWORD|${DATABASE_PASSWORD}|" v4_api/app/config/parameters.yml.dist
sed -i -e "s|\$DATABASE_PASSWORD|${DATABASE_PASSWORD}|" decathlon_db/Dockerfile

echo "--- BUILDING IMAGES ------------------"
echo "--- BUILDING FRONT-END PROJECT -------"
cd decathlon_front
yarn
yarn build
cp Dockerfile ./build
cd build

echo "--- BUILDING FRON-END IMAGE ----------"
docker build -t decathlon_front .

echo "--- BUILDING DATABASE IMAGE ----------"
cd ../../decathlon_db
docker build -t decathlon_db .

echo "--- BUILDING BACK-END PROJECT --------"
cd ../v4_api
composer install

echo "--- BUILDING BACK-END IMAGE ----------"
docker build -t decathlon_back .

echo "--- BUILDING REVERSE-PROXY IMAGE -----"
cd ../nginx
docker build -t decathlon_proxy .

echo "--- TAGING IMAGES --------------------"
docker tag decathlon_front:latest $DOCKER_USERNAME/decathlon_front
docker tag decathlon_back:latest $DOCKER_USERNAME/decathlon_back
docker tag decathlon_proxy:latest $DOCKER_USERNAME/decathlon_proxy
docker tag decathlon_db:latest $DOCKER_USERNAME/decathlon_db

echo "--- PUSHING IMAGES TO DOCKER HUB -----"
docker push $DOCKER_USERNAME/decathlon_front
docker push $DOCKER_USERNAME/decathlon_back
docker push $DOCKER_USERNAME/decathlon_proxy
docker push $DOCKER_USERNAME/decathlon_db

echo "--- REMOVING UNTAGGED IMAGES ---------"
docker rmi $(docker images | grep '<none>' | awk '{print $3}')

echo "--- RESETING CONFIGURATION FILES -----"
cd ..
sed -i -e "s|${PROD_SERVER_IP}|\$PROD_SERVER_IP|" decathlon_front/src/imports/helpers/Constants.js
sed -i -e "s|${PROD_SERVER_IP}|\$PROD_SERVER_IP|" nginx/nginx.conf
sed -i -e "s|${PROD_SERVER_IP}|\$PROD_SERVER_IP|" v4_api/app/config/parameters.yml
sed -i -e "s|${PROD_SERVER_IP}|\$PROD_SERVER_IP|" v4_api/app/config/parameters.yml.dist

sed -i -e "s|${DATABASE_USERNAME}|\$DATABASE_USERNAME|" v4_api/app/config/parameters.yml
sed -i -e "s|${DATABASE_USERNAME}|\$DATABASE_USERNAME|" v4_api/app/config/parameters.yml.dist
sed -i -e "s|${DATABASE_USERNAME}|\$DATABASE_USERNAME|" decathlon_db/Dockerfile

sed -i -e "s|${DATABASE_PASSWORD}|\$DATABASE_PASSWORD|" v4_api/app/config/parameters.yml
sed -i -e "s|${DATABASE_PASSWORD}|\$DATABASE_PASSWORD|" v4_api/app/config/parameters.yml.dist
sed -i -e "s|${DATABASE_PASSWORD}|\$DATABASE_PASSWORD|" decathlon_db/Dockerfile

echo "--- DONE, EXITING --------------------"
exit 0
