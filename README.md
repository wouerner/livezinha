# Livezinha 🎥

O **Livezinha** é um monorepo que contém uma plataforma completa para gerenciar transmissões ao vivo interativas. A plataforma permite que espectadores enviem perguntas e votem em tempo real, enquanto o streamer/administrador gerencia as transmissões, modera perguntas e exibe a pergunta ativa através de um overlay para o OBS Studio.

O projeto é dividido em dois subprojetos independentes:
- **Backend**: API RESTful desenvolvida com Laravel 13.x (PHP 8.3+).
- **Frontend**: Single Page Application (SPA) standalone desenvolvida com Vue 3 e Vite.

---

## 📂 Estrutura do Monorepo

```bash
livezinha/
├── backend/          # API Laravel 13 + Docker Sail + MySQL
└── frontend/         # SPA Vue 3 + Vite (Consome a API REST)
```

- Para detalhes específicos sobre o desenvolvimento da API, veja o [README do Backend](./backend/README.md).
- Para detalhes específicos sobre a interface do usuário e o overlay de OBS, veja o [README do Frontend](./frontend/README.md).

---

## 🚀 Como Iniciar Rápido

### Pré-requisitos

Antes de iniciar, certifique-se de ter instalado em sua máquina:
- [Docker](https://www.docker.com/) & Docker Compose
- [Node.js](https://nodejs.org/) (versão 18+) & npm
- **Make** (geralmente pré-instalado em sistemas Linux/macOS)

---

### 🛠️ Método 1: Utilizando o Makefile (Recomendado)

O projeto possui um [Makefile](./Makefile) na raiz para automatizar e unificar o gerenciamento dos projetos.

#### 1. Setup Inicial
Para criar os arquivos `.env`, instalar todas as dependências (usando Docker para o backend, sem precisar de PHP/Composer no host) e preparar o banco de dados:
```bash
make setup
```

#### 2. Executar os projetos juntos
Para subir o banco de dados e a API via Docker Sail, e iniciar o servidor de desenvolvimento do frontend concorrentemente:
```bash
make dev
```
*   **Backend (API)**: Disponível em `http://localhost`
*   **Frontend (SPA)**: Disponível em `http://localhost:5173`
*   Para parar ambos os servidores, basta pressionar `Ctrl+C` no terminal.

#### Outros comandos úteis:
- `make sail-down`: Para os containers do Docker Sail.
- `make migrate-fresh`: Limpa, migra e popula o banco de dados novamente.
- `make test`: Executa a suíte de testes do backend.
- `make lint`: Executa o formatador de código (Laravel Pint).
- `make help`: Mostra todos os comandos disponíveis no Makefile.

---

### 📝 Método 2: Inicialização Manual (Alternativo)

Caso prefira rodar os comandos individualmente em terminais separados:

#### Passo 1: Inicializar o Backend
O backend utiliza o Laravel Sail para rodar os serviços necessários (PHP, MySQL) de forma isolada.

1. Acesse o diretório do backend:
   ```bash
   cd backend
   ```
2. Copie o arquivo de variáveis de ambiente:
   ```bash
   cp .env.example .env
   ```
3. Instale as dependências usando um contêiner temporário (caso não possua PHP/Composer local):
   ```bash
   docker run --rm \
       -u "$(id -u):$(id -g)" \
       -v "$(pwd):/var/www/html" \
       -w /var/www/html \
       laravelsail/php83-composer:latest \
       composer install
   ```
4. Suba os contêineres do Docker Sail em segundo plano:
   ```bash
   ./vendor/bin/sail up -d
   ```
5. Execute as migrações e popule o banco de dados:
   ```bash
   ./vendor/bin/sail artisan migrate:fresh --seed
   ```

#### Passo 2: Inicializar o Frontend
O frontend roda diretamente na máquina hospedeira.

1. Em um novo terminal, acesse o diretório do frontend:
   ```bash
   cd frontend
   ```
2. Copie o arquivo de variáveis de ambiente:
   ```bash
   cp .env.example .env
   ```
3. Instale as dependências do Node.js:
   ```bash
   npm install
   ```
4. Inicie o servidor de desenvolvimento do Vite:
   ```bash
   npm run dev
   ```

---

## 🔐 Credenciais de Acesso (Admin)

Após rodar a sementeira (`db:seed`) no backend, você poderá acessar o painel administrativo usando:
- **URL**: `http://localhost:5173/#/admin`
- **E-mail**: `admin@livezinha.com`
- **Senha**: `admin123`

---

## 🛠️ Tecnologias Utilizadas

- **Backend**: Laravel 13, Laravel Sail (Docker), PHP 8.3+, MySQL 8.4, Laravel Sanctum (Autenticação SPA).
- **Frontend**: Vue 3 (Composition API / `<script setup>`), Vite, Vanilla CSS.

---

## 📝 Licença

Este projeto é de uso livre e sob licença MIT.
