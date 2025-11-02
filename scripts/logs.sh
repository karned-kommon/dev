#!/bin/bash

# Script utilitaire pour la gestion des logs centralisés Karned
# Usage: ./scripts/logs.sh [commande] [options]

set -e

SYSLOG_CONTAINER="karned-syslog"
LOG_DIR="/var/log"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction d'aide
show_help() {
    echo -e "${GREEN}Script de gestion des logs centralisés Karned${NC}"
    echo ""
    echo "Usage: $0 [COMMANDE] [OPTIONS]"
    echo ""
    echo "COMMANDES:"
    echo "  list                     Liste tous les fichiers de logs disponibles"
    echo "  tail [service]          Affiche les logs en temps réel (défaut: all)"
    echo "  search [terme] [service] Recherche un terme dans les logs"
    echo "  clean [jours]           Nettoie les logs plus anciens que X jours (défaut: 7)"
    echo "  stats                   Affiche les statistiques des logs"
    echo "  status                  Vérifie le statut du serveur syslog"
    echo "  test                    Teste l'envoi d'un message de test"
    echo "  json [service]          Affiche les logs JSON filtrés par service"
    echo ""
    echo "SERVICES DISPONIBLES:"
    echo "  all, mongodb, redis, keycloak, vault, elasticsearch, kafka,"
    echo "  grafana, prometheus, minio, mariadb, postgres, neo4j,"
    echo "  couchdb, init, api-services"
    echo ""
    echo "EXEMPLES:"
    echo "  $0 tail mongodb         # Logs MongoDB en temps réel"
    echo "  $0 search ERROR         # Recherche toutes les erreurs"
    echo "  $0 clean 3              # Supprime les logs > 3 jours"
    echo "  $0 json api-services    # Logs JSON des services API"
}

# Vérifier si le container syslog existe et fonctionne
check_syslog_container() {
    if ! docker ps | grep -q "$SYSLOG_CONTAINER"; then
        echo -e "${RED}Erreur: Le container $SYSLOG_CONTAINER n'est pas en cours d'exécution${NC}"
        echo "Démarrez-le avec: docker-compose up -d syslog"
        exit 1
    fi
}

