# 🚀 Laravel Reverb Docker

Uma solução completa e otimizada para executar **Laravel Reverb** (WebSocket server) em containers Docker, com configurações de produção e ferramentas de desenvolvimento integradas.

## 📋 Características

- **🐳 Docker otimizado**: Imagem Alpine Linux leve e segura
- **⚡ Multi-processo**: Nginx + PHP-FPM + Reverb + Queue Workers + Scheduler
- **🔄 Auto-healing**: Health checks e restart automático
- **📊 Monitoramento**: Supervisor para gerenciamento de processos
- **🛡️ Segurança**: Configurações hardened e rate limiting
- **🔧 Desenvolvimento**: Ferramentas integradas (PhpMyAdmin, Mailpit, Redis Commander)
- **📈 Performance**: OPcache, Redis, otimizações de cache
- **🎯 Produção**: Configurações otimizadas para alta performance

## 🏗️ Arquitetura

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Container                         │
├─────────────────────────────────────────────────────────────┤
│  Nginx (Port 80)          │  Laravel Reverb (Port 8080)     │
│  ├─ Static Files          │  ├─ WebSocket Server            │
│  ├─ PHP-FPM Proxy         │  ├─ Real-time Broadcasting      │
│  └─ WebSocket Proxy       │  └─ Event Broadcasting          │
├─────────────────────────────────────────────────────────────┤
│  PHP-FPM (Port 9000)      │  Queue Workers                  │
│  ├─ Laravel Application   │  ├─ Background Jobs             │
│  ├─ API Endpoints         │  ├─ Email Processing            │
│  └─ Web Interface         │  └─ Async Tasks                 │
├─────────────────────────────────────────────────────────────┤
│  Scheduler                │  Redis (Port 6379)              │
│  ├─ Cron Jobs             │  ├─ Session Storage             │
│  ├─ Maintenance Tasks     │  ├─ Cache Layer                 │
│  └─ Automated Backups     │  └─ Queue Backend               │
└─────────────────────────────────────────────────────────────┘
```

## 🚀 Início Rápido

### Pré-requisitos

- Docker 20.10+
- Docker Compose 2.0+
- Make (opcional, para comandos facilitados)

### 1. Clone o repositório

```bash
git clone https://github.com/linehostcloud/linehost-reverb.git
cd laraverb
```

### 2. Configure o ambiente

```bash
# Copie o arquivo de exemplo
cp .env.example .env

# Edite as configurações conforme necessário
nano .env
```

### 3. Inicie os serviços

```bash
# Usando Make (recomendado)
make quick-start

# Ou usando Docker Compose diretamente
docker-compose up -d --build
docker-compose exec laraverb php artisan migrate
```

### 4. Acesse a aplicação

- **Aplicação Web**: http://localhost
- **WebSocket**: ws://localhost:8080
- **PhpMyAdmin**: http://localhost:8081 (modo desenvolvimento)
- **Mailpit**: http://localhost:8025 (modo desenvolvimento)
- **Redis Commander**: http://localhost:8082 (modo desenvolvimento)

## 📁 Estrutura do Projeto

```
laraverb/
├── 🐳 Dockerfile                 # Imagem Docker otimizada
├── 🔧 docker-compose.yml         # Orquestração de serviços
├── 📋 Makefile                   # Comandos facilitados
├── 📄 .env.example               # Configurações de exemplo
├── 🚫 .dockerignore              # Arquivos ignorados no build
├── config/                       # Configurações dos serviços
│   ├── 🐘 php.ini               # Configurações PHP otimizadas
│   ├── 🌐 nginx.conf            # Configuração principal Nginx
│   ├── 🔗 reverb-site.conf      # Virtual host com proxy WebSocket
│   └── 👥 supervisor.conf        # Gerenciamento de processos
├── scripts/                      # Scripts de automação
│   ├── 🚀 docker-entrypoint.sh  # Script de inicialização
│   └── 🏥 healthcheck-reverb.sh  # Verificação de saúde
└── 📖 README.md                  # Esta documentação
```

## ⚙️ Configuração

### Variáveis de Ambiente

| Variável | Padrão | Descrição |
|----------|--------|-----------|
| `APP_ENV` | `production` | Ambiente da aplicação |
| `APP_DEBUG` | `false` | Debug mode |
| `DB_HOST` | `mysql` | Host do banco de dados |
| `DB_DATABASE` | `laravel` | Nome do banco |
| `DB_USERNAME` | `laravel` | Usuário do banco |
| `DB_PASSWORD` | `secret` | Senha do banco |
| `REDIS_HOST` | `127.0.0.1` | Host do Redis |
| `REVERB_APP_ID` | `app-id` | ID da aplicação Reverb |
| `REVERB_APP_KEY` | `app-key` | Chave da aplicação |
| `REVERB_APP_SECRET` | `app-secret` | Secret da aplicação |
| `REVERB_HOST` | `0.0.0.0` | Host do servidor Reverb |
| `REVERB_PORT` | `8080` | Porta do servidor Reverb |
| `AUTO_MIGRATE` | `false` | Executar migrations automaticamente |
| `AUTO_SEED` | `false` | Executar seeders automaticamente |

### Configurações de Produção

Para ambiente de produção, ajuste as seguintes configurações:

```env
APP_ENV=production
APP_DEBUG=false
LOG_LEVEL=warning

# Use banco de dados externo
DB_HOST=your-database-host
DB_PASSWORD=strong-password

