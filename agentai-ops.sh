#!/usr/bin/env bash
# ==============================================================================
#  agentai-ops.sh  —  Agent AI Ops V15  |  Infrastructure as Code
#  Gestión completa del stack: instalar · levantar · bajar · destruir · verificar
# ==============================================================================
set -euo pipefail
IFS=$'\n\t'

# ─────────────────────────────────────────────────────────────────────────────
#  CONFIGURACIÓN GLOBAL
# ─────────────────────────────────────────────────────────────────────────────
readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="$(basename "$0")"
readonly PROJECT_NAME="Agent AI Ops"
readonly PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly LOG_FILE="$PROJECT_DIR/agentai-ops.log"
readonly MONITORING_DIR="$PROJECT_DIR/monitoring"
readonly ENV_FILE="$PROJECT_DIR/.env"
readonly COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
readonly PROMETHEUS_FILE="$MONITORING_DIR/prometheus.yml"
readonly NVIDIA_TOOLKIT_VERSION="1.17.8-1"
readonly LAN_SUBNET="192.168.1.0/24"

# ─────────────────────────────────────────────────────────────────────────────
#  COLORES Y ESTILOS
# ─────────────────────────────────────────────────────────────────────────────
if [[ -t 1 ]]; then
  RED='\033[0;31m';    GREEN='\033[0;32m';    YELLOW='\033[1;33m'
  BLUE='\033[0;34m';   CYAN='\033[0;36m';     MAGENTA='\033[0;35m'
  BOLD='\033[1m';      DIM='\033[2m';          RESET='\033[0m'
  TICK="✅"; CROSS="❌"; ARROW="➜"; WARN="⚠️ "; INFO="ℹ️ "; GEAR="⚙️ "
  ROCKET="🚀"; PACKAGE="📦"; SHIELD="🛡️ "; LOGS="🪵"; FIRE="🔥"
else
  RED=''; GREEN=''; YELLOW=''; BLUE=''; CYAN=''; MAGENTA=''
  BOLD=''; DIM=''; RESET=''
  TICK="[OK]"; CROSS="[ERR]"; ARROW="->"; WARN="[WARN]"; INFO="[INFO]"
  GEAR="[CFG]"; ROCKET="[RUN]"; PACKAGE="[PKG]"; SHIELD="[SEC]"
  LOGS="[LOG]"; FIRE="[!]"
fi

# ─────────────────────────────────────────────────────────────────────────────
#  LOGGING
# ─────────────────────────────────────────────────────────────────────────────
_ensure_log_dir() {
  # Crea el directorio y el archivo de log de forma segura al arranque
  mkdir -p "$PROJECT_DIR" 2>/dev/null || true
  touch "$LOG_FILE" 2>/dev/null || true
}

_log_write() {
  # Escribe al log file solo si existe y es escribible; nunca duplica stdout
  [[ -w "$LOG_FILE" ]] && echo -e "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOG_FILE" 2>/dev/null || true
}

log()    { local msg="[INFO]  $*";                        echo -e "$msg";                        _log_write "$msg"; }
ok()     { local msg="${GREEN}${TICK}  $*${RESET}";       echo -e "$msg";                        _log_write "[OK]    $*"; }
warn()   { local msg="${YELLOW}${WARN} $*${RESET}";       echo -e "$msg";                        _log_write "[WARN]  $*"; }
err()    { local msg="${RED}${CROSS} $*${RESET}";         echo -e "$msg" >&2;                    _log_write "[ERROR] $*"; }
info()   { echo -e "${CYAN}${INFO} $*${RESET}"; }
step()   { echo -e "\n${BOLD}${BLUE}${ARROW} $*${RESET}"; _log_write "[STEP]  $*"; }
title()  { echo -e "\n${BOLD}${MAGENTA}════════════════════════════════════════════${RESET}"; echo -e "${BOLD}${MAGENTA}  $*${RESET}"; echo -e "${BOLD}${MAGENTA}════════════════════════════════════════════${RESET}"; _log_write "[TITLE] $*"; }
divider(){ echo -e "${DIM}────────────────────────────────────────────${RESET}"; }

# ─────────────────────────────────────────────────────────────────────────────
#  UTILIDADES
# ─────────────────────────────────────────────────────────────────────────────
require_root() {
  if [[ $EUID -ne 0 ]]; then
    err "Esta operación requiere privilegios de superusuario."
    echo -e "  ${DIM}Ejecuta: sudo bash $SCRIPT_NAME $*${RESET}"
    exit 1
  fi
}

require_sudo() {
  if ! sudo -n true 2>/dev/null; then
    warn "Se requieren permisos sudo. Por favor ingresa tu contraseña:"
    sudo -v || { err "No se pudo obtener permisos sudo"; exit 1; }
  fi
}

cmd_exists() { command -v "$1" &>/dev/null; }

confirm() {
  local msg="${1:-¿Continuar?}"
  echo -e "${YELLOW}${WARN} ${msg} ${BOLD}[s/N]${RESET} " && read -r -n1 reply
  echo
  [[ "$reply" =~ ^[sS]$ ]]
}

check_project_dir() {
  if [[ ! -d "$PROJECT_DIR" ]]; then
    err "Directorio del proyecto no encontrado: $PROJECT_DIR"
    echo -e "  ${DIM}Ejecuta primero: bash $SCRIPT_NAME instalar${RESET}"
    return 1
  fi
}

check_env_file() {
  if [[ ! -f "$ENV_FILE" ]]; then
    err "Archivo .env no encontrado: $ENV_FILE"
    echo -e "  ${DIM}Ejecuta primero: bash $SCRIPT_NAME instalar${RESET}"
    return 1
  fi
}

check_compose_file() {
  if [[ ! -f "$COMPOSE_FILE" ]]; then
    err "docker-compose.yml no encontrado: $COMPOSE_FILE"
    return 1
  fi
}

run_compose() {
  check_project_dir || return 1
  check_env_file    || return 1
  check_compose_file || return 1
  cd "$PROJECT_DIR" && docker compose "$@"
}