# Lister tous les fichiers de logs
list_logs() {
    echo -e "${BLUE}Fichiers de logs disponibles:${NC}"
    docker exec "$SYSLOG_CONTAINER" find "$LOG_DIR" -name "*.log" -o -name "*.json" | sort
    echo ""
    echo -e "${BLUE}Taille des logs:${NC}"
    docker exec "$SYSLOG_CONTAINER" du -h "$LOG_DIR"/* 2>/dev/null | sort -hr
}

# Afficher les logs en temps réel
tail_logs() {
    local service=${1:-"all"}
    local log_file
    
    case $service in
        "all")
            log_file="$LOG_DIR/karned-all.log"
            ;;
        "structured"|"json")
            log_file="$LOG_DIR/karned-structured.json"
            ;;
        *)
            log_file="$LOG_DIR/karned-${service}.log"
            ;;
    esac
    
    echo -e "${GREEN}Affichage des logs: $service${NC}"
    echo -e "${YELLOW}Fichier: $log_file${NC}"
    echo "Pressez Ctrl+C pour arrêter"
    echo ""
    
    if [[ $service == "structured" || $service == "json" ]]; then
        docker exec "$SYSLOG_CONTAINER" tail -f "$log_file" | jq -r '. | "\(.["@timestamp"]) [\(.program)] \(.message)"' 2>/dev/null || \
        docker exec "$SYSLOG_CONTAINER" tail -f "$log_file"
    else
        docker exec "$SYSLOG_CONTAINER" tail -f "$log_file"
    fi
}

# Rechercher dans les logs
search_logs() {
    local term=$1
    local service=${2:-"all"}
    
    if [[ -z "$term" ]]; then
        echo -e "${RED}Erreur: Terme de recherche requis${NC}"
        exit 1
    fi
    
    local log_file
    if [[ "$service" == "all" ]]; then
        log_file="$LOG_DIR/karned-all.log"
    else
        log_file="$LOG_DIR/karned-${service}.log"
    fi
    
    echo -e "${GREEN}Recherche de '$term' dans $service${NC}"
    docker exec "$SYSLOG_CONTAINER" grep -i --color=always "$term" "$log_file" 2>/dev/null || \
    echo -e "${YELLOW}Aucun résultat trouvé${NC}"
}

# Nettoyer les anciens logs
clean_logs() {
    local days=${1:-7}
    
    echo -e "${YELLOW}Nettoyage des logs de plus de $days jours...${NC}"
    
    # Compter les fichiers avant suppression
    local count_before
    count_before=$(docker exec "$SYSLOG_CONTAINER" find "$LOG_DIR" -name "*.log" -o -name "*.json" | wc -l)
    
    # Supprimer les anciens fichiers
    docker exec "$SYSLOG_CONTAINER" find "$LOG_DIR" -name "*.log" -type f -mtime +$days -delete
    docker exec "$SYSLOG_CONTAINER" find "$LOG_DIR" -name "*.json" -type f -mtime +$days -delete
    
    # Compter les fichiers après suppression
    local count_after
    count_after=$(docker exec "$SYSLOG_CONTAINER" find "$LOG_DIR" -name "*.log" -o -name "*.json" | wc -l)
    
    local deleted=$((count_before - count_after))
    echo -e "${GREEN}$deleted fichiers supprimés${NC}"
}

# Afficher les statistiques
show_stats() {
    echo -e "${BLUE}Statistiques des logs:${NC}"
    echo ""
    
    echo -e "${GREEN}Espace disque utilisé:${NC}"
    docker exec "$SYSLOG_CONTAINER" df -h "$LOG_DIR"
    echo ""
    
    echo -e "${GREEN}Nombre de lignes par service:${NC}"
    for log_file in $(docker exec "$SYSLOG_CONTAINER" find "$LOG_DIR" -name "karned-*.log" | sort); do
        local service=$(basename "$log_file" .log | sed 's/karned-//')
        local lines=$(docker exec "$SYSLOG_CONTAINER" wc -l < "$log_file" 2>/dev/null || echo "0")
        printf "  %-20s: %'d lignes\n" "$service" "$lines"
    done
    echo ""
    
    echo -e "${GREEN}Dernière activité par service:${NC}"
    for log_file in $(docker exec "$SYSLOG_CONTAINER" find "$LOG_DIR" -name "karned-*.log" | sort); do
        local service=$(basename "$log_file" .log | sed 's/karned-//')
        local last_mod=$(docker exec "$SYSLOG_CONTAINER" stat -c %y "$log_file" 2>/dev/null | cut -d. -f1 || echo "N/A")
        printf "  %-20s: %s\n" "$service" "$last_mod"
    done
}

# Vérifier le statut du serveur syslog
check_status() {
    echo -e "${BLUE}Statut du serveur syslog:${NC}"
    echo ""
    
    # Statut du container
    if docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep "$SYSLOG_CONTAINER"; then
        echo -e "${GREEN}Container: En cours d'exécution${NC}"
    else
        echo -e "${RED}Container: Arrêté${NC}"
        return 1
    fi
    
    echo ""
    
    # Vérification de la configuration
    echo -e "${GREEN}Vérification de la configuration:${NC}"
    if docker exec "$SYSLOG_CONTAINER" syslog-ng --syntax-only -f /etc/syslog-ng/syslog-ng.conf 2>/dev/null; then
        echo -e "${GREEN}Configuration: Valide${NC}"
    else
        echo -e "${RED}Configuration: Erreurs détectées${NC}"
    fi
    
    echo ""
    
    # Logs récents du container
    echo -e "${GREEN}Logs récents du container:${NC}"
    docker logs --tail 10 "$SYSLOG_CONTAINER"
}

# Tester l'envoi d'un message
test_logging() {
    local test_message="Test message from logs.sh at $(date)"
    
    echo -e "${YELLOW}Envoi d'un message de test...${NC}"
    
    # Envoyer via logger si disponible dans le container
    if docker exec "$SYSLOG_CONTAINER" which logger >/dev/null 2>&1; then
        docker exec "$SYSLOG_CONTAINER" logger -p local0.info "$test_message"
        echo -e "${GREEN}Message envoyé avec succès${NC}"
        
        echo ""
        echo -e "${BLUE}Vérification dans les logs:${NC}"
        sleep 2
        docker exec "$SYSLOG_CONTAINER" tail -n 5 "$LOG_DIR/karned-all.log" | grep "Test message" || \
        echo -e "${YELLOW}Message non trouvé dans les logs récents${NC}"
    else
        echo -e "${RED}Logger non disponible dans le container${NC}"
    fi
}

# Afficher les logs JSON filtrés
json_logs() {
    local service=${1:-""}
    local log_file="$LOG_DIR/karned-structured.json"
    
    echo -e "${GREEN}Logs JSON structurés${NC}"
    if [[ -n "$service" ]]; then
        echo -e "${YELLOW}Filtrés pour le service: $service${NC}"
        docker exec "$SYSLOG_CONTAINER" cat "$log_file" | jq --arg svc "$service" 'select(.program == $svc)' 2>/dev/null || \
        echo -e "${RED}Erreur lors du filtrage JSON${NC}"
    else
        echo -e "${YELLOW}Tous les services${NC}"
        docker exec "$SYSLOG_CONTAINER" cat "$log_file" | jq . 2>/dev/null || \
        docker exec "$SYSLOG_CONTAINER" cat "$log_file"
    fi
}

# Main
main() {
    local command=${1:-"help"}
    
    case $command in
        "help"|"-h"|"--help")
            show_help
            ;;
        "list")
            check_syslog_container
            list_logs
            ;;
        "tail")
            check_syslog_container
            tail_logs "$2"
            ;;
        "search")
            check_syslog_container
            search_logs "$2" "$3"
            ;;
        "clean")
            check_syslog_container
            clean_logs "$2"
            ;;
        "stats")
            check_syslog_container
            show_stats
            ;;
        "status")
            check_status
            ;;
        "test")
            check_syslog_container
            test_logging
            ;;
        "json")
            check_syslog_container
            json_logs "$2"
            ;;
        *)
            echo -e "${RED}Commande inconnue: $command${NC}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Exécuter le script principal
main "$@"