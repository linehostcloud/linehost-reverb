# Laravel Reverb Docker Makefile
# Facilita o uso de comandos comuns do Docker

.PHONY: help build up down restart logs shell test clean

# Default target
help: ## Mostra esta ajuda
	@echo "Laravel Reverb Docker - Comandos Disponíveis:"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'

# Build commands
build: ## Constrói a imagem Docker
	docker build -t laraverb:latest .

build-no-cache: ## Constrói a imagem Docker sem cache
	docker build --no-cache -t laraverb:latest .

# Docker Compose commands
up: ## Inicia todos os serviços
	docker compose up -d

up-dev: ## Inicia serviços com ferramentas de desenvolvimento
	docker compose --profile development up -d

up-build: ## Inicia serviços reconstruindo as imagens
	docker compose up -d --build

down: ## Para todos os serviços
	docker compose down

restart: ## Reinicia todos os serviços
	docker compose restart

# Logs and monitoring
logs: ## Mostra logs de todos os serviços
	docker compose logs -f

logs-app: ## Mostra logs apenas da aplicação
	docker compose logs -f laraverb

logs-mysql: ## Mostra logs do MySQL
	docker compose logs -f mysql

logs-redis: ## Mostra logs do Redis
	docker compose logs -f redis

# Shell access
shell: ## Acessa shell da aplicação
	docker compose exec laraverb bash

shell-mysql: ## Acessa shell do MySQL
	docker compose exec mysql mysql -u laravel -p laravel

shell-redis: ## Acessa shell do Redis
	docker compose exec redis redis-cli

# Laravel commands
artisan: ## Executa comando artisan (use: make artisan CMD="migrate")
	docker compose exec laraverb php artisan $(CMD)

migrate: ## Executa migrations
	docker compose exec laraverb php artisan migrate

migrate-fresh: ## Executa fresh migrations
	docker compose exec laraverb php artisan migrate:fresh --seed

seed: ## Executa seeders
	docker compose exec laraverb php artisan db:seed

cache-clear: ## Limpa todos os caches
	docker compose exec laraverb php artisan cache:clear
	docker compose exec laraverb php artisan config:clear
	docker compose exec laraverb php artisan route:clear
	docker compose exec laraverb php artisan view:clear

cache-optimize: ## Otimiza caches para produção
	docker compose exec laraverb php artisan config:cache
	docker compose exec laraverb php artisan route:cache
	docker compose exec laraverb php artisan view:cache

# Testing and health checks
test: ## Executa testes
	docker compose exec laraverb php artisan test

health: ## Verifica saúde dos serviços
	docker compose exec laraverb /usr/local/bin/healthcheck-reverb.sh

# Development tools
install: ## Instala dependências
	docker compose exec laraverb composer install

update: ## Atualiza dependências
	docker compose exec laraverb composer update

npm-install: ## Instala dependências NPM
	docker compose exec laraverb npm install

npm-dev: ## Executa build de desenvolvimento
	docker compose exec laraverb npm run dev

npm-build: ## Executa build de produção
	docker compose exec laraverb npm run build

# Cleanup commands
clean: ## Remove containers, volumes e imagens não utilizados
	docker compose down -v
	docker system prune -f

clean-all: ## Remove tudo (CUIDADO: remove volumes com dados)
	docker compose down -v --rmi all
	docker system prune -af

# Backup and restore
backup-db: ## Faz backup do banco de dados
	docker compose exec mysql mysqldump -u laravel -p laravel > backup_$(shell date +%Y%m%d_%H%M%S).sql

restore-db: ## Restaura backup do banco (use: make restore-db FILE=backup.sql)
	docker compose exec -T mysql mysql -u laravel -p laravel < $(FILE)

# Production commands
deploy: ## Deploy para produção
	docker compose -f docker-compose.yml up -d --build
	make cache-optimize
	make migrate

# Monitoring
stats: ## Mostra estatísticas dos containers
	docker stats

ps: ## Lista containers em execução
	docker compose ps

# Quick start
quick-start: build up migrate ## Início rápido: build, up e migrate
	@echo "🚀 Laravel Reverb está rodando!"
	@echo "📱 Aplicação: http://localhost"
	@echo "🔌 WebSocket: ws://localhost:8080"
	@echo "🗄️  PhpMyAdmin: http://localhost:8081 (perfil development)"
	@echo "📧 Mailpit: http://localhost:8025 (perfil development)"

