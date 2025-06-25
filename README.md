# Karned Development Environment

This directory contains the Docker Compose configuration for the Karned development environment.

## Services

The environment includes the following services:

### Databases
- **MongoDB**: Available on port 5971
- **Redis**: Available on port 5972
- **MariaDB**: Available on port 5973
- **PostgreSQL**: Available on port 5974
- **Neo4j**: Available on ports 5975 (HTTP) and 5976 (Bolt)
- **CouchDB**: Available on port 5977

### Services
- **Keycloak**: Available on port 5990
- **Vault**: Available on port 5991
- **Grafana**: Available on port 5992
- **Prometheus**: Available on port 5993
- **MinIO**: Available on ports 5994 (API) and 5995 (Console)

### API Services
- **API Gateway**: Available on port 9000
- **Auth API**: Available on port 9001
- **Credential API**: Available on port 9002
- **License API**: Available on port 9003
- **Recipe API**: Available on port 9005

## Container Names

The containers are explicitly named:
- `karned-mongodb`
- `karned-redis`
- `karned-mariadb`
- `karned-postgres`
- `karned-neo4j`
- `karned-couchdb`
- `karned-keycloak`
- `karned-vault`
- `karned-grafana`
- `karned-prometheus`
- `karned-minio`
- `karned-api-gateway`
- `karned-api-auth`
- `karned-api-credential`
- `karned-api-license`
- `karned-api-recipe`

## Setup

1. Run the script to create the Docker network:
   ```
   ./create_karned_network.sh
   ```

2. Start the services:
   ```
   docker compose up -d
   ```

3. To stop the services:
   ```
   docker compose down
   ```

## Accessing Services
### Databases
- **MongoDB**: Connect to `mongodb://localhost:5971`
- **Redis**: Connect to `redis://localhost:5972`
- **MariaDB**: Connect to `mysql://localhost:5973`
- **PostgreSQL**: Connect to `postgresql://localhost:5974`
- **Neo4j**: 
  - Browser interface: `http://localhost:5975`
  - Bolt protocol: `bolt://localhost:5976`
- **CouchDB**: Access at `http://localhost:5977`

### Services
- **Keycloak**: Access the admin console at `http://localhost:5990`
- **Vault**: Access the UI at `http://localhost:5991`
- **Grafana**: Access the dashboard at `http://localhost:5992`
- **Prometheus**: Access the UI at `http://localhost:5993`
- **MinIO**: 
  - API: `http://localhost:5994`
  - Console: `http://localhost:5995`

### API Services
- **API Gateway**: Access at `http://localhost:9000`
- **Auth API**: Access at `http://localhost:9001`
- **Credential API**: Access at `http://localhost:9002`
- **License API**: Access at `http://localhost:9003`
- **Recipe API**: Access at `http://localhost:9005`

## Credentials
### Databases
- **MongoDB**: No authentication is set by default
- **Redis**: No authentication is set by default
- **MariaDB**:
  - Root Username: `root`
  - Root Password: `root`
  - Database: `karned`
- **PostgreSQL**:
  - Username: `postgres`
  - Password: `postgres`
  - Database: `karned`
- **Neo4j**:
  - Username: `neo4j`
  - Password: `password`
- **CouchDB**:
  - Username: `admin`
  - Password: `password`

### Services
- **Keycloak Admin Console**:
  - Username: `admin`
  - Password: `admin`
- **Vault**:
  - Token: `root`
- **Grafana**:
  - Default admin credentials (username: `admin`, password: `admin`)
- **MinIO**:
  - Access Key: `minioadmin`
  - Secret Key: `minioadmin`
