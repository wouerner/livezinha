# Descrições do Projeto Livezinha 📝

Este arquivo contém sugestões de descrições bem estruturadas e profissionais em português para você copiar e colar nas configurações dos repositórios (GitHub, GitLab, etc.).

---

## 1. Monorepo Principal (`livezinha`)

* **Descrição Curta (Ideal para o campo "Description" do GitHub):**
  > Monorepo do Livezinha — Plataforma interativa para gerenciar transmissões ao vivo com envio e moderação de perguntas de espectadores, votações em tempo real e overlay dinâmico para o OBS Studio.

* **Descrição Completa / Detalhada:**
  > Plataforma completa de interação em transmissões ao vivo. Este monorepo integra a API do backend desenvolvida em Laravel 13 (com banco de dados, filas e moderação) e a SPA do frontend construída em Vue 3 + Vite (com interfaces públicas de espectador, painel administrativo do streamer e overlay transparente com transições suaves para OBS).

---

## 2. Backend (`livezinha-api` / `backend`)

* **Descrição Curta (Ideal para o campo "Description" do GitHub):**
  > API RESTful em Laravel 13 para gerenciamento de transmissões, moderação de perguntas com passcodes únicos, controle de votos e suporte a filas em tempo real.

* **Descrição Completa / Detalhada:**
  > API RESTful robusta desenvolvida em Laravel 13.x e PHP 8.3+. Gerencia o controle de lives ativas, recebimento e ordenação de perguntas por voto, sistema de moderação com passcodes seguros em português (ex: `gato-azul`), e autenticação via Laravel Sanctum para o painel administrativo. Configurado com Docker Sail (MySQL) e suíte de testes em SQLite.

---

## 3. Frontend (`livezinha-web` / `frontend`)

* **Descrição Curta (Ideal para o campo "Description" do GitHub):**
  > SPA minimalista em Vue 3 + Vite com interface de envio e votação de perguntas para espectadores, painel de controle do streamer e overlay dinâmico para OBS Studio.

* **Descrição Completa / Detalhada:**
  > Interface SPA leve e de alto desempenho criada com Vue 3 (Composition API / `<script setup>`) e Vite. Conta com roteamento baseado em hash contido em um único arquivo (`App.vue`), integrando o envio público de perguntas, painel administrativo e uma visualização de overlay transparente que busca a pergunta ativa em tempo real via polling para exibição no OBS.
