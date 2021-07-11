#!/bin/bash

AIRFLOW_ENV_TYPE="dev"
AIRFLOW_VERSION="apache/airflow:2.1.1"
FERNET_KEY=$(docker container run --rm -v $(pwd)/script:/tmp/ ${AIRFLOW_VERSION} python /tmp/create_fernet.py)
printf ${FERNET_KEY} | docker secret create ${AIRFLOW_ENV_TYPE}_airflow__core__fernet_key -

POSTGRES_USER=""$(openssl rand -base64 32 | tr -d /=+ | cut -c -20)
POSTGRES_PASSWORD=""$(openssl rand -base64 32 | tr -d /=+ | cut -c -30)
printf ${POSTGRES_USER} | docker secret create "${AIRFLOW_ENV_TYPE}_airflow_postgres_user" -
printf ${POSTGRES_PASSWORD} | docker secret create "${AIRFLOW_ENV_TYPE}_airflow_postgres_password" -

#AIRFLOW__CORE__SQL_ALCHEMY_CONN
AIRFLOW__CORE__SQL_ALCHEMY_CONN="postgresql+psycopg2://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/airflow"
printf ${AIRFLOW__CORE__SQL_ALCHEMY_CONN} | docker secret create "${AIRFLOW_ENV_TYPE}_airflow__core__sql__alchemy__conn" -
#AIRFLOW__CELERY__RESULT_BACKEND
AIRFLOW__CELERY__RESULT_BACKEND="db+postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@postgres/airflow"
printf ${AIRFLOW__CELERY__RESULT_BACKEND} | docker secret create "${AIRFLOW_ENV_TYPE}_airflow__celery__result_backend" -

#Create folder structure
mkdir dags
mkdir logs
#if you use set uid/gid in airflow.yml, you can delete this.
chmod 777 logs
mkdir plugins

#Create db
docker network create -d bridge tmp_db_airflow_create

docker container run \
--rm \
-d \
--env POSTGRES_USER=$POSTGRES_USER \
--env POSTGRES_PASSWORD=$POSTGRES_PASSWORD \
--env POSTGRES_DB="airflow" \
-v ${AIRFLOW_ENV_TYPE}-postgres-db-volume:/var/lib/postgresql/data \
-p 5432:5432 \
--network tmp_db_airflow_create \
--health-cmd="pg_isready -U airflow" \
--health-interval=5s \
--health-retries=5 \
--name postgres \
postgres:13 \
\

docker container run \
--rm \
--network tmp_db_airflow_create \
--env AIRFLOW__CORE__EXECUTOR="CeleryExecutor" \
--env AIRFLOW__CORE__SQL_ALCHEMY_CONN=$AIRFLOW__CORE__SQL_ALCHEMY_CONN \
--env AIRFLOW__CELERY__RESULT_BACKEND=$AIRFLOW__CELERY__RESULT_BACKEND \
--env AIRFLOW__CELERY__BROKER_URL="redis://:@redis:6379/0" \
--env AIRFLOW__CORE__FERNET_KEY=$FERNET_KEY \
--env AIRFLOW__API__AUTH_BACKEND="airflow.api.auth.backend.basic_auth" \
--env _AIRFLOW_DB_UPGRADE="true" \
--env _AIRFLOW_WWW_USER_CREATE="true" \
--env _AIRFLOW_WWW_USER_USERNAME=${_AIRFLOW_WWW_USER_USERNAME:-airflow} \
--env _AIRFLOW_WWW_USER_PASSWORD=${_AIRFLOW_WWW_USER_PASSWORD:-airflow} \
--name ${AIRFLOW_ENV_TYPE}_start_airflow \
$AIRFLOW_VERSION version \
\

#Clean workspace
docker container stop postgres
docker network rm tmp_db_airflow_create

#finally, deploy the airflow stack
docker stack deploy -c airflow.yml ${AIRFLOW_ENV_TYPE}