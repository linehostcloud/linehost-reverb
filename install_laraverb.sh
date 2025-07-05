#!/bin/bash

# Cores para a saída do terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Função para exibir mensagens de status
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}
log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}
log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}
log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Função para verificar se um comando existe
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Função para verificar Docker Compose
check_docker_compose() {
    # Verifica se docker compose (plugin) está disponível
    if docker compose version >/dev/null 2>&1; then
        return 0
    fi
    
    # Verifica se docker-compose (standalone) está disponível
    if command_exists docker-compose; then
        return 0
    fi
    
    return 1
}

# Função para instalar Docker
install_docker() {
    log_info "Verificando e instalando Docker e Docker Compose..."
    if ! command_exists docker; then
        log_info "Docker não encontrado. Instalando Docker Engine..."
        sudo apt update
        sudo apt install -y ca-certificates curl gnupg
        sudo install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
        sudo chmod a+r /etc/apt/keyrings/docker.gpg
        echo "deb [arch=\"$(dpkg --print-architecture)\" signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \"$(. /etc/os-release && echo "$VERSION_CODENAME")\" stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        sudo apt update
        sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        if ! command_exists docker; then
            log_error "Falha ao instalar Docker. Por favor, verifique a conexão com a internet ou os repositórios."
            exit 1
        fi
        log_success "Docker instalado com sucesso!"
        
        log_info "Adicionando usuário atual ao grupo docker para evitar o uso de sudo..."
        sudo usermod -aG docker "$USER"
        log_warning "Por favor, faça logout e login novamente para que as permissões do Docker sejam aplicadas."
        log_warning "Após o login, execute este script novamente."
        exit 0
    else
        log_success "Docker já está instalado."
    fi

    # Verificar Docker Compose
    if ! check_docker_compose; then
        log_warning "Docker Compose não encontrado. Tentando instalar..."
        
        # Tentar instalar o plugin docker-compose
        log_info "Tentando instalar docker-compose-plugin..."
        sudo apt update
        sudo apt install -y docker-compose-plugin
        
        # Se ainda não funcionar, instalar a versão standalone
        if ! check_docker_compose; then
            log_info "Instalando Docker Compose standalone..."
            DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
            sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
            sudo chmod +x /usr/local/bin/docker-compose
            
            # Verificar se foi instalado com sucesso
            if ! check_docker_compose; then
                log_error "Falha ao instalar Docker Compose. Por favor, instale manualmente."
                exit 1
            fi
        fi
        
        log_success "Docker Compose instalado com sucesso!"
    else
        log_success "Docker Compose já está instalado."
        # Mostrar qual versão está sendo usada
        if docker compose version >/dev/null 2>&1; then
            COMPOSE_VERSION=$(docker compose version --short 2>/dev/null || echo "unknown")
            log_info "Usando Docker Compose plugin v${COMPOSE_VERSION}"
        elif command_exists docker-compose; then
            COMPOSE_VERSION=$(docker-compose version --short 2>/dev/null || echo "unknown")
            log_info "Usando Docker Compose standalone v${COMPOSE_VERSION}"
        fi
    fi
}

