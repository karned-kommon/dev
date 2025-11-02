# Système de Logging Centralisé Karned

Ce document décrit le système de logging centralisé mis en place pour l'environnement Karned.

## Architecture

Le système utilise **syslog-ng** comme serveur de logs centralisé. Tous les services Docker envoient leurs logs via le driver syslog vers le serveur central.

### Composants

- **Serveur Syslog** : Container `karned-syslog` basé sur `balabit/syslog-ng:latest`
- **Configuration** : `config/syslog-ng.conf`
- **Stockage** : Volume `.syslog_data` monté sur `/var/log` dans le container syslog

## Ports

- **6000** : UDP - Réception des logs syslog
- **6001** : TCP - Réception des logs syslog  
- **6002** : TCP - Port de management syslog-ng

## Configuration des Services

Chaque service Docker est configuré avec le driver de logging syslog :

```yaml
logging:
  driver: "syslog"
  options:
    syslog-address: "tcp://karned-syslog:514"
    tag: "nom-du-service"
```

## Structure des Logs

### Fichiers de logs générés

- **`karned-all.log`** : Tous les logs de tous les services
- **`karned-structured.json`** : Logs au format JSON structuré
- **`karned-[service].log`** : Logs spécifiques par service

### Services avec logs dédiés

- **Bases de données** :
  - `karned-mongodb.log`
  - `karned-redis.log`  
  - `karned-mariadb.log`
  - `karned-postgres.log`
  - `karned-neo4j.log`
  - `karned-couchdb.log`

- **Services principaux** :
  - `karned-keycloak.log`
  - `karned-vault.log` (inclut vault-unseal)
  - `karned-elasticsearch.log`
  - `karned-kafka.log` (inclut kafka-ui)
  - `karned-grafana.log`
  - `karned-prometheus.log`
  - `karned-minio.log`

- **Services API** :
  - `karned-api-services.log` (tous les services api-* et ms-*)

- **Initialisation** :
  - `karned-init.log`

## Format des Logs

### Format standard
```
YYYY-MM-DD HH:MM:SS HOST PROGRAM[PID]: MESSAGE
```

### Format JSON structuré
```json
{
  "@timestamp": "2025-11-02T10:30:45.123Z",
  "host": "container-name",
  "program": "service-name",
  "message": "log message",
  "pid": "1234"
}
```

## Utilisation

### Démarrage du système
```bash
docker-compose up -d syslog
docker-compose up -d
```

### Consultation des logs

#### Tous les logs
```bash
docker exec karned-syslog tail -f /var/log/karned-all.log
```

#### Logs d'un service spécifique
```bash
docker exec karned-syslog tail -f /var/log/karned-mongodb.log
```

#### Logs JSON structurés
```bash
docker exec karned-syslog tail -f /var/log/karned-structured.json | jq .
```

### Accès aux logs depuis l'hôte
```bash
# Les logs sont accessibles via le volume Docker
docker volume inspect dev_syslog_data
# Ou directement dans le répertoire du projet
ls -la .syslog_data/
```

## Filtrage et Recherche

### Recherche dans tous les logs
```bash
docker exec karned-syslog grep "ERROR" /var/log/karned-all.log
```

### Recherche par service
```bash
docker exec karned-syslog grep "authentication failed" /var/log/karned-keycloak.log
```

### Analyse des logs JSON
```bash
docker exec karned-syslog cat /var/log/karned-structured.json | jq 'select(.program == "mongodb")'
```

## Maintenance

### Rotation des logs
Les logs peuvent grossir rapidement. Il est recommandé de mettre en place une rotation :

```bash
# Exemple de commande pour nettoyer les anciens logs
docker exec karned-syslog find /var/log -name "*.log" -type f -mtime +7 -delete
```

### Surveillance de l'espace disque
```bash
docker exec karned-syslog df -h /var/log
```

## Dépannage

### Vérifier le statut du serveur syslog
```bash
docker logs karned-syslog
```

### Tester la connectivité
```bash
# Depuis un autre container
docker exec karned-mongodb logger -h karned-syslog -p local0.info "Test message"
```

### Vérifier la configuration
```bash
docker exec karned-syslog syslog-ng --syntax-only -f /etc/syslog-ng/syslog-ng.conf
```

## Performance

Le serveur syslog-ng est optimisé pour :
- Traitement haute performance des logs
- Gestion de multiples connexions simultanées
- Formatage flexible des messages
- Routage intelligent par service

## Sécurité

- Les logs sont stockés localement dans le volume Docker
- Communication entre containers via réseau Docker interne
- Pas d'exposition des ports syslog vers l'extérieur (sauf pour debug)