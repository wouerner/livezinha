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

## 🚀 Como Iniciar Rapido

### Pré-requisitos

Antes de iniciar, certifique-se de ter instalado em sua máquina:
- [Docker](https://www.docker.com/) & Docker Compose
- [Node.js](https://nodejs.org/) (versão 18+) & npm

---

### Passo 1: Inicializar o Backend

O backend utiliza o Laravel Sail para rodar os serviços necessários (PHP, MySQL, etc.) de forma isolada em contêineres Docker.

1. Acesse o diretório do backend:
   ```bash
   cd backend
   ```

2. Copie o arquivo de variáveis de ambiente:
   ```bash
   cp .env.example .env
   ```

3. Instale as dependências do PHP (caso tenha o PHP e Composer instalados localmente):
   ```bash
   composer install
   ```
   *Nota: Caso não possua PHP/Composer instalado na máquina hospedeira, você pode usar um contêiner temporário para instalar as dependências:*
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

5. Execute o setup inicial do projeto (isto executará migrações e populará o banco de dados):
   ```bash
   ./vendor/bin/sail artisan migrate:fresh --seed
   ```

6. Inicie os serviços do backend (servidor web, filas e logs concorrentes):
   ```bash
   composer dev
   ```

A API estará disponível em `http://localhost`.

---

### Passo 2: Inicializar o Frontend

O frontend é uma SPA que roda separada da aplicação Laravel.

1. Abra um novo terminal e acesse o diretório do frontend:
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

O frontend estará disponível em `http://localhost:5173`.

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
