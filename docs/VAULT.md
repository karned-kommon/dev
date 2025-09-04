# HashiCorp Vault - Guide d'utilisation

## Informations de connexion

### Accès Web
- **URL**: [http://localhost:5991/ui](http://localhost:5991/ui)
- **Token Root**: `hvs.Mnvqo3FVx9A7eIrM6CbOzrsw`

### API
- **Endpoint**: `http://localhost:5991`
- **Version**: v1.20.0

## Configuration actuelle

### Stockage
- **Type**: File storage (persistant)
- **Chemin**: `/vault/data` (monté depuis `.vault_data/`)
- **Fichiers de données**:
  - `core/` - Données principales de Vault
  - `logical/` - Moteurs de secrets
  - `sys/` - Configuration système

### Sécurité
- **Mode**: Production (non-dev)
- **Clés de déverrouillage**: 1 clé requise sur 1 total
- **Auto-unseal**: ✅ Activé (service `karned-vault-unseal`)
- **TLS**: Désactivé (développement uniquement)

## Utilisation

### Scripts disponibles

#### Déverrouillage manuel
```bash
./scripts/vault-manual-unseal.sh
```

#### Service automatique
Le service `karned-vault-unseal` surveille Vault et le déverrouille automatiquement :
- **Intervalle**: 5 secondes
- **Logs**: `docker logs karned-vault-unseal`

### API - Exemples d'utilisation

#### Vérifier l'état
```bash
curl -s http://localhost:5991/v1/sys/health | jq
```

#### Authentification
```bash
export VAULT_TOKEN="hvs.Mnvqo3FVx9A7eIrM6CbOzrsw"
export VAULT_ADDR="http://localhost:5991"
```

#### Créer un secret
```bash
curl -X POST \
  -H "X-Vault-Token: $VAULT_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{"data": {"username": "admin", "password": "secret123"}}' \
  http://localhost:5991/v1/secret/data/myapp/config
```

#### Lire un secret
```bash
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  http://localhost:5991/v1/secret/data/myapp/config | jq .data.data
```

#### Lister les secrets
```bash
curl -H "X-Vault-Token: $VAULT_TOKEN" \
  http://localhost:5991/v1/secret/metadata?list=true | jq
```

### Via l'interface web

1. Ouvrir [http://localhost:5991/ui](http://localhost:5991/ui)
2. Sélectionner "Token" comme méthode d'authentification
3. Saisir le token: `hvs.Mnvqo3FVx9A7eIrM6CbOzrsw`
4. Naviguer dans les secrets via le menu "Secrets" > "secret/"

## Secrets préconfigurés

Les secrets suivants sont automatiquement créés lors de l'initialisation :

### Base de données MongoDB
```
Path: entities/c1d2e3f4-g5h6-i7j8-k9l0-m1n2o3p4qf3a/licenses/a1b2c3d4-e5f6-7890-1234-567890abcdef/database
Data: {
  "uri": "mongodb://karned-mongodb:27017/karned"
}
```

```
Path: entities/c1d2e3f4-g5h6-i7j8-k9l0-m1n2o3p4j5rf/licenses/b1b2c3d4-e5f6-7890-1234-567890ghijk/database
Data: {
  "uri": "mongodb://karned-mongodb:27017/karned"
}
```

## Maintenance

### Sauvegarde
Les données importantes sont dans :
- `.vault_data/vault-keys.json` - **CRUCIAL** : Clés de déverrouillage et token root
- `.vault_data/core/` - Données de configuration Vault
- `.vault_data/logical/` - Secrets stockés
- `.vault_data/sys/` - Configuration système

### Redémarrage
1. Le service auto-unseal déverrouillera automatiquement Vault
2. En cas de problème, utiliser : `./scripts/vault-manual-unseal.sh`

### Régénération des clés
⚠️ **ATTENTION** : Ne pas perdre le fichier `vault-keys.json` !

En cas de perte :
1. Sauvegarder `.vault_data/`
2. Arrêter Vault : `docker-compose stop vault`
3. Supprimer `.vault_data/vault-keys.json`
4. Redémarrer : `docker-compose up -d vault`
5. Réinitialiser avec de nouvelles clés

## Dépannage

### Vault scellé
```bash
# Vérifier l'état
curl -s http://localhost:5991/v1/sys/health | jq .sealed

# Déverrouiller manuellement
./scripts/vault-manual-unseal.sh
```

### Service auto-unseal non fonctionnel
```bash
# Vérifier les logs
docker logs karned-vault-unseal

# Redémarrer le service
docker-compose restart vault-unseal
```

### Vault non accessible
```bash
# Vérifier le statut du conteneur
docker ps | grep vault

# Vérifier les logs
docker logs karned-vault

# Redémarrer Vault
docker-compose restart vault
```

## Sécurité en production

⚠️ **Cette configuration est pour le développement uniquement !**

Pour la production :
1. Activer TLS/HTTPS
2. Utiliser un stockage externe (Consul, etcd, cloud)
3. Configurer l'auto-unseal avec un KMS cloud
4. Implémenter une rotation des tokens
5. Configurer des politiques d'accès granulaires
6. Mettre en place une sauvegarde automatique
