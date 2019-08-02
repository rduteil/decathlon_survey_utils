#!/bin/bash

if [ "$#" -ne 1 ]; then
    echo "Usage: ./pull_n_run.sh \$DOCKER_USERNAME... exiting with code 1"
    exit 1
fi

echo "--- STOPPING FORMER CONTAINERS -------"
docker stop decathlon_front
docker stop decathlon_back
docker stop decathlon_proxy
docker stop decathlon_db
echo "--- REMOVING FORMER CONTAINERS -------"
docker rm decathlon_front
docker rm decathlon_back
docker rm decathlon_proxy
docker rm decathlon_db
echo "--- PULLING IMAGES FROM DOCKER HUB ---"
docker pull $1/decathlon_front
docker pull $1/decathlon_back
docker pull $1/decathlon_proxy
docker pull $1/decathlon_db
echo "--- RUNNING DATABASE CONTAINER --"
docker run -d -p 5432:5432 --name decathlon_db $1/decathlon_db
echo "--- RUNNING FRONT-END CONTAINER ------"
docker run -d -p 5000:5000 --name decathlon_front $1/decathlon_front

sleep 5

echo "--- RUNNING BACK-END CONTAINER -------"
docker run -d -p 8000:8000 --name decathlon_back $1/decathlon_back
echo "--- RUNNING REVERSE-PROXY CONTAINER --"
docker run -d -p 80:80 --name decathlon_proxy $1/decathlon_proxy

echo "Production server IP address?"
read PROD_SERVER_IP

while ! [[ $PROD_SERVER_IP =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]
do
	echo "That was not a valid IP address, try again:"
	read PROD_SERVER_IP
done

echo "Choose a name for your first administrator:"
read ADMIN_USERNAME

echo "Choose a password for your first administrator:"
read -s ADMIN_PASSWORD

echo "Enter it again, for verification purpose:"
read -s ADMIN_PASSWORD_VERIFICATION

while [[ "$ADMIN_PASSWORD" != "$ADMIN_PASSWORD_VERIFICATION" ]]
do
	echo "Those two passwords are different, try again:"
	read -s ADMIN_PASSWORD

	echo "Of course you have to enter it one more time:"
	read -s ADMIN_PASSWORD_VERIFICATION
done

echo "Choose a name for the service of your first administrator:"
read SERVICE_NAME

echo "--- UPDATING DATABASE ----------------"
docker exec -it decathlon_back php bin/console doctrine:schema:validate
docker exec -it decathlon_back php bin/console doctrine:schema:update --force

echo "--- CREATING ADMINISTRATOR ACCOUNT ---"
curl -X POST http://$PROD_SERVER_IP/graphql -H 'Cache-Control: no-cache' -d '{"query":"mutation AddFrstAdmin($input: UserInput!, $serviceName: String!){\n  addFirstAdmin(input: $input, serviceName: $serviceName) {\n    id\n    username\n}\n}\n", "variables":{"input":{"username":"'$ADMIN_USERNAME'", "password":"'$ADMIN_PASSWORD'", "email": "", "roles": [], "serviceId": 0}, "serviceName": "'$SERVICE_NAME'"}, "operationName":"AddFirstAdmin"}'