# Função para detectar IP público
get_public_ip() {
    # Tentar diferentes métodos para obter o IP público
    local public_ip
    
    # Método 1: curl para serviços externos
    public_ip=$(curl -s https://ipinfo.io/ip 2>/dev/null)
    if [[ $public_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$public_ip"
        return 0
    fi
    
    # Método 2: alternativa
    public_ip=$(curl -s https://api.ipify.org 2>/dev/null)
    if [[ $public_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$public_ip"
        return 0
    fi
    
    # Método 3: verificar interfaces de rede locais (IP público provável)
    public_ip=$(ip route get 8.8.8.8 | awk '{print $7}' | head -1 2>/dev/null)
    if [[ $public_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        echo "$public_ip"
        return 0
    fi
    
    # Se nenhum método funcionou, retornar erro
    return 1
}

# Função para inicializar Docker Swarm
init_swarm() {
    log_info "Verificando e inicializando Docker Swarm..."
    if ! sudo docker info | grep -q "Swarm: active"; then
        log_info "Docker Swarm não está ativo. Inicializando..."
        
        # Detectar IP público automaticamente
        PUBLIC_IP=$(get_public_ip)
        if [ $? -eq 0 ] && [ -n "$PUBLIC_IP" ]; then
            log_info "IP público detectado: $PUBLIC_IP"
            sudo docker swarm init --advertise-addr "$PUBLIC_IP" || {
                log_error "Falha ao inicializar Docker Swarm com IP $PUBLIC_IP."
                log_info "Tentando com IP da interface eth0..."
                ETH0_IP=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
                if [ -n "$ETH0_IP" ]; then
                    sudo docker swarm init --advertise-addr "$ETH0_IP" || {
                        log_error "Falha ao inicializar Docker Swarm com IP $ETH0_IP."
                        log_warning "Por favor, execute manualmente: sudo docker swarm init --advertise-addr <SEU_IP_PUBLICO>"
                        exit 1
                    }
                else
                    log_error "Não foi possível detectar IP da interface eth0."
                    exit 1
                fi
            }
        else
            log_warning "Não foi possível detectar o IP público automaticamente."
            log_info "Tentando com IP da interface eth0..."
            ETH0_IP=$(ip addr show eth0 | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | head -1)
            if [ -n "$ETH0_IP" ]; then
                log_info "IP da interface eth0 detectado: $ETH0_IP"
                sudo docker swarm init --advertise-addr "$ETH0_IP" || {
                    log_error "Falha ao inicializar Docker Swarm com IP $ETH0_IP."
                    log_warning "Por favor, execute manualmente: sudo docker swarm init --advertise-addr <SEU_IP_PUBLICO>"
                    exit 1
                }
            else
                log_error "Não foi possível detectar IP da interface eth0."
                log_warning "Por favor, execute manualmente: sudo docker swarm init --advertise-addr <SEU_IP_PUBLICO>"
                exit 1
            fi
        fi
        
        log_success "Docker Swarm inicializado com sucesso!"
    else
        log_success "Docker Swarm já está ativo."
    fi
}

# Função para configurar o projeto e SSL
configure_project_and_ssl() {
    log_info "Iniciando configuração do projeto e SSL..."

    # Verificar se estamos no diretório do projeto
    if [ ! -f "docker-compose.yml" ] || [ ! -d "config" ]; then
        log_error "Este script deve ser executado a partir do diretório raiz do seu projeto Laravel Reverb (onde está o docker-compose.yml e a pasta config). Saindo."
        exit 1
    fi

    # Solicitar domínio do projeto
    read -p "$(echo -e "${YELLOW}Digite o domínio do seu projeto (ex: example.com ou sub.example.com): ${NC}")" PROJECT_DOMAIN
    if [ -z "$PROJECT_DOMAIN" ]; then
        log_error "Domínio do projeto não pode ser vazio. Saindo."
        exit 1
    fi

    # Criar .env a partir de .env.example se não existir
    if [ ! -f .env ]; then
        log_info "Criando arquivo .env a partir de .env.example..."
        cp .env.example .env || {
            log_error "Falha ao criar .env. Verifique se .env.example existe."
            exit 1
        }
        log_success "Arquivo .env criado."
    else
        log_info "Arquivo .env já existe."
    fi

    # Atualizar docker-compose.yml com o domínio
    log_info "Atualizando docker-compose.yml com o domínio $PROJECT_DOMAIN..."
    sed -i "s/server_name _;/server_name $PROJECT_DOMAIN;/g" config/default.conf || {
        log_error "Falha ao atualizar config/default.conf. Verifique o arquivo."
        exit 1
    }
    sed -i "s/your-email@example.com/admin@$PROJECT_DOMAIN/g" docker-compose.yml || {
        log_error "Falha ao atualizar email do Certbot no docker-compose.yml."
        exit 1
    }
    sed -i "s/example.com/$PROJECT_DOMAIN/g" docker-compose.yml || {
        log_error "Falha ao atualizar domínio do Certbot no docker-compose.yml."
        exit 1
    }
    log_success "docker-compose.yml e config/default.conf atualizados."

    # Derrubar serviços existentes para liberar portas
    log_info "Derrubando serviços Docker Compose existentes para liberar portas..."
    if check_docker_compose; then
        if docker compose version >/dev/null 2>&1; then
            sudo docker compose down
        else
            sudo docker-compose down
        fi
    fi

    # Construir e subir os serviços
    log_info "Construindo e subindo os serviços Docker Compose..."
    if docker compose version >/dev/null 2>&1; then
        sudo docker compose up -d --build || {
            log_error "Falha ao construir e subir os serviços Docker Compose."
            exit 1
        }
    else
        sudo docker-compose up -d --build || {
            log_error "Falha ao construir e subir os serviços Docker Compose."
            exit 1
        }
    fi
    log_success "Serviços Docker Compose iniciados com sucesso."

    # Obter certificado SSL com Certbot
    log_info "Obtendo certificado SSL para $PROJECT_DOMAIN com Certbot..."
    # Aguarda o Nginx estar pronto para o desafio HTTP-01
    sleep 10
    if docker compose version >/dev/null 2>&1; then
        sudo docker compose run --rm certbot certonly --webroot -w /var/www/certbot --email admin@$PROJECT_DOMAIN --agree-tos --no-eff-email -d $PROJECT_DOMAIN || {
            log_error "Falha ao obter certificado SSL com Certbot. Verifique o apontamento DNS e os logs do Certbot."
            log_info "Tentando novamente em 5 segundos..."
            sleep 5
            sudo docker compose run --rm certbot certonly --webroot -w /var/www/certbot --email admin@$PROJECT_DOMAIN --agree-tos --no-eff-email -d $PROJECT_DOMAIN || {
                log_error "Falha persistente ao obter certificado SSL. Por favor, verifique manualmente."
                exit 1
            }
        }
    else
        sudo docker-compose run --rm certbot certonly --webroot -w /var/www/certbot --email admin@$PROJECT_DOMAIN --agree-tos --no-eff-email -d $PROJECT_DOMAIN || {
            log_error "Falha ao obter certificado SSL com Certbot. Verifique o apontamento DNS e os logs do Certbot."
            log_info "Tentando novamente em 5 segundos..."
            sleep 5
            sudo docker-compose run --rm certbot certonly --webroot -w /var/www/certbot --email admin@$PROJECT_DOMAIN --agree-tos --no-eff-email -d $PROJECT_DOMAIN || {
                log_error "Falha persistente ao obter certificado SSL. Por favor, verifique manualmente."
                exit 1
            }
        }
    fi
    log_success "Certificado SSL obtido com sucesso para $PROJECT_DOMAIN."

    # Reiniciar Nginx para carregar o novo certificado
    log_info "Reiniciando Nginx para carregar o novo certificado SSL..."
    if docker compose version >/dev/null 2>&1; then
        sudo docker compose exec laraverb-app nginx -s reload || {
            log_error "Falha ao reiniciar Nginx."
            exit 1
        }
    else
        sudo docker-compose exec laraverb-app nginx -s reload || {
            log_error "Falha ao reiniciar Nginx."
            exit 1
        }
    fi
    log_success "Nginx reiniciado com sucesso."

    # Gerar APP_KEY e executar migrações
    log_info "Gerando APP_KEY do Laravel e executando migrações..."
    if docker compose version >/dev/null 2>&1; then
        sudo docker compose exec laraverb-app php artisan key:generate --force || {
            log_error "Falha ao gerar APP_KEY."
            exit 1
        }
        sudo docker compose exec laraverb-app php artisan migrate --force || {
            log_error "Falha ao executar migrações do Laravel."
            exit 1
        }
    else
        sudo docker-compose exec laraverb-app php artisan key:generate --force || {
            log_error "Falha ao gerar APP_KEY."
            exit 1
        }
        sudo docker-compose exec laraverb-app php artisan migrate --force || {
            log_error "Falha ao executar migrações do Laravel."
            exit 1
        }
    fi
    log_success "APP_KEY gerada e migrações executadas."

    # Limpar e otimizar caches do Laravel
    log_info "Limpando e otimizando caches do Laravel..."
    if docker compose version >/dev/null 2>&1; then
        sudo docker compose exec laraverb-app php artisan config:clear
        sudo docker compose exec laraverb-app php artisan cache:clear
        sudo docker compose exec laraverb-app php artisan view:clear
        sudo docker compose exec laraverb-app php artisan route:clear
        sudo docker compose exec laraverb-app php artisan optimize
    else
        sudo docker-compose exec laraverb-app php artisan config:clear
        sudo docker-compose exec laraverb-app php artisan cache:clear
        sudo docker-compose exec laraverb-app php artisan view:clear
        sudo docker-compose exec laraverb-app php artisan route:clear
        sudo docker-compose exec laraverb-app php artisan optimize
    fi
    log_success "Caches do Laravel limpos e otimizados."
}

# Função para exibir informações finais
display_final_info() {
    echo -e "\n${BLUE}===================================================="
    echo -e "          INSTALAÇÃO CONCLUÍDA!         "
    echo -e "====================================================${NC}"
    log_success "Sua aplicação Laravel Reverb está pronta!"
    echo -e "\nURLs de Acesso:"
    echo -e "- Aplicação Web (HTTPS): ${GREEN}https://$PROJECT_DOMAIN${NC}"
    echo -e "- WebSocket (WSS): ${GREEN}wss://$PROJECT_DOMAIN/app/${NC} (ou porta 8080 se não estiver usando proxy Nginx para Reverb na 443)"
    echo -e "- PhpMyAdmin: ${GREEN}http://localhost:8081${NC} (acessível apenas do servidor, ou mapeie porta)"
    echo -e "- Mailpit: ${GREEN}http://localhost:8025${NC} (acessível apenas do servidor, ou mapeie porta)"

    echo -e "\nComandos Úteis:"
    if docker compose version >/dev/null 2>&1; then
        echo -e "- Ver status dos serviços: ${BLUE}sudo docker compose ps${NC}"
        echo -e "- Ver logs da aplicação: ${BLUE}sudo docker compose logs laraverb-app${NC}"
        echo -e "- Ver logs de todos os serviços: ${BLUE}sudo docker compose logs${NC}"
        echo -e "- Entrar no contêiner da aplicação: ${BLUE}sudo docker compose exec laraverb-app bash${NC}"
        echo -e "- Derrubar todos os serviços: ${BLUE}sudo docker compose down${NC}"
        echo -e "- Reiniciar todos os serviços: ${BLUE}sudo docker compose restart${NC}"
        echo -e "- Renovar certificado SSL (a cada 90 dias): ${BLUE}sudo docker compose run --rm certbot renew && sudo docker compose exec laraverb-app nginx -s reload${NC}"
    else
        echo -e "- Ver status dos serviços: ${BLUE}sudo docker-compose ps${NC}"
        echo -e "- Ver logs da aplicação: ${BLUE}sudo docker-compose logs laraverb-app${NC}"
        echo -e "- Ver logs de todos os serviços: ${BLUE}sudo docker-compose logs${NC}"
        echo -e "- Entrar no contêiner da aplicação: ${BLUE}sudo docker-compose exec laraverb-app bash${NC}"
        echo -e "- Derrubar todos os serviços: ${BLUE}sudo docker-compose down${NC}"
        echo -e "- Reiniciar todos os serviços: ${BLUE}sudo docker-compose restart${NC}"
        echo -e "- Renovar certificado SSL (a cada 90 dias): ${BLUE}sudo docker-compose run --rm certbot renew && sudo docker-compose exec laraverb-app nginx -s reload${NC}"
    fi
    echo -e "\n===================================================="
}

# --- Fluxo Principal do Script ---

echo -e "\n${BLUE}===================================================="
echo -e "  Instalador Automatizado Laravel Reverb com SSL  "
echo -e "====================================================${NC}"

# Mensagem inicial sobre DNS
log_warning "Antes de prosseguir, certifique-se de que o domínio que você usará"
log_warning "já está apontando para o IP público deste servidor no seu provedor de DNS."
log_warning "A propagação do DNS pode levar alguns minutos ou horas."

read -p "$(echo -e "${YELLOW}Já fez o apontamento do domínio e aguardou a propagação? (s/n): ${NC}")" DNS_CONFIRMED

if [[ "$DNS_CONFIRMED" =~ ^[Ss]$ ]]; then
    log_info "Prosseguindo com a instalação..."
else
    log_error "Por favor, faça o apontamento do domínio e aguarde a propagação antes de executar o script novamente."
    exit 1
fi

# 1. Instalar Docker
install_docker

# 2. Inicializar Swarm
init_swarm

# 3. Configurar projeto e SSL
configure_project_and_ssl

# 4. Exibir informações finais
display_final_info

log_success "Script concluído!"