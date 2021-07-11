#!/bin/bash

AIRFLOW_ENV_TYPE="dev"

#docker container stop postgres
docker volume rm ${AIRFLOW_ENV_TYPE}-postgres-db-volume
docker secret rm $(docker secret ls -q)
rm -rf logs