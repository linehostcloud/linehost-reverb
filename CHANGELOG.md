# Changelog

Todas as mudanças notáveis neste projeto serão documentadas neste arquivo.

O formato é baseado em [Keep a Changelog](https://keepachangelog.com/pt-BR/1.0.0/),
e este projeto adere ao [Semantic Versioning](https://semver.org/lang/pt-BR/).

## [2.0.0] - 2025-01-02

### ✨ Adicionado
- **Dockerfile otimizado** com base Alpine Linux para menor tamanho
- **Multi-processo** com Supervisor gerenciando Nginx, PHP-FPM, Reverb, Queue e Schedule
- **Configurações PHP** otimizadas para WebSocket e alta performance
- **Nginx** com proxy WebSocket e configurações de segurança
- **Health checks** automáticos para monitoramento
- **Docker Compose** completo com MySQL, Redis e ferramentas de desenvolvimento
- **Makefile** com comandos facilitados para desenvolvimento e produção
- **Scripts de automação** para inicialização e verificação de saúde
- **Documentação completa** com exemplos e guias de uso
- **Configurações de segurança** com rate limiting e headers de proteção
- **Suporte a desenvolvimento** com PhpMyAdmin, Mailpit e Redis Commander

### 🔧 Configurações
- **PHP 8.3** com extensões otimizadas (Redis, OPcache, sockets)
- **Nginx** com configurações de performance e proxy WebSocket
- **Supervisor** para gerenciamento robusto de processos
- **Redis** para cache, sessões e queue backend
- **MySQL 8.0** como banco de dados padrão
- **Variáveis de ambiente** configuráveis para diferentes ambientes

### 🛡️ Segurança
- **Rate limiting** em endpoints críticos
- **Security headers** (XSS, CSRF, Content-Type protection)
- **Permissões de arquivo** restritivas
- **Processo não-root** para aplicação
- **Validação de entrada** em configurações

### 📊 Monitoramento
- **Health checks** Docker nativos
- **Logs estruturados** para todos os serviços
- **Métricas** de performance via Supervisor
- **Endpoints** de status e saúde

### 🚀 Performance
- **OPcache** habilitado para PHP
- **Gzip compression** no Nginx
- **Connection pooling** para banco de dados
- **Redis caching** para sessões e cache
- **Otimizações** de buffer e timeout

### 📖 Documentação
- **README** completo com guias de uso
- **Exemplos** de configuração para produção
- **Comandos** facilitados via Makefile
- **Arquitetura** documentada com diagramas
- **Troubleshooting** e FAQ

## [1.0.0] - 2024-05-14

### ✨ Adicionado
- **Dockerfile básico** com PHP 8.3-FPM
- **Instalação automática** do Laravel com Reverb
- **Configurações básicas** de ambiente
- **README inicial** com instruções básicas
- **Licença MIT**

### 🔧 Configurações Iniciais
- **PHP-FPM** como base
- **Composer** para gerenciamento de dependências
- **Laravel Reverb** instalado automaticamente
- **Usuário não-root** para segurança básica

---

## Tipos de Mudanças

- `✨ Adicionado` para novas funcionalidades
- `🔧 Modificado` para mudanças em funcionalidades existentes
- `🐛 Corrigido` para correções de bugs
- `🗑️ Removido` para funcionalidades removidas
- `🛡️ Segurança` para melhorias de segurança
- `📊 Performance` para melhorias de performance
- `📖 Documentação` para mudanças na documentação

