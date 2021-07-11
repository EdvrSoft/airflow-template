# Airflow-template
Create airflow env (celery executor) for dev. 


# How to use it?

```
chmod +x create_env.sh
./create_env.sh
```

It will create a docker swarm airflow instance. it includes dags, logs, plugins folder.

If you want to keep your settings, use **docker stack rm** and **docker stack deploy -c airflow.yml**.

# Clean up

```
chmod +x clean.sh
./clean.sh
```

It removes all secret, log folder and volume.