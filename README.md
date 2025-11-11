# Official configurations for the docker setup of TOLERANT Post
## The configurations for each released version can be found under tags


## Package Content

```
+-- config
|   +-- grafana
|   |   +-- dashboards
|   |   |   +-- dashboard.yml            # a configuration file for grafana
|   |   |   +-- main_dashboard.json      # an example dashboard to display metrics data
|   |   +-- datasources
|   |       +-- datasource.yml           # an example datasource's configuration to request the data from
|   +-- keycloak
|   |   +-- import
|   |       +-- tolerant-realm.json      # an example keycloak configuration for TOLERANT
|   +-- nginx
|   |   +-- locations
|   |       +-- keycloak.loc.template    # an example of nginx location configuration for forwarding request to the keycloak example
|   |   +-- ssl
|   |   |   +-- certs                    # a folder to store the self-assigned certificate for the nginx 
|   |   |   +-- private                  # a folder to store the private key for the nginx
|   |   +-- default.conf.template        # an example of nginx configuration for forwarding request to TOLERANT Post
|   |   +-- default.no.gui.conf.template # an example of nginx configuration without gui for forwarding request to TOLERANT Post
|   |   +-- httppaswd                    # an example password file in case of basic auth
|   |   +-- ssl.conf.template            # an example of nginx configuration for forwarding https request to TOLERANT Post
|   |   +-- ssl.no.gui.conf.template     # an example of nginx configuration without gui for forwarding https request to TOLERANT Post
|   +-- openssl
|   |   +-- docker-entrypoint.sh         # an entrypoint for the openssl image to create ssl certificates 
|   |   +-- Dockerfile                   # a dockerfile to build the openssl image on startup
|   +-- prometheus
|       +-- prometheus.yml               # a prometheus configuration for collecting metrics data
+-- .env                                 # a file containing variables for the compose files
+-- compose.yml                          # an example configuration for docker compose
+-- compose-batch.yml                    # an example configuration for a batch process in docker compose
+-- compose-secure.yml                   # an example configuration for docker compose with keycloak and https
+-- README.md
```

## Steps to use your own identity provider

-  Make sure, that you have configured your identity provider having a client with clientId and realm matching the values of **TOLERANT_CLIENT_ID** and **TOLERANT_REALM** in the .env file
-  Remove postgres and keycloak from the compose-secure.yml, this includes **services**, **volumes** and **depends_on** sections.
-  Remove the variables **INTERNAL_IDENTITY_PROVIDER_URL** and **INTERNAL_IDENTITY_PROVIDER_PORT** from the **proxy** service in the compose-secure.yml
-  Adjust **INTERNAL_IDENTITY_PROVIDER_URL** and **IDENTITY_PROVIDER_URL** in the .env file to the URL of your identity provider.
-  Remove the mount for the keycloak location from the **proxy** service in the compose-secure.yml

## Steps to use your own ssl certificate
-  Remove openssl from the compose-secure.yml, this includes **services**, **volumes_from** and **depends_on** sections.
-  Comment in the volumes of the proxy service for ssl certificates in the compose-secure.yml
-  Make sure that the ssl certificate and key are under the mounted directory's mentioned in step before
-  Make sure that the variables **CERT_FILENAME** and **CERT_PRIVATE_KEY_FILENAME** in the .env file match your filenames

## Steps to use without gui

### Without security
- Replace the mount for the default.conf.template file for **proxy** with a mount for default.no.gui.conf.template file in the compose.yml
- Remove gui from the compose.yml, this includes **services** and **depends_on** sections.

### With enabled security
- Replace the mount for the ssl.conf.template file for **proxy** with a mount for ssl.no.gui.conf.template file in the compose-secure.yml
- Remove gui from the compose-secure.yml, this includes **services** and **depends_on** sections.

## Usage

### Starting

**The services can be started using the following commands:**

Without security:

```sh
docker compose up -d
```

With enabled security:

```sh
docker compose -f compose-secure.yml up -d
```

The `docker compose` command should be executed from the directory containing the `compose.yml or compose-secure.yml` file.


### Stopping

**The running services can be stopped using the following commands:**

Without security:

```sh
docker compose down
```

With enabled security:

```sh
docker compose -f compose-secure.yml down
```


The `docker compose` command should be executed from the directory containing the `compose.yml or compose-secure.yml` file.

### Starting a batch process
>**Note**
> The config file and the reference data must exist inside the container.

A batch process can be stated with the following example

```sh
docker compose -f compose-batch.yml up -d
```

Removing the container after it has exited

```sh
docker compose -f compose-batch.yml down
```

Steps to use your own configuration and data for a batch process
- mount your configuration and data to the batch container
- adjust the entry point of the `compose-batch.yml` to match the following pattern:
```yaml
entrypoint: ["postBatch.sh", "<configFilename>", "<projectId>", "<profileId>"]
```

### Starting with local user and group

To start with a different user please use the following instructions:

* create the following directories using the local user
    * post-config
    * post-data
    * post-logs
    * post-protocols
* use the fully qualified path of the above mentioned directories in the compose.yml or compose-secure.yml
* comment in the **user** setting for the **backend** and the **gui** service
* start the compose file

Without security:

```sh
export UID=`id -u`; export GID=`id -g`; docker compose up -d
```

With enabled security:

```sh
export UID=`id -u`; export GID=`id -g`; docker compose -f compose-secure.yml up -d
```

The `docker compose` command should be executed from the directory containing the `compose.yml or compose-secure.yml` file.

### Stopping with local user and group

```sh
export UID=`id -u`; export GID=`id -g`; docker compose down
```

With enabled security:

```sh
export UID=`id -u`; export GID=`id -g`; docker compose -f compose-secure.yml down
```

The `docker compose` command should be executed from the directory containing the `compose.yml or compose-secure.yml` file.