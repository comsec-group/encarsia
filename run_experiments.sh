#!/bin/bash

image_name="ethcomsec/encarsia-artifacts:latest"
username=$(whoami)
container_name="encarsia_scripted"

if [ -n "$(docker ps -q -f name=$container_name)" ]; then
  echo "Container is already running."
elif [ -n "$(docker ps -a -q -f name=$container_name)" ]; then
  echo "Container is stopped."
  echo "Starting the container..."
  docker start $container_name
else
  echo "Container does not exist."
  echo "Setting up the container..."
  docker run --name $container_name -d -i -t $image_name /bin/bash
fi

echo "Starting the experiments..."
docker exec -t $container_name bash -c "python /encarsia-meta/encarsia.py -d /encarsia-meta/out/Injection -H ibex rocket -p 30"
docker exec -t $container_name bash -c "python /encarsia-meta/encarsia.py -d /encarsia-meta/out/EnCorpus -H ibex rocket -p 30 -Y"
docker exec -t $container_name bash -c "python /encarsia-meta/encarsia.py -d /encarsia-meta/out/EnCorpus -H boom -p 8 -Y"
docker exec -t $container_name bash -c "python /encarsia-meta/encarsia.py -d /encarsia-meta/out/EnCorpus -H rocket boom -p 30 -F no_cov_difuzzrtl no_cov_processorfuzz"
docker exec -t $container_name bash -c "python /encarsia-meta/encarsia.py -d /encarsia-meta/out/EnCorpus -H rocket boom -p 30 -F difuzzrtl processorfuzz"
docker exec -t $container_name bash -c "python /encarsia-meta/encarsia.py -d /encarsia-meta/out/EnCorpus -H rocket boom -p 30 -F difuzzrtl cascade"
echo "Experiments completed."

echo "Attaching to the container..."
docker attach $container_name