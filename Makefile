# Cores para saída do terminal
GREEN  := \033[0;32m
YELLOW := \033[0;33m
BLUE   := \033[0;34m
MAGENTA:= \033[0;35m
CYAN   := \033[0;36m
RESET  := \033[0m

.PHONY: help setup dev sail-up sail-down migrate migrate-fresh seed tinker test lint frontend-install backend-install

# Target padrão: exibe a ajuda
help:
	@printf "$(GREEN)Comandos disponíveis no Monorepo Livezinha (Executados via Docker/Host):$(RESET)\n\n"
	@printf "  $(YELLOW)make setup$(RESET)           Inicializa o projeto (instala dependências via Docker/NPM, cria .env, sobe Docker e popula banco)\n"
	@printf "  $(YELLOW)make dev$(RESET)             Sobe o Docker Sail e inicia os servidores de desenvolvimento do backend e frontend juntos\n"
	@printf "  $(YELLOW)make sail-up$(RESET)         Sobe os contêineres Docker Sail (MySQL, etc.) em segundo plano\n"
	@printf "  $(YELLOW)make sail-down$(RESET)       Para os contêineres do Docker Sail\n"
	@printf "  $(YELLOW)make migrate$(RESET)         Executa as migrações no banco de dados via Sail\n"
	@printf "  $(YELLOW)make migrate-fresh$(RESET)   Recria o banco de dados do zero e roda a sementeira (seeds) via Sail\n"
	@printf "  $(YELLOW)make seed$(RESET)            Executa a sementeira (seeds) no banco de dados via Sail\n"
	@printf "  $(YELLOW)make tinker$(RESET)          Abre o shell interativo do Laravel Tinker via Sail\n"
	@printf "  $(YELLOW)make test$(RESET)            Executa os testes do backend via Sail\n"
	@printf "  $(YELLOW)make lint$(RESET)            Executa o Laravel Pint para linting do código backend via Sail\n"

# Inicia o Laravel Sail (Backend) e Vite (Frontend) concorrentemente
dev:
	@printf "$(CYAN)Iniciando Docker Sail (Backend) e Vite Server (Frontend)...$(RESET)\n"
	npx concurrently --kill-others \
		--names "backend,frontend" \
		-c "blue,magenta" \
		"cd backend && ./vendor/bin/sail up" \
		"cd frontend && npm run dev"

# Sobe os serviços Docker do Sail
sail-up:
	@printf "$(CYAN)Iniciando Docker Sail em segundo plano...$(RESET)\n"
	cd backend && ./vendor/bin/sail up -d

# Para os serviços Docker do Sail
sail-down:
	@printf "$(CYAN)Parando serviços do Docker Sail...$(RESET)\n"
	cd backend && ./vendor/bin/sail down

# Executa migrações via Sail
migrate:
	@printf "$(CYAN)Executando migrações do banco de dados...$(RESET)\n"
	cd backend && ./vendor/bin/sail artisan migrate

# Limpa, migra e popula banco via Sail
migrate-fresh:
	@printf "$(CYAN)Recriando banco de dados e executando seeds...$(RESET)\n"
	cd backend && ./vendor/bin/sail artisan migrate:fresh --seed

# Roda as seeds via Sail
seed:
	@printf "$(CYAN)Populando o banco de dados...$(RESET)\n"
	cd backend && ./vendor/bin/sail artisan db:seed

# Abre Tinker via Sail
tinker:
	cd backend && ./vendor/bin/sail artisan tinker

# Roda testes do backend via Sail
test:
	@printf "$(CYAN)Executando testes do backend...$(RESET)\n"
	cd backend && ./vendor/bin/sail composer test

# Roda linter Pint via Sail
lint:
	@printf "$(CYAN)Executando linter no backend...$(RESET)\n"
	cd backend && ./vendor/bin/sail pint

# Instala dependências do backend usando um contêiner temporário (evita precisar de PHP/Composer no host)
backend-install:
	@printf "$(CYAN)Criando arquivo .env se não existir...$(RESET)\n"
	cd backend && cp -n .env.example .env || true
	@printf "$(CYAN)Instalando dependências do Composer usando contêiner Docker temporário...$(RESET)\n"
	docker run --rm \
		-u "$$(id -u):$$(id -g)" \
		-v "$$(pwd)/backend:/var/www/html" \
		-w /var/www/html \
		laravelsail/php83-composer:latest \
		composer install

# Instala dependências do frontend (roda no host)
frontend-install:
	@printf "$(CYAN)Criando arquivo .env do Frontend se não existir...$(RESET)\n"
	cd frontend && cp -n .env.example .env || true
	@printf "$(CYAN)Instalando dependências do NPM no Frontend...$(RESET)\n"
	cd frontend && npm install

# Setup completo do monorepo
setup: backend-install frontend-install
	@printf "$(CYAN)Subindo ambiente Docker Sail para finalizar configuração...$(RESET)\n"
	cd backend && ./vendor/bin/sail up -d
	@printf "$(CYAN)Aguardando o banco de dados iniciar...$(RESET)\n"
	sleep 5
	cd backend && ./vendor/bin/sail artisan key:generate
	cd backend && ./vendor/bin/sail artisan migrate:fresh --seed
	@printf "$(GREEN)Setup concluído com sucesso! Você pode rodar 'make dev' para iniciar o desenvolvimento.$(RESET)\n"