spinner() {
  local pid=$1 msg="${2:-Procesando...}"
  local spin='⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏'
  local i=0
  tput civis 2>/dev/null || true
  while kill -0 "$pid" 2>/dev/null; do
    printf "\r${CYAN}  ${spin:i++%${#spin}:1}  ${msg}${RESET}"
    sleep 0.1
  done
  printf "\r\033[2K"
  tput cnorm 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
#  DETECCIÓN DE ESTADO DEL SISTEMA
# ─────────────────────────────────────────────────────────────────────────────
detect_state() {
  STATE_NVIDIA_TOOLKIT=false
  STATE_DOCKER=false
  STATE_DOCKER_GPU=false
  STATE_PROJECT_DIR=false
  STATE_ENV_FILE=false
  STATE_COMPOSE_FILE=false
  STATE_PROMETHEUS_FILE=false
  STATE_UFW=false
  STATE_LYNIS=false
  STATE_CONTAINERS_UP=false
  STATE_OLLAMA_MODELS=false

  dpkg -l nvidia-container-toolkit &>/dev/null 2>&1 && STATE_NVIDIA_TOOLKIT=true
  cmd_exists docker && systemctl is-active --quiet docker 2>/dev/null && STATE_DOCKER=true
  [[ -d "$PROJECT_DIR" ]] && STATE_PROJECT_DIR=true
  [[ -f "$ENV_FILE" ]] && STATE_ENV_FILE=true
  [[ -f "$COMPOSE_FILE" ]] && STATE_COMPOSE_FILE=true
  [[ -f "$PROMETHEUS_FILE" ]] && STATE_PROMETHEUS_FILE=true
  cmd_exists ufw && STATE_UFW=true
  cmd_exists lynis && STATE_LYNIS=true

  if $STATE_DOCKER && $STATE_COMPOSE_FILE && $STATE_ENV_FILE; then
    local running
    running=$(cd "$PROJECT_DIR" 2>/dev/null && docker compose ps --services --filter "status=running" 2>/dev/null | wc -l || echo 0)
    [[ "$running" -gt 0 ]] && STATE_CONTAINERS_UP=true
  fi

  if $STATE_DOCKER; then
    docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi &>/dev/null 2>&1 \
      && STATE_DOCKER_GPU=true || true
    if docker exec ollama_gpu ollama list &>/dev/null 2>&1; then
      STATE_OLLAMA_MODELS=true
    fi
  fi
}

print_state() {
  detect_state
  title "${PACKAGE} Estado del Sistema — ${PROJECT_NAME}"
  local s_ok="${GREEN}${TICK} Instalado${RESET}"
  local s_no="${RED}${CROSS} No instalado${RESET}"
  local s_run="${GREEN}${ROCKET} Activo${RESET}"
  local s_down="${YELLOW}${WARN} Detenido${RESET}"

  printf "  %-35s %s\n" "NVIDIA Container Toolkit:" "$($STATE_NVIDIA_TOOLKIT && echo -e "$s_ok" || echo -e "$s_no")"
  printf "  %-35s %s\n" "Docker (servicio activo):" "$($STATE_DOCKER && echo -e "$s_run" || echo -e "$s_down")"
  printf "  %-35s %s\n" "Soporte GPU en Docker:" "$($STATE_DOCKER_GPU && echo -e "$s_ok" || echo -e "$s_no")"
  printf "  %-35s %s\n" "UFW (firewall):" "$($STATE_UFW && echo -e "$s_ok" || echo -e "$s_no")"
  printf "  %-35s %s\n" "Lynis (auditoría):" "$($STATE_LYNIS && echo -e "$s_ok" || echo -e "$s_no")"
  divider
  printf "  %-35s %s\n" "Directorio del proyecto:" "$($STATE_PROJECT_DIR && echo -e "$s_ok" || echo -e "$s_no")"
  printf "  %-35s %s\n" "Archivo .env:" "$($STATE_ENV_FILE && echo -e "$s_ok" || echo -e "$s_no")"
  printf "  %-35s %s\n" "docker-compose.yml:" "$($STATE_COMPOSE_FILE && echo -e "$s_ok" || echo -e "$s_no")"
  printf "  %-35s %s\n" "prometheus.yml:" "$($STATE_PROMETHEUS_FILE && echo -e "$s_ok" || echo -e "$s_no")"
  divider
  printf "  %-35s %s\n" "Contenedores corriendo:" "$($STATE_CONTAINERS_UP && echo -e "$s_run" || echo -e "$s_down")"
  printf "  %-35s %s\n" "Modelos Ollama listos:" "$($STATE_OLLAMA_MODELS && echo -e "$s_ok" || echo -e "$s_no")"
  echo
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 1 — NVIDIA CONTAINER TOOLKIT
# ─────────────────────────────────────────────────────────────────────────────
install_nvidia_toolkit() {
  title "${PACKAGE} 1. NVIDIA Container Toolkit"
  require_sudo

  if dpkg -l nvidia-container-toolkit &>/dev/null 2>&1; then
    ok "NVIDIA Container Toolkit ya está instalado. Omitiendo."
    return 0
  fi

  step "1.1 Agregando repositorio NVIDIA..."
  curl -fsSL https://nvidia.github.io/libnvidia-container/gpgkey \
    | sudo gpg --dearmor -o /usr/share/keyrings/nvidia-container-toolkit-keyring.gpg

  curl -s -L https://nvidia.github.io/libnvidia-container/stable/deb/nvidia-container-toolkit.list \
    | sed 's#deb https://#deb [signed-by=/usr/share/keyrings/nvidia-container-toolkit-keyring.gpg] https://#g' \
    | sudo tee /etc/apt/sources.list.d/nvidia-container-toolkit.list > /dev/null

  sudo sed -i -e '/experimental/ s/^#//g' /etc/apt/sources.list.d/nvidia-container-toolkit.list
  sudo apt-get update -qq
  ok "Repositorio configurado."

  step "1.2 Instalando paquetes (versión ${NVIDIA_TOOLKIT_VERSION})..."
  sudo apt-get install -y \
    "nvidia-container-toolkit=${NVIDIA_TOOLKIT_VERSION}" \
    "nvidia-container-toolkit-base=${NVIDIA_TOOLKIT_VERSION}" \
    "libnvidia-container-tools=${NVIDIA_TOOLKIT_VERSION}" \
    "libnvidia-container1=${NVIDIA_TOOLKIT_VERSION}" \
    && ok "NVIDIA Container Toolkit instalado." \
    || { err "Falló la instalación del NVIDIA Container Toolkit"; return 1; }

  step "1.3 Reiniciando Docker..."
  sudo systemctl restart docker \
    && ok "Docker reiniciado." \
    || warn "No se pudo reiniciar Docker automáticamente."

  step "1.4 Verificando integración GPU con Docker..."
  if docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi 2>/dev/null; then
    ok "GPU detectada correctamente en Docker."
  else
    warn "No se pudo verificar la GPU. Asegúrate de que los drivers NVIDIA estén instalados en el host."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 2 — SEGURIDAD: LYNIS + UFW
# ─────────────────────────────────────────────────────────────────────────────
configure_security() {
  title "${SHIELD} 2. Seguridad del Host"
  require_sudo

  # ── Lynis ──────────────────────────────────────────────────────────────────
  step "2.1 Instalando Lynis..."
  if cmd_exists lynis; then
    ok "Lynis ya instalado."
  else
    sudo apt-get install -y lynis -qq && ok "Lynis instalado." || warn "No se pudo instalar Lynis."
  fi

  if cmd_exists lynis; then
    if confirm "¿Ejecutar auditoría Lynis ahora? (puede tardar ~2 min)"; then
      step "Ejecutando auditoría del sistema con Lynis..."
      sudo lynis audit system --quick 2>&1 | tee -a "$LOG_FILE" | tail -20
      ok "Auditoría Lynis completada. Reporte en /var/log/lynis-report.dat"
    else
      info "Auditoría Lynis omitida."
    fi
  fi

  # ── UFW ────────────────────────────────────────────────────────────────────
  step "2.2 Configurando UFW (firewall)..."
  if ! cmd_exists ufw; then
    sudo apt-get install -y ufw -qq && ok "UFW instalado." || { warn "No se pudo instalar UFW"; return; }
  else
    ok "UFW ya instalado."
  fi

  step "2.2.2 Aplicando políticas por defecto..."
  sudo ufw default deny incoming  2>/dev/null
  sudo ufw default allow outgoing 2>/dev/null
  ok "deny incoming / allow outgoing configurado."

  step "2.2.3 HTTP/HTTPS — solo subred LAN ($LAN_SUBNET)..."
  sudo ufw allow from "$LAN_SUBNET" to any port 80  proto tcp comment 'HTTP LAN'  2>/dev/null
  sudo ufw allow from "$LAN_SUBNET" to any port 443 proto tcp comment 'HTTPS LAN' 2>/dev/null

  step "2.2.4 Puertos de servicios — solo LAN..."
  local -A PORTS=(
    [8088]="Open Web UI LAN"
    [3000]="Grafana LAN"
    [6333]="Qdrant HTTP LAN"
    [6334]="Qdrant gRPC LAN"
  )
  for port in "${!PORTS[@]}"; do
    sudo ufw allow from "$LAN_SUBNET" to any port "$port" proto tcp comment "${PORTS[$port]}" 2>/dev/null
    info "Puerto $port permitido → ${PORTS[$port]}"
  done
  sudo ufw reload 2>/dev/null || true

  step "2.2.5 Activando UFW..."
  if sudo ufw status | grep -q "Status: active"; then
    ok "UFW ya estaba activo."
  else
    sudo ufw --force enable 2>/dev/null && ok "UFW activado." || warn "No se pudo activar UFW."
  fi

  sudo ufw status verbose 2>/dev/null | head -30
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 3 — DIRECTORIOS Y VOLÚMENES
# ─────────────────────────────────────────────────────────────────────────────
create_directories() {
  title "${LOGS} 3. Directorios y Volúmenes"

  local -a DIRS=(
    "n8n-data"
    "n8n-data/pdfs"
    "open-webui-data/config"
    "open-webui-data/logs"
    "open-webui-data/app/backend/data"
    "ollama-data"
    "ollama-data/config"
    "qdrant-data"
    "redis-data"
    "redisinsight-data"
    "postgres-data"
    "pgadmin-data"
    "dcgm-exporter-data"
    "monitoring/data"
    "monitoring/rules"
    "grafana-data"
  )

  step "Creando estructura en: $PROJECT_DIR"
  sudo chown -R "$(id -u):$(id -g)" "$PROJECT_DIR" 2>/dev/null || true

  local created=0
  for dir in "${DIRS[@]}"; do
    local full_path="$PROJECT_DIR/$dir"
    if [[ ! -d "$full_path" ]]; then
      mkdir -p "$full_path"
      sudo chown -R "$(id -u):$(id -g)" "$full_path"
      chmod -R 755 "$full_path"
      info "Creado: $dir"
      created=$(( created + 1 ))   # ← seguro con set -e; ((n++)) falla cuando n=0
    fi
  done

  [[ $created -eq 0 ]] && ok "Todos los directorios ya existen." \
                        || ok "$created directorio(s) creado(s)."

  mkdir -p "$PROJECT_DIR/logs" 2>/dev/null || true
  touch "$LOG_FILE" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 4.1 — prometheus.yml
# ─────────────────────────────────────────────────────────────────────────────
write_prometheus_yml() {
  title "${GEAR} 4.1 Generando prometheus.yml"

  if [[ -f "$PROMETHEUS_FILE" ]]; then
    ok "prometheus.yml ya existe."
    if ! confirm "¿Sobrescribir el archivo prometheus.yml existente?"; then
      info "Omitido."; return 0
    fi
  fi

  mkdir -p "$MONITORING_DIR"

  cat > "$PROMETHEUS_FILE" << 'PROM_EOF'
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'agent-ai-stack'
    environment: 'production'
    datacenter: 'slp-mx'

rule_files:

scrape_configs:

  # =============================================
  # INFRAESTRUCTURA BASE
  # =============================================
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
    scrape_interval: 30s
    metrics_path: '/metrics'
    scrape_timeout: 10s

  - job_name: 'node-exporter'
    static_configs:
      - targets: ['node_exporter:9100']
    scrape_interval: 15s
    metrics_path: '/metrics'
    scrape_timeout: 10s

  - job_name: 'cadvisor'
    static_configs:
      - targets: ['cadvisor:8080']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 8s

  # =============================================
  # BASES DE DATOS Y CACHÉ
  # =============================================
  - job_name: 'postgres-exporter'
    static_configs:
      - targets: ['postgres_exporter:9187']
    scrape_interval: 20s
    metrics_path: '/metrics'
    scrape_timeout: 15s

  - job_name: 'redis-exporter'
    static_configs:
      - targets: ['redis_exporter:9121']
    metrics_path: '/metrics'
    scrape_interval: 15s
    scrape_timeout: 10s

  # =============================================
  # SERVICIOS IA Y GPU
  # =============================================
  - job_name: 'nvidia-dcgm'
    static_configs:
      - targets: ['dcgm_exporter:9400']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 8s

  - job_name: 'qdrant'
    static_configs:
      - targets: ['qdrant_gpu:6333']
    metrics_path: '/metrics'
    scrape_interval: 20s
    scrape_timeout: 15s

  # =============================================
  # APLICACIONES CON MÉTRICAS NATIVAS
  # =============================================
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
    metrics_path: '/metrics'
    scrape_interval: 30s
    scrape_timeout: 10s

  # =============================================
  # MÉTRICAS DE RED
  # =============================================
  - job_name: 'network-traffic'
    static_configs:
      - targets: ['node_exporter:9100']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 8s
    params:
      collect[]:
        - 'netdev'
        - 'netstat'
        - 'sockstat'

  - job_name: 'container-network'
    static_configs:
      - targets: ['cadvisor:8080']
    metrics_path: '/metrics'
    scrape_interval: 10s
    scrape_timeout: 8s

alerting:
  alertmanagers:
    - static_configs:
        - targets: []
PROM_EOF

  ok "prometheus.yml generado en: $PROMETHEUS_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 4.2 — docker-compose.yml
# ─────────────────────────────────────────────────────────────────────────────
write_docker_compose() {
  title "${GEAR} 4.2 Generando docker-compose.yml"

  if [[ -f "$COMPOSE_FILE" ]]; then
    ok "docker-compose.yml ya existe."
    if ! confirm "¿Sobrescribir el archivo docker-compose.yml existente?"; then
      info "Omitido."; return 0
    fi
  fi

  cat > "$COMPOSE_FILE" << 'COMPOSE_EOF'
version: '3.8'
services:

  # =========================================
  # N8N - Automation Engine
  # =========================================
  n8n:
    image: n8nio/n8n:${N8N_VERSION}
    container_name: ${N8N_CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "${N8N_HOST_PORT}:${N8N_CONTAINER_PORT}"
    environment:
      GENERIC_TIMEZONE: ${TIMEZONE}
      TZ: ${TIMEZONE}
      N8N_BASIC_AUTH_ACTIVE: ${N8N_BASIC_AUTH_ACTIVE}
      N8N_BASIC_AUTH_USER: ${N8N_BASIC_AUTH_USER}
      N8N_BASIC_AUTH_PASSWORD: ${N8N_BASIC_AUTH_PASSWORD}
      DB_TYPE: postgresdb
      DB_POSTGRESDB_HOST: ${POSTGRES_CONTAINER_NAME}
      DB_POSTGRESDB_PORT: ${POSTGRES_PORT}
      DB_POSTGRESDB_DATABASE: ${POSTGRES_DB}
      DB_POSTGRESDB_USER: ${POSTGRES_USER}
      DB_POSTGRESDB_PASSWORD: ${POSTGRES_PASSWORD}
      DB_POSTGRESDB_SCHEMA: ${POSTGRES_SCHEMA}
      N8N_DATABASE_LOGGING_ENABLED: ${N8N_DATABASE_LOGGING_ENABLED}
      EXECUTIONS_DATA_PRUNE: ${N8N_EXECUTIONS_DATA_PRUNE}
      EXECUTIONS_DATA_MAX_AGE: ${N8N_EXECUTIONS_DATA_MAX_AGE}
      N8N_LOG_LEVEL: ${N8N_LOG_LEVEL}
      N8N_DIAGNOSTICS_ENABLED: ${N8N_DIAGNOSTICS_ENABLED}
      LLAMA_ENDPOINT: http://${OLLAMA_CONTAINER_NAME}:${OLLAMA_PORT}
      LLAMA_MODEL: ${OLLAMA_MODEL}
      OLLAMA_USE_GPU: ${OLLAMA_USE_GPU}
      QDRANT_HOST: http://${QDRANT_CONTAINER_NAME}:${QDRANT_HTTP_PORT}
      REDIS_HOST: ${REDIS_CONTAINER_NAME}
      REDIS_PORT: ${REDIS_PORT}
      REDIS_PASSWORD: ${REDIS_PASSWORD}
    volumes:
      - ./n8n-data:/home/node/.n8n
      - ./n8n-data/pdfs:/pdfs
    depends_on:
      postgres:
        condition: service_healthy
      redis:
        condition: service_healthy
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:${N8N_CONTAINER_PORT}/healthz"]
      interval: 30s
      timeout: 10s
      retries: 5
      start_period: 120s

  # =========================================
  # Open WebUI
  # =========================================
  open-webui:
    image: ghcr.io/open-webui/open-webui:latest
    container_name: ${OPEN_WEBUI_CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "${OPEN_WEBUI_HOST_PORT}:${OPEN_WEBUI_CONTAINER_PORT}"
    extra_hosts:
      - "host.docker.internal:host-gateway"
    environment:
      TZ: ${TIMEZONE}
      LOG_LEVEL: ${OPEN_WEBUI_LOG_LEVEL}
    volumes:
      - ./open-webui-data:/app/backend/data
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${OPEN_WEBUI_CONTAINER_PORT}/healthz"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 20s

  # =========================================
  # Ollama - LLM Server (GPU)
  # =========================================
  ollama:
    image: ollama/ollama:${OLLAMA_VERSION}
    container_name: ${OLLAMA_CONTAINER_NAME}
    restart: unless-stopped
    environment:
      OLLAMA_HOST: 0.0.0.0:${OLLAMA_PORT}
      OLLAMA_GPU_LAYERS: ${OLLAMA_GPU_LAYERS}
      OLLAMA_MAX_LOADED_MODELS: ${OLLAMA_MAX_LOADED_MODELS}
      NVIDIA_VISIBLE_DEVICES: ${NVIDIA_VISIBLE_DEVICES}
      NVIDIA_DRIVER_CAPABILITIES: ${NVIDIA_DRIVER_CAPABILITIES}
    volumes:
      - ./ollama-data:/root/.ollama
      - prometheus-data:/prometheus
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${OLLAMA_PORT}/api/tags"]
      interval: 45s
      timeout: 30s
      retries: 5
      start_period: 180s

  # =========================================
  # Qdrant - Vector DB (GPU)
  # =========================================
  qdrant:
    image: qdrant/qdrant:${QDRANT_VERSION}
    container_name: ${QDRANT_CONTAINER_NAME}
    restart: unless-stopped
    environment:
      QDRANT__GPU__INDEXING: ${QDRANT_GPU_INDEXING}
      QDRANT__SERVICE__HTTP_PORT: ${QDRANT_HTTP_PORT}
      QDRANT__SERVICE__GRPC_PORT: ${QDRANT_GRPC_PORT}
    ports:
      - "${QDRANT_HOST_HTTP_PORT}:${QDRANT_HTTP_PORT}"
      - "${QDRANT_HOST_GRPC_PORT}:${QDRANT_GRPC_PORT}"
    volumes:
      - ./qdrant-data:/qdrant/storage
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:${QDRANT_HTTP_PORT}/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # =========================================
  # Redis - Cache
  # =========================================
  redis:
    image: redis:${REDIS_VERSION}
    container_name: ${REDIS_CONTAINER_NAME}
    restart: unless-stopped
    volumes:
      - ./redis-data:/data
    command: ["redis-server", "--appendonly", "yes", "--requirepass", "${REDIS_PASSWORD}", "--bind", "0.0.0.0"]
    networks:
      - agent-ai-network-internal
    healthcheck:
      test: ["CMD", "redis-cli", "-a", "${REDIS_PASSWORD}", "ping"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # =========================================
  # RedisInsight - GUI
  # =========================================
  redisinsight:
    image: redislabs/redisinsight:${REDIS_INSIGHT_VERSION}
    container_name: ${REDIS_INSIGHT_CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "${REDIS_INSIGHT_HOST_PORT}:${REDIS_INSIGHT_CONTAINER_PORT}"
    volumes:
      - ./redisinsight-data:/data
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external

  # =========================================
  # Redis Exporter
  # =========================================
  redis-exporter:
    image: oliver006/redis_exporter:${REDIS_EXPORTER_VERSION}
    container_name: ${REDIS_EXPORTER_CONTAINER_NAME}
    restart: unless-stopped
    environment:
      REDIS_ADDR: redis://:${REDIS_PASSWORD}@${REDIS_CONTAINER_NAME}:${REDIS_PORT}
      REDIS_EXPORTER_LOG_FORMAT: txt
    depends_on:
      redis:
        condition: service_healthy
    networks:
      - agent-ai-network-internal

  # =========================================
  # PostgreSQL
  # =========================================
  postgres:
    image: postgres:${POSTGRES_VERSION}
    container_name: ${POSTGRES_CONTAINER_NAME}
    restart: unless-stopped
    environment:
      POSTGRES_USER: ${POSTGRES_USER}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD}
      POSTGRES_DB: ${POSTGRES_DB}
      POSTGRES_MULTIPLE_DATABASES: ${POSTGRES_ADDITIONAL_DBS}
    volumes:
      - ./postgres-data:/var/lib/postgresql/data
    networks:
      - agent-ai-network-internal
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER}"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 30s

  # =========================================
  # pgAdmin
  # =========================================
  pgadmin:
    image: dpage/pgadmin4:${PGADMIN_VERSION}
    container_name: ${PGADMIN_CONTAINER_NAME}
    restart: unless-stopped
    environment:
      PGADMIN_DEFAULT_EMAIL: ${PGADMIN_DEFAULT_EMAIL}
      PGADMIN_DEFAULT_PASSWORD: ${PGADMIN_DEFAULT_PASSWORD}
      PGADMIN_LISTEN_PORT: ${PGADMIN_LISTEN_PORT}
    ports:
      - "${PGADMIN_HOST_PORT}:${PGADMIN_LISTEN_PORT}"
    volumes:
      - ./pgadmin-data:/var/lib/pgadmin
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external

  # =========================================
  # Postgres Exporter
  # =========================================
  postgres-exporter:
    image: prometheuscommunity/postgres-exporter:${POSTGRES_EXPORTER_VERSION}
    container_name: ${POSTGRES_EXPORTER_CONTAINER_NAME}
    restart: unless-stopped
    environment:
      DATA_SOURCE_NAME: postgresql://${POSTGRES_USER}:${POSTGRES_PASSWORD}@${POSTGRES_CONTAINER_NAME}:${POSTGRES_PORT}/${POSTGRES_DB}?sslmode=disable
    depends_on:
      postgres:
        condition: service_healthy
    networks:
      - agent-ai-network-internal
    healthcheck:
      test: ["CMD", "wget", "--no-verbose", "--tries=1", "--spider", "http://localhost:${POSTGRES_EXPORTER_PORT}/metrics"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 60s

  # =========================================
  # Node Exporter
  # =========================================
  node-exporter:
    image: prom/node-exporter:${NODE_EXPORTER_VERSION}
    container_name: ${NODE_EXPORTER_CONTAINER_NAME}
    restart: unless-stopped
    command:
      - '--path.rootfs=/host'
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    networks:
      - agent-ai-network-internal

  # =========================================
  # cAdvisor
  # =========================================
  cadvisor:
    image: gcr.io/cadvisor/cadvisor:${CADVISOR_VERSION}
    container_name: ${CADVISOR_CONTAINER_NAME}
    restart: unless-stopped
    ports:
      - "${CADVISOR_HOST_PORT}:${CADVISOR_CONTAINER_PORT}"
    volumes:
      - /:/rootfs:ro
      - /var/run:/var/run:ro
      - /sys:/sys:ro
      - /var/lib/docker/:/var/lib/docker:ro
      - /dev/disk/:/dev/disk:ro
    privileged: true
    devices:
      - /dev/kmsg:/dev/kmsg
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external

  # =========================================
  # DCGM Exporter - GPU Metrics
  # =========================================
  dcgm-exporter:
    image: nvidia/dcgm-exporter:${DCGM_EXPORTER_VERSION}
    container_name: ${DCGM_EXPORTER_CONTAINER_NAME}
    restart: unless-stopped
    environment:
      DCGM_EXPORTER_LISTEN: :${DCGM_EXPORTER_PORT}
      DCGM_EXPORTER_KUBERNETES: ${DCGM_EXPORTER_KUBERNETES}
      DCGM_EXPORTER_COLLECTORS: ${DCGM_EXPORTER_COLLECTORS}
    volumes:
      - ./dcgm-exporter-data:/tmp/dcgm-exporter
    deploy:
      resources:
        reservations:
          devices:
            - driver: nvidia
              count: all
              capabilities: [gpu]
    cap_add:
      - SYS_ADMIN
    security_opt:
      - seccomp:unconfined
    networks:
      - agent-ai-network-internal

  # =========================================
  # Prometheus
  # =========================================
  prometheus:
    image: prom/prometheus:${PROMETHEUS_VERSION}
    container_name: ${PROMETHEUS_CONTAINER_NAME}
    restart: unless-stopped
    volumes:
      - ./monitoring/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - prometheus-data:/prometheus
    ports:
      - "${PROMETHEUS_HOST_PORT}:${PROMETHEUS_CONTAINER_PORT}"
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=${PROMETHEUS_RETENTION}'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    depends_on:
      cadvisor:
        condition: service_started
      node-exporter:
        condition: service_started
      redis-exporter:
        condition: service_started
      postgres-exporter:
        condition: service_healthy
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external

  # =========================================
  # Grafana
  # =========================================
  grafana:
    image: grafana/grafana:${GRAFANA_VERSION}
    container_name: ${GRAFANA_CONTAINER_NAME}
    restart: unless-stopped
    environment:
      GF_SECURITY_ADMIN_PASSWORD: ${GRAFANA_ADMIN_PASSWORD}
      GF_SERVER_HTTP_PORT: ${GRAFANA_CONTAINER_PORT}
    ports:
      - "${GRAFANA_HOST_PORT}:${GRAFANA_CONTAINER_PORT}"
    volumes:
      - grafana-data:/var/lib/grafana
    depends_on:
      prometheus:
        condition: service_started
    networks:
      - agent-ai-network-internal
      - agent-ai-network-external

# =========================================
# Networks
# =========================================
networks:
  agent-ai-network-internal:
    driver: bridge
    internal: true
  agent-ai-network-external:
    driver: bridge

# =========================================
# Volumes
# =========================================
volumes:
  grafana-data:
    driver: local
  prometheus-data:
    driver: local
COMPOSE_EOF

  ok "docker-compose.yml generado en: $COMPOSE_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 4.3 — .env
# ─────────────────────────────────────────────────────────────────────────────
write_env_file() {
  title "${GEAR} 4.3 Generando archivo .env"

  if [[ -f "$ENV_FILE" ]]; then
    ok ".env ya existe."
    if ! confirm "¿Sobrescribir el archivo .env existente?"; then
      info "Omitido."; return 0
    fi
  fi

  cat > "$ENV_FILE" << 'ENV_EOF'
# ===============================================
# CONFIGURACIÓN GENERAL
# ===============================================
TIMEZONE=America/Mexico_City
OPEN_WEBUI_LOG_LEVEL=WARNING

# ===============================================
# N8N
# ===============================================
N8N_VERSION=latest
N8N_CONTAINER_NAME=n8n
N8N_HOST_PORT=5678
N8N_CONTAINER_PORT=5678
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=Admin
N8N_BASIC_AUTH_PASSWORD=YourSecureN8NPassword123!
N8N_DATABASE_LOGGING_ENABLED=false
N8N_EXECUTIONS_DATA_PRUNE=true
N8N_EXECUTIONS_DATA_MAX_AGE=336
N8N_LOG_LEVEL=info
N8N_DIAGNOSTICS_ENABLED=false

# ===============================================
# OPEN WEBUI
# ===============================================
OPEN_WEBUI_VERSION=latest
OPEN_WEBUI_CONTAINER_NAME=open-webui
OPEN_WEBUI_HOST_PORT=8088
OPEN_WEBUI_CONTAINER_PORT=8080

# ===============================================
# OLLAMA
# ===============================================
OLLAMA_VERSION=0.10.1
OLLAMA_CONTAINER_NAME=ollama_gpu
OLLAMA_PORT=11434
OLLAMA_MODEL=llama3.1:8b
OLLAMA_USE_GPU=true
OLLAMA_GPU_LAYERS=35
OLLAMA_MAX_LOADED_MODELS=2
NVIDIA_VISIBLE_DEVICES=0,1
NVIDIA_DRIVER_CAPABILITIES=compute,utility

# ===============================================
# QDRANT
# ===============================================
QDRANT_VERSION=v1.15-gpu-nvidia
QDRANT_CONTAINER_NAME=qdrant_gpu
QDRANT_HTTP_PORT=6333
QDRANT_GRPC_PORT=6334
QDRANT_HOST_HTTP_PORT=6333
QDRANT_HOST_GRPC_PORT=6334
QDRANT_GPU_INDEXING=1

# ===============================================
# REDIS
# ===============================================
REDIS_VERSION=7-alpine
REDIS_CONTAINER_NAME=redis_cache
REDIS_PORT=6379
REDIS_PASSWORD=YourSecureRedisPassword123!

# ===============================================
# REDIS INSIGHT
# ===============================================
REDIS_INSIGHT_VERSION=2.70
REDIS_INSIGHT_CONTAINER_NAME=redisinsight
REDIS_INSIGHT_HOST_PORT=5540
REDIS_INSIGHT_CONTAINER_PORT=5540

# ===============================================
# REDIS EXPORTER
# ===============================================
REDIS_EXPORTER_VERSION=v1.74.0
REDIS_EXPORTER_CONTAINER_NAME=redis_exporter

# ===============================================
# POSTGRESQL
# ===============================================
POSTGRES_VERSION=15
POSTGRES_CONTAINER_NAME=n8n_postgres
POSTGRES_USER=n8n
POSTGRES_PASSWORD=YourSecurePostgresPassword123!
POSTGRES_DB=n8n
POSTGRES_SCHEMA=public
POSTGRES_PORT=5432
POSTGRES_ADDITIONAL_DBS=grafana

# ===============================================
# PGADMIN
# ===============================================
PGADMIN_VERSION=9.6.0
PGADMIN_CONTAINER_NAME=pgadmin4
PGADMIN_DEFAULT_EMAIL=admin@admin.com
PGADMIN_DEFAULT_PASSWORD=YourSecurePgAdminPassword123!
PGADMIN_LISTEN_PORT=80
PGADMIN_HOST_PORT=5050

# ===============================================
# POSTGRES EXPORTER
# ===============================================
POSTGRES_EXPORTER_VERSION=v0.17.1
POSTGRES_EXPORTER_CONTAINER_NAME=postgres_exporter
POSTGRES_EXPORTER_PORT=9187

# ===============================================
# NODE EXPORTER
# ===============================================
NODE_EXPORTER_VERSION=v1.9.1
NODE_EXPORTER_CONTAINER_NAME=node_exporter

# ===============================================
# CADVISOR
# ===============================================
CADVISOR_VERSION=latest
CADVISOR_CONTAINER_NAME=cadvisor
CADVISOR_HOST_PORT=8080
CADVISOR_CONTAINER_PORT=8080

# ===============================================
# DCGM EXPORTER
# ===============================================
DCGM_EXPORTER_VERSION=4.2.3-4.1.3-ubuntu22.04
DCGM_EXPORTER_CONTAINER_NAME=dcgm_exporter
DCGM_EXPORTER_PORT=9400
DCGM_EXPORTER_KUBERNETES=false
DCGM_EXPORTER_COLLECTORS=/etc/dcgm-exporter/dcp-metrics-included.csv

# ===============================================
# PROMETHEUS
# ===============================================
PROMETHEUS_VERSION=v3.5.0
PROMETHEUS_CONTAINER_NAME=prometheus
PROMETHEUS_HOST_PORT=9090
PROMETHEUS_CONTAINER_PORT=9090
PROMETHEUS_RETENTION=30d

# ===============================================
# GRAFANA
# ===============================================
GRAFANA_VERSION=latest
GRAFANA_CONTAINER_NAME=grafana
GRAFANA_ADMIN_PASSWORD=YourSecureGrafanaPassword123!
GRAFANA_HOST_PORT=3000
GRAFANA_CONTAINER_PORT=3000
ENV_EOF

  sudo chmod 600 "$ENV_FILE"
  ok ".env generado y asegurado (chmod 600): $ENV_FILE"
  warn "Recuerda cambiar las contraseñas por defecto en $ENV_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 5 — LEVANTAR SERVICIOS
# ─────────────────────────────────────────────────────────────────────────────
cmd_up() {
  title "${ROCKET} 5. Levantando Servicios"
  check_project_dir || return 1
  check_env_file    || return 1
  check_compose_file || return 1

  fix_pgadmin_permissions

  step "Ejecutando docker compose up -d ..."
  run_compose up -d && ok "Todos los servicios iniciados." \
    || { err "Falló docker compose up"; return 1; }

  echo
  info "Esperando que los servicios estén listos (30s)..."
  sleep 30
  cmd_ps
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 6 — REINICIO DE DOCKER
# ─────────────────────────────────────────────────────────────────────────────
restart_docker() {
  title "${GEAR} 6. Reinicio del Servicio Docker"
  require_sudo
  step "Reiniciando Docker..."
  sudo systemctl restart docker \
    && ok "Docker reiniciado correctamente." \
    || { err "No se pudo reiniciar Docker"; return 1; }
  sleep 3
  sudo systemctl status docker --no-pager | head -8
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 7 — DESCARGA DE LLMs
# ─────────────────────────────────────────────────────────────────────────────
pull_llms() {
  title "${PACKAGE} 7. Descarga de Modelos LLM"

  if ! docker ps --format '{{.Names}}' | grep -q "ollama_gpu"; then
    err "El contenedor ollama_gpu no está corriendo."
    echo -e "  ${DIM}Ejecuta primero: bash $SCRIPT_NAME levantar${RESET}"
    return 1
  fi

  step "7.1 Descargando snowflake-arctic-embed2 (embedding)..."
  if docker exec ollama_gpu ollama list 2>/dev/null | grep -q "snowflake-arctic-embed2"; then
    ok "snowflake-arctic-embed2 ya está descargado."
  else
    docker exec -it ollama_gpu ollama pull snowflake-arctic-embed2:latest \
      && ok "snowflake-arctic-embed2 descargado." \
      || warn "Falló la descarga de snowflake-arctic-embed2."
  fi

  step "7.2 Descargando llama3.1:8b (chat)..."
  if docker exec ollama_gpu ollama list 2>/dev/null | grep -q "llama3.1:8b"; then
    ok "llama3.1:8b ya está descargado."
  else
    docker exec -it ollama_gpu ollama pull llama3.1:8b \
      && ok "llama3.1:8b descargado." \
      || warn "Falló la descarga de llama3.1:8b."
  fi

  step "Modelos instalados:"
  docker exec ollama_gpu ollama list 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 8 — VERIFICACIONES
# ─────────────────────────────────────────────────────────────────────────────
run_verifications() {
  title "${TICK} 8. Verificaciones del Sistema"
  local all_ok=true

  step "8.1 LLMs cargados en Ollama..."
  if docker exec ollama_gpu ollama list 2>/dev/null; then
    ok "Ollama responde correctamente."
  else
    warn "No se pudo contactar ollama_gpu."
    all_ok=false
  fi

  step "8.2 Estado de todos los contenedores..."
  docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | head -30

  step "8.3 Verificación GPU en Docker..."
  if docker run --rm --gpus all nvidia/cuda:12.2.0-base-ubuntu22.04 nvidia-smi 2>/dev/null; then
    ok "GPU accesible desde Docker."
  else
    warn "GPU no disponible desde Docker o drivers no instalados."
    all_ok=false
  fi

  divider
  $all_ok && ok "Todas las verificaciones pasaron." \
           || warn "Algunas verificaciones fallaron. Revisa el log: $LOG_FILE"
}

# ─────────────────────────────────────────────────────────────────────────────
#  PASO 9 — PERMISOS PGADMIN
# ─────────────────────────────────────────────────────────────────────────────
fix_pgadmin_permissions() {
  title "${GEAR} 9. Permisos pgAdmin"
  local pgadmin_dir="$PROJECT_DIR/pgadmin-data"
  if [[ -d "$pgadmin_dir" ]]; then
    sudo chown -R 5050:5050 "$pgadmin_dir"
    sudo chmod -R 700 "$pgadmin_dir"
    ok "Permisos pgAdmin aplicados: $pgadmin_dir"
  else
    warn "Directorio pgadmin-data no encontrado. Se creará en el siguiente paso."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  ESTADO Y LOGS
# ─────────────────────────────────────────────────────────────────────────────
cmd_ps() {
  title "${INFO} Estado de Contenedores"
  check_project_dir || return 1
  cd "$PROJECT_DIR"
  docker compose ps 2>/dev/null || docker ps -a --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
}

cmd_logs() {
  title "${LOGS} Logs de Servicios"
  check_project_dir || return 1
  local service="${2:-}"

  if [[ -n "$service" ]]; then
    run_compose logs -f --tail=100 "$service"
  else
    echo -e "${DIM}Servicios disponibles: n8n, open-webui, ollama, qdrant, redis, postgres, grafana, prometheus${RESET}"
    echo -e "${DIM}Uso: bash $SCRIPT_NAME logs <servicio>${RESET}\n"
    run_compose logs -f --tail=50
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  BAJAR SERVICIOS
# ─────────────────────────────────────────────────────────────────────────────
cmd_down() {
  title "${WARN} Bajando Servicios"
  check_project_dir  || return 1
  check_compose_file || return 1
  run_compose down && ok "Todos los servicios detenidos." \
    || { err "Error al detener servicios"; return 1; }
}

# ─────────────────────────────────────────────────────────────────────────────
#  REINICIAR SERVICIOS
# ─────────────────────────────────────────────────────────────────────────────
cmd_restart() {
  local service="${2:-}"
  if [[ -n "$service" ]]; then
    title "${GEAR} Reiniciando servicio: $service"
    run_compose restart "$service" \
      && ok "$service reiniciado." \
      || err "No se pudo reiniciar $service."
  else
    title "${GEAR} Reiniciando todos los servicios"
    cmd_down
    sleep 3
    cmd_up
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  DESTRUIR — Eliminar contenedores, redes y volúmenes Docker
# ─────────────────────────────────────────────────────────────────────────────
cmd_destroy() {
  title "${FIRE} Destruir Stack (contenedores + volúmenes Docker)"
  warn "Esto eliminará TODOS los contenedores y volúmenes Docker del proyecto."
  warn "Los datos en carpetas locales (postgres-data, n8n-data, etc.) NO serán borrados."
  confirm "¿Confirmas que quieres destruir el stack?" || { info "Cancelado."; return 0; }

  check_project_dir  || return 1
  check_compose_file || return 1

  step "Bajando servicios y eliminando volúmenes Docker..."
  run_compose down -v --remove-orphans \
    && ok "Stack destruido." \
    || err "Ocurrió un error al destruir el stack."
}

# ─────────────────────────────────────────────────────────────────────────────
#  PURGE — Eliminar TODO incluyendo datos locales
# ─────────────────────────────────────────────────────────────────────────────
cmd_purge() {
  title "${FIRE} PURGE TOTAL — Eliminación completa del proyecto"
  err "¡ADVERTENCIA CRÍTICA! Esta acción es IRREVERSIBLE."
  warn "Se eliminarán: contenedores, volúmenes Docker Y todos los datos locales."
  warn "Ruta afectada: $PROJECT_DIR"
  echo

  confirm "¿Estás absolutamente seguro? (escribe 's' para confirmar)" || { info "Cancelado."; return 0; }
  confirm "¿Segunda confirmación — esto borrará TODO incluyendo bases de datos?" || { info "Cancelado."; return 0; }

  if $STATE_COMPOSE_FILE 2>/dev/null || [[ -f "$COMPOSE_FILE" ]]; then
    step "Bajando servicios..."
    cd "$PROJECT_DIR" && docker compose down -v --remove-orphans 2>/dev/null || true
  fi

  step "Eliminando directorio del proyecto..."
  sudo rm -rf "$PROJECT_DIR" \
    && ok "Directorio eliminado: $PROJECT_DIR" \
    || err "No se pudo eliminar completamente $PROJECT_DIR"

  ok "Purge completado."
}

# ─────────────────────────────────────────────────────────────────────────────
#  INSTALACIÓN COMPLETA (orquesta todos los pasos)
# ─────────────────────────────────────────────────────────────────────────────
cmd_install() {
  title "${ROCKET} Instalación Completa — ${PROJECT_NAME}"
  detect_state

  echo -e "\n${BOLD}Estado actual detectado:${RESET}"
  print_state

  if $STATE_CONTAINERS_UP; then
    warn "Los servicios ya están corriendo."
    confirm "¿Continuar de todas formas?" || { info "Cancelado."; return 0; }
  fi

  require_sudo
  log "Iniciando instalación completa de $PROJECT_NAME"

  # Paso 1: NVIDIA Toolkit
  if ! $STATE_NVIDIA_TOOLKIT; then
    install_nvidia_toolkit || warn "NVIDIA toolkit falló — continuando sin GPU completa."
  else
    ok "PASO 1: NVIDIA Toolkit ya instalado. Omitiendo."
  fi

  # Paso 2: Seguridad
  configure_security

  # Paso 3: Directorios
  create_directories

  # Paso 4: Archivos de configuración
  write_prometheus_yml
  write_docker_compose
  write_env_file

  # Paso 6: Reinicio Docker para aplicar cambios
  restart_docker

  # Paso 9: Permisos pgAdmin (antes de levantar)
  fix_pgadmin_permissions

  # Paso 5: Levantar servicios
  cmd_up

  echo
  info "Esperando que Ollama esté completamente listo (60s)..."
  sleep 60

  # Paso 7: Descargar LLMs
  if confirm "¿Descargar los modelos LLM ahora? (puede tardar varios minutos)"; then
    pull_llms
  else
    info "Descarga de LLMs omitida. Ejecuta después: bash $SCRIPT_NAME llms"
  fi

  # Paso 8: Verificaciones
  run_verifications

  title "${TICK} Instalación Completada"
  print_endpoints
  log "Instalación completada exitosamente."
}

# ─────────────────────────────────────────────────────────────────────────────
#  MOSTRAR ENDPOINTS
# ─────────────────────────────────────────────────────────────────────────────
print_endpoints() {
  echo -e "\n${BOLD}${GREEN}════════ Endpoints de Acceso ════════${RESET}"
  local ip
  ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "localhost")
  local -A ENDPOINTS=(
    ["N8N (Automatización)"]="http://$ip:5678"
    ["Open WebUI (Chat IA)"]="http://$ip:8088"
    ["Grafana (Dashboards)"]="http://$ip:3000"
    ["Prometheus (Métricas)"]="http://$ip:9090"
    ["pgAdmin (PostgreSQL)"]="http://$ip:5050"
    ["RedisInsight (Redis)"]="http://$ip:5540"
    ["Qdrant (Vector DB)"]="http://$ip:6333"
    ["cAdvisor (Containers)"]="http://$ip:8080"
  )
  for name in "N8N (Automatización)" "Open WebUI (Chat IA)" "Grafana (Dashboards)" \
              "Prometheus (Métricas)" "pgAdmin (PostgreSQL)" "RedisInsight (Redis)" \
              "Qdrant (Vector DB)" "cAdvisor (Containers)"; do
    printf "  ${CYAN}%-28s${RESET} %s\n" "$name" "${ENDPOINTS[$name]}"
  done
  echo
}

# ─────────────────────────────────────────────────────────────────────────────
#  ACTUALIZAR IMÁGENES
# ─────────────────────────────────────────────────────────────────────────────
cmd_update() {
  title "${PACKAGE} Actualización de Imágenes"
  check_project_dir  || return 1
  check_compose_file || return 1
  confirm "¿Actualizar todas las imágenes Docker? (los servicios se reiniciarán)" || return 0

  step "Bajando servicios..."
  run_compose down

  step "Descargando imágenes actualizadas..."
  run_compose pull

  step "Levantando con nuevas imágenes..."
  run_compose up -d
  ok "Actualización completada."
}

# ─────────────────────────────────────────────────────────────────────────────
#  BACKUP DE DATOS
# ─────────────────────────────────────────────────────────────────────────────
cmd_backup() {
  title "${PACKAGE} Backup de Datos"
  check_project_dir || return 1

  local backup_dir="$HOME/agentai-backups"
  local ts; ts=$(date '+%Y%m%d_%H%M%S')
  local backup_file="$backup_dir/agentai-backup-$ts.tar.gz"
  mkdir -p "$backup_dir"

  step "Creando backup en: $backup_file"
  local -a backup_dirs=()
  for d in n8n-data qdrant-data redis-data postgres-data monitoring .env docker-compose.yml; do
    [[ -e "$PROJECT_DIR/$d" ]] && backup_dirs+=("$d")
  done

  cd "$PROJECT_DIR"
  tar -czf "$backup_file" "${backup_dirs[@]}" 2>/dev/null \
    && ok "Backup creado: $backup_file ($(du -sh "$backup_file" | cut -f1))" \
    || { err "Error al crear backup"; return 1; }
}

# ─────────────────────────────────────────────────────────────────────────────
#  MENÚ INTERACTIVO
# ─────────────────────────────────────────────────────────────────────────────
show_menu() {
  clear
  echo -e "${BOLD}${MAGENTA}"
  cat << 'BANNER'
   ___                    _        _    ___   ___
  / _ \  __ _  ___  _ __ | |_     / \  |_ _| / _ \ _ __  ___
 / /_\ \/ _` |/ _ \| '_ \| __|   / _ \  | | | | | | '_ \/ __|
/ /   \ \ (_| |  __/ | | | |_   / ___ \ | | | |_| | |_) \__ \
\/     \/\__, |\___|_| |_|\__| /_/   \_\___| \___/| .__/|___/
          |___/  AI-Gen · IaC · DevOps              |_|
BANNER
  echo -e "${RESET}"
  echo -e "${DIM}  Versión $SCRIPT_VERSION  |  Proyecto: $PROJECT_DIR${RESET}\n"

  detect_state
  local status_line=""
  $STATE_CONTAINERS_UP \
    && status_line="${GREEN}${ROCKET} Servicios activos${RESET}" \
    || status_line="${YELLOW}${WARN} Servicios detenidos${RESET}"
  echo -e "  Estado: $status_line\n"

  echo -e "${BOLD}  ┌─── Operaciones Principales ───────────────┐${RESET}"
  echo -e "  │  ${CYAN}1)${RESET} ${BOLD}instalar${RESET}   — Instalación completa        │"
  echo -e "  │  ${CYAN}2)${RESET} ${BOLD}levantar${RESET}   — Iniciar todos los servicios │"
  echo -e "  │  ${CYAN}3)${RESET} ${BOLD}bajar${RESET}      — Detener todos los servicios │"
  echo -e "  │  ${CYAN}4)${RESET} ${BOLD}reiniciar${RESET}  — Reiniciar servicios          │"
  echo -e "  ${BOLD}  ├─── Gestión ────────────────────────────────┤${RESET}"
  echo -e "  │  ${CYAN}5)${RESET} ${BOLD}estado${RESET}     — Ver estado del sistema       │"
  echo -e "  │  ${CYAN}6)${RESET} ${BOLD}logs${RESET}       — Ver logs de servicios        │"
  echo -e "  │  ${CYAN}7)${RESET} ${BOLD}llms${RESET}       — Descargar modelos LLM        │"
  echo -e "  │  ${CYAN}8)${RESET} ${BOLD}verificar${RESET}  — Verificaciones del sistema   │"
  echo -e "  │  ${CYAN}9)${RESET} ${BOLD}endpoints${RESET}  — Mostrar URLs de acceso       │"
  echo -e "  ${BOLD}  ├─── Avanzado ───────────────────────────────┤${RESET}"
  echo -e "  │  ${CYAN}a)${RESET} ${BOLD}actualizar${RESET} — Actualizar imágenes Docker   │"
  echo -e "  │  ${CYAN}b)${RESET} ${BOLD}backup${RESET}     — Backup de datos              │"
  echo -e "  │  ${CYAN}s)${RESET} ${BOLD}seguridad${RESET}  — Auditoría + Firewall         │"
  echo -e "  │  ${CYAN}p)${RESET} ${BOLD}pgadmin${RESET}    — Reparar permisos pgAdmin     │"
  echo -e "  ${BOLD}  ├─── Peligroso ──────────────────────────────┤${RESET}"
  echo -e "  │  ${RED}d)${RESET} ${BOLD}destruir${RESET}   — Eliminar contenedores+vols   │"
  echo -e "  │  ${RED}x)${RESET} ${BOLD}purge${RESET}      — ${RED}ELIMINAR TODO (irreversible)${RESET}  │"
  echo -e "  ${BOLD}  └─────────────────────────────────────────────┘${RESET}"
  echo -e "\n  ${DIM}q) Salir${RESET}\n"
  printf "  ${BOLD}Selecciona una opción: ${RESET}"
}

interactive_menu() {
  while true; do
    show_menu
    read -r -n1 choice
    echo
    case "$choice" in
      1) cmd_install ;;
      2) cmd_up ;;
      3) cmd_down ;;
      4) cmd_restart ;;
      5) print_state ;;
      6) cmd_logs ;;
      7) pull_llms ;;
      8) run_verifications ;;
      9) print_endpoints ;;
      a|A) cmd_update ;;
      b|B) cmd_backup ;;
      s|S) configure_security ;;
      p|P) fix_pgadmin_permissions ;;
      d|D) cmd_destroy ;;
      x|X) cmd_purge ;;
      q|Q) echo -e "\n${DIM}Hasta luego.${RESET}\n"; exit 0 ;;
      *) warn "Opción inválida: '$choice'" ;;
    esac
    echo -e "\n${DIM}Presiona cualquier tecla para continuar...${RESET}"
    read -r -n1
  done
}

# ─────────────────────────────────────────────────────────────────────────────
#  PUNTO DE ENTRADA
# ─────────────────────────────────────────────────────────────────────────────
usage() {
  echo -e "${BOLD}Uso:${RESET} bash $SCRIPT_NAME [comando] [opciones]\n"
  echo -e "${BOLD}Comandos:${RESET}"
  printf "  %-18s %s\n" "instalar"   "Instalación completa del stack"
  printf "  %-18s %s\n" "levantar"   "Levantar todos los servicios"
  printf "  %-18s %s\n" "bajar"      "Detener todos los servicios"
  printf "  %-18s %s\n" "reiniciar"  "Reiniciar servicios (o un servicio específico)"
  printf "  %-18s %s\n" "estado"     "Estado del sistema"
  printf "  %-18s %s\n" "logs"       "Ver logs (opcionalmente: logs <servicio>)"
  printf "  %-18s %s\n" "llms"       "Descargar modelos LLM en Ollama"
  printf "  %-18s %s\n" "verificar"  "Verificaciones del sistema"
  printf "  %-18s %s\n" "endpoints"  "Mostrar URLs de acceso"
  printf "  %-18s %s\n" "actualizar" "Actualizar imágenes Docker"
  printf "  %-18s %s\n" "backup"     "Backup de datos locales"
  printf "  %-18s %s\n" "seguridad"  "Auditoría Lynis + configurar UFW"
  printf "  %-18s %s\n" "pgadmin"    "Reparar permisos de pgAdmin"
  printf "  %-18s %s\n" "destruir"   "Eliminar contenedores y volúmenes Docker"
  printf "  %-18s %s\n" "purge"      "Eliminar TODO (IRREVERSIBLE)"
  echo -e "\n${DIM}Sin argumentos: abre el menú interactivo${RESET}\n"
}

main() {
  _ensure_log_dir
  detect_state

  case "${1:-menu}" in
    menu|"")          interactive_menu ;;
    instalar|install) cmd_install ;;
    levantar|up)      cmd_up ;;
    bajar|down)       cmd_down ;;
    reiniciar|restart)cmd_restart "$@" ;;
    estado|status)    print_state ;;
    logs)             cmd_logs "$@" ;;
    llms)             pull_llms ;;
    verificar|verify) run_verifications ;;
    endpoints)        print_endpoints ;;
    actualizar|update)cmd_update ;;
    backup)           cmd_backup ;;
    seguridad|sec)    configure_security ;;
    pgadmin)          fix_pgadmin_permissions ;;
    destruir|destroy) cmd_destroy ;;
    purge)            cmd_purge ;;
    ayuda|help|-h)    usage ;;
    *)
      err "Comando desconocido: '${1}'"
      usage
      exit 1
      ;;
  esac
}

main "$@"