# Use Redis externo
REDIS_HOST=your-redis-host

# Configure domínios
APP_URL=https://your-domain.com
SANCTUM_STATEFUL_DOMAINS=your-domain.com
```

## 🛠️ Comandos Úteis

### Usando Make

```bash
# Gerenciamento de containers
make build              # Constrói a imagem
make up                  # Inicia serviços
make down                # Para serviços
make restart             # Reinicia serviços
make logs                # Mostra logs

# Desenvolvimento
make shell               # Acessa shell da aplicação
make artisan CMD="route:list"  # Executa comando artisan
make migrate             # Executa migrations
make test                # Executa testes

# Manutenção
make cache-clear         # Limpa caches
make cache-optimize      # Otimiza caches
make health              # Verifica saúde
make backup-db           # Backup do banco
```

### Usando Docker Compose

```bash
# Serviços básicos
docker-compose up -d
docker-compose down
docker-compose logs -f

# Desenvolvimento com ferramentas extras
docker-compose --profile development up -d

# Comandos Laravel
docker-compose exec laraverb php artisan migrate
docker-compose exec laraverb php artisan queue:work
docker-compose exec laraverb php artisan reverb:start
```

## 🔧 Desenvolvimento

### Modo Desenvolvimento

Para ativar ferramentas de desenvolvimento:

```bash
# Inicia com PhpMyAdmin, Mailpit e Redis Commander
make up-dev

# Ou
docker-compose --profile development up -d
```

### Instalação de Dependências

```bash
# Composer
make install
docker-compose exec laraverb composer install

# NPM
make npm-install
docker-compose exec laraverb npm install

# Build assets
make npm-build
docker-compose exec laraverb npm run build
```

### Debugging

```bash
# Logs em tempo real
make logs

# Logs específicos
make logs-app
make logs-mysql
make logs-redis

# Shell interativo
make shell

# Verificação de saúde
make health
```

## 🏥 Monitoramento e Health Checks

O sistema inclui verificações automáticas de saúde:

- **Nginx**: Verifica se o servidor web está respondendo
- **PHP-FPM**: Verifica se o processador PHP está ativo
- **Reverb**: Verifica se o servidor WebSocket está funcionando
- **MySQL**: Verifica conectividade com banco de dados
- **Redis**: Verifica cache e sessões
- **Supervisor**: Monitora todos os processos

### Endpoints de Monitoramento

- `GET /health` - Status geral da aplicação
- Health check automático via Docker a cada 30 segundos

## 🔒 Segurança

### Configurações Implementadas

- **Rate Limiting**: Proteção contra ataques DDoS
- **Security Headers**: XSS, CSRF, Content-Type protection
- **File Permissions**: Permissões restritivas nos arquivos
- **Process Isolation**: Processos executam com usuário não-root
- **Input Validation**: Validação de entrada em todos os endpoints

### Recomendações Adicionais

1. **SSL/TLS**: Use HTTPS em produção
2. **Firewall**: Configure firewall para portas específicas
3. **Backup**: Implemente backup automático
4. **Monitoring**: Use ferramentas de monitoramento externas
5. **Updates**: Mantenha imagens atualizadas

## 🚀 Deploy em Produção

### 1. Preparação

```bash
# Clone em servidor de produção
git clone https://github.com/linehostcloud/linehost-reverb.git
cd laraverb

# Configure ambiente
cp .env.example .env
nano .env  # Ajuste para produção
```

### 2. Deploy

```bash
# Deploy completo
make deploy

# Ou manualmente
docker-compose -f docker-compose.yml up -d --build
make cache-optimize
make migrate
```

### 3. Configuração de Proxy Reverso (Nginx)

```nginx
server {
    listen 80;
    server_name your-domain.com;
    
    location / {
        proxy_pass http://localhost:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
    
    location /app/ {
        proxy_pass http://localhost:8080;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }
}
```

## 🧪 Testes

### Executando Testes

```bash
# Todos os testes
make test

# Testes específicos
docker-compose exec laraverb php artisan test --filter=ReverbTest

# Coverage
docker-compose exec laraverb php artisan test --coverage
```

### Teste de WebSocket

```javascript
// Frontend JavaScript
const echo = new Echo({
    broadcaster: 'reverb',
    key: 'app-key',
    wsHost: window.location.hostname,
    wsPort: 8080,
    forceTLS: false,
});

echo.channel('test-channel')
    .listen('TestEvent', (e) => {
        console.log('Received:', e);
    });
```

## 🤝 Contribuição

1. Fork o projeto
2. Crie uma branch para sua feature (`git checkout -b feature/AmazingFeature`)
3. Commit suas mudanças (`git commit -m 'Add some AmazingFeature'`)
4. Push para a branch (`git push origin feature/AmazingFeature`)
5. Abra um Pull Request

## 📝 Changelog

### v2.0.0 (2025-01-02)
- ✨ Estrutura completa e otimizada
- 🐳 Dockerfile multi-estágio
- 🔧 Configurações de produção
- 📊 Monitoramento integrado
- 🛡️ Melhorias de segurança
- 📖 Documentação completa

### v1.0.0 (2024-05-14)
- 🎉 Versão inicial
- 🐳 Dockerfile básico
- 📋 README inicial

## 📄 Licença

Este projeto está licenciado sob a Licença MIT - veja o arquivo [LICENSE](LICENSE) para detalhes.


⭐ **Se este projeto foi útil, considere dar uma estrela no GitHub!**

