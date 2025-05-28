# Package Content

```
+-- config       # an empty config directory for the compose example
+-- data         # an empty data directory for the compose example
+-- compose.yml  # an example configuration for docker compose
+-- README.md
```

# Usage

**Notes**
> * The container needs licenses and reference data to run properly. For proper test licences and testdata please contact  <support@tolerant-software.de>.
> * The required memory depends on the amount of reference data used.
> * We recommend to use docker volumes instead of bind mounts in production environments.

## Starting

The container can be started using the following command:

```sh
docker compose up -d
```

The `docker compose` command should be executed from the directory containing the `compose.yml` file.


## Stopping

A running container can be stopped using the following command:


```sh
docker compose down
```

The `docker compose` command should be executed from the directory containing the `compose.yml` file.

## Starting a batch process
>**Note**
> The Post container must be running to execute this command. <br>
> The config file and the reference data must exist inside the container.

```sh
docker compose exec post postBatch.sh <configFilename> <projectId> <profileId>
```