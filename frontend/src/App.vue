<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'

const apiBaseUrl = 'http://192.168.15.10/api'

// View Routing State
const currentView = ref('public') // 'public' | 'admin' | 'obs'

// Shared States
const connectionStatus = ref('checking') // 'checking' | 'online' | 'offline'

// --- AUTH STATE ---
const token = ref(localStorage.getItem('auth_token') || '')
const loginForm = ref({ email: '', password: '' })
const loginError = ref('')
const isLoggingIn = ref(false)
const isAuthenticated = computed(() => !!token.value)

const authHeaders = () => {
  const headers = {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  }
  if (token.value) {
    headers['Authorization'] = `Bearer ${token.value}`
  }
  return headers
}

const login = async () => {
  loginError.value = ''
  isLoggingIn.value = true
  try {
    const response = await fetch(`${apiBaseUrl}/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'Accept': 'application/json' },
      body: JSON.stringify(loginForm.value),
    })
    if (response.ok) {
      const data = await response.json()
      token.value = data.token
      localStorage.setItem('auth_token', data.token)
      loginForm.value = { email: '', password: '' }
      navigateTo('admin')
    } else {
      const err = await response.json()
      loginError.value = err.message || err.errors?.email?.[0] || 'Erro ao fazer login.'
    }
  } catch (error) {
    loginError.value = 'Falha na conexão com o servidor.'
  } finally {
    isLoggingIn.value = false
  }
}

const logout = async () => {
  try {
    await fetch(`${apiBaseUrl}/logout`, {
      method: 'POST',
      headers: authHeaders(),
    })
  } catch (e) {
    // ignore
  }
  token.value = ''
  localStorage.removeItem('auth_token')
  navigateTo('public')
}

// --- PUBLIC VIEW STATE ---
const publicLives = ref([])
const selectedPublicLive = ref(null)
const questionForm = ref({
  name: '',
  tiktok_handle: '',
  question_text: '',
})
const generatedPasscode = ref('')
const isSubmittingQuestion = ref(false)
const submitQuestionError = ref('')
const copySuccess = ref(false)

// --- ADMIN VIEW STATE ---
const lives = ref([])
const selectedLive = ref(null)
const newLiveForm = ref({
  title: '',
  scheduled_at: '',
})
const isCreatingLive = ref(false)
const adminQuestions = ref([])
const selectedFilter = ref('all') // 'all' | 'pending' | 'approved' | 'active' | 'archived'

// --- OBS VIEW STATE ---
const activeQuestion = ref(null)
let obsIntervalId = null
let connectionIntervalId = null

// --- COMMON FUNCTIONS ---
const checkConnection = async () => {
  try {
    const response = await fetch(`${apiBaseUrl}/ping`)
    if (response.ok) {
      connectionStatus.value = 'online'
      if (currentView.value === 'public') {
        fetchPublicLives()
      }
    } else {
      connectionStatus.value = 'offline'
    }
  } catch (error) {
    console.error('Connection check failed:', error)
    connectionStatus.value = 'offline'
  }
}

// --- PUBLIC VIEW FUNCTIONS ---
const fetchPublicLives = async () => {
  try {
    const response = await fetch(`${apiBaseUrl}/lives`)
    if (response.ok) {
      const all = await response.json()
      publicLives.value = all.filter(l => l.status === 'scheduled' || l.status === 'active')
    } else {
      publicLives.value = []
    }
  } catch (error) {
    console.error('Failed to fetch lives:', error)
    publicLives.value = []
  }
}

const selectPublicLive = (live) => {
  selectedPublicLive.value = live
  fetchPublicQuestions()
}

const publicQuestions = ref([])

const fetchPublicQuestions = async () => {
  if (!selectedPublicLive.value) return
  try {
    const response = await fetch(`${apiBaseUrl}/lives/${selectedPublicLive.value.id}/questions/public`)
    if (response.ok) {
      publicQuestions.value = await response.json()
    } else {
      publicQuestions.value = []
    }
  } catch (error) {
    console.error('Failed to fetch public questions:', error)
    publicQuestions.value = []
  }
}

const submitQuestion = async () => {
  if (!selectedPublicLive.value || !questionForm.value.name.trim() || !questionForm.value.question_text.trim()) return

  isSubmittingQuestion.value = true
  submitQuestionError.value = ''

  try {
    const response = await fetch(`${apiBaseUrl}/questions`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({
        live_stream_id: selectedPublicLive.value.id,
        name: questionForm.value.name,
        tiktok_handle: questionForm.value.tiktok_handle,
        question_text: questionForm.value.question_text,
      }),
    })

    if (response.ok) {
      const data = await response.json()
      generatedPasscode.value = data.passcode
      // Reset form
      questionForm.value.name = ''
      questionForm.value.tiktok_handle = ''
      questionForm.value.question_text = ''
      fetchPublicQuestions()
    } else {
      const err = await response.json()
      submitQuestionError.value = err.message || 'Erro ao enviar pergunta.'
    }
  } catch (error) {
    console.error('Failed to submit question:', error)
    submitQuestionError.value = 'Falha na conexão com o servidor.'
  } finally {
    isSubmittingQuestion.value = false
  }
}

const copyPasscode = () => {
  navigator.clipboard.writeText(generatedPasscode.value)
  copySuccess.value = true
  setTimeout(() => {
    copySuccess.value = false
  }, 2000)
}

const resetSuccessScreen = () => {
  generatedPasscode.value = ''
  selectedPublicLive.value = null
}

// --- ADMIN VIEW FUNCTIONS ---
const fetchLives = async () => {
  try {
    const response = await fetch(`${apiBaseUrl}/lives`, { headers: authHeaders() })
    if (response.ok) {
      lives.value = await response.json()
      // Default select first live or keep current selection updated
      if (lives.value.length > 0) {
        if (!selectedLive.value) {
          selectedLive.value = lives.value[0]
        } else {
          // Sync selected live
          const updated = lives.value.find(l => l.id === selectedLive.value.id)
          if (updated) selectedLive.value = updated
        }
        fetchAdminQuestions()
      }
    }
  } catch (error) {
    console.error('Failed to fetch lives:', error)
  }
}

const selectLive = (live) => {
  selectedLive.value = live
  fetchAdminQuestions()
}

const createLive = async () => {
  if (!newLiveForm.value.title.trim() || !newLiveForm.value.scheduled_at) return
  isCreatingLive.value = true
  try {
    const response = await fetch(`${apiBaseUrl}/lives`, {
      method: 'POST',
      headers: authHeaders(),
      body: JSON.stringify({
        title: newLiveForm.value.title,
        scheduled_at: newLiveForm.value.scheduled_at.replace('T', ' '),
      }),
    })
    if (response.ok) {
      const data = await response.json()
      lives.value.unshift(data)
      selectedLive.value = data
      newLiveForm.value.title = ''
      newLiveForm.value.scheduled_at = ''
      fetchAdminQuestions()
    }
  } catch (error) {
    console.error('Failed to create live:', error)
  } finally {
    isCreatingLive.value = false
  }
}

const toggleLiveStatus = async (status) => {
  if (!selectedLive.value) return
  try {
    const response = await fetch(`${apiBaseUrl}/lives/${selectedLive.value.id}`, {
      method: 'PUT',
      headers: authHeaders(),
      body: JSON.stringify({ status }),
    })
    if (response.ok) {
      // Reload lives to refresh statuses
      fetchLives()
    }
  } catch (error) {
    console.error('Failed to update live status:', error)
  }
}

const deleteLive = async (id) => {
  if (!confirm('Tem certeza de que deseja deletar esta live? Todas as perguntas associadas também serão excluídas.')) return
  try {
    const response = await fetch(`${apiBaseUrl}/lives/${id}`, {
      method: 'DELETE',
      headers: authHeaders(),
    })
    if (response.ok) {
      lives.value = lives.value.filter(l => l.id !== id)
      if (selectedLive.value && selectedLive.value.id === id) {
        selectedLive.value = lives.value.length > 0 ? lives.value[0] : null
      }
      fetchAdminQuestions()
    }
  } catch (error) {
    console.error('Failed to delete live:', error)
  }
}

const fetchAdminQuestions = async () => {
  if (!selectedLive.value) return
  try {
    const response = await fetch(`${apiBaseUrl}/questions?live_stream_id=${selectedLive.value.id}`, { headers: authHeaders() })
    if (response.ok) {
      adminQuestions.value = await response.json()
    }
  } catch (error) {
    console.error('Failed to fetch admin questions:', error)
  }
}

const updateQuestionStatus = async (questionId, status) => {
  try {
    const response = await fetch(`${apiBaseUrl}/questions/${questionId}`, {
      method: 'PUT',
      headers: authHeaders(),
      body: JSON.stringify({ status }),
    })
    if (response.ok) {
      // Reload questions
      fetchAdminQuestions()
    }
  } catch (error) {
    console.error('Failed to update question status:', error)
  }
}

const toggleQuestionTagStatus = async (question) => {
  try {
    const response = await fetch(`${apiBaseUrl}/questions/${question.id}`, {
      method: 'PUT',
      headers: authHeaders(),
      body: JSON.stringify({ is_tagged: !question.is_tagged }),
    })
    if (response.ok) {
      fetchAdminQuestions()
    }
  } catch (error) {
    console.error('Failed to toggle question tag status:', error)
  }
}

const toggleQuestionHidden = async (question) => {
  try {
    const response = await fetch(`${apiBaseUrl}/questions/${question.id}`, {
      method: 'PUT',
      headers: authHeaders(),
      body: JSON.stringify({ is_hidden: !question.is_hidden }),
    })
    if (response.ok) {
      fetchAdminQuestions()
    }
  } catch (error) {
    console.error('Failed to toggle question hidden status:', error)
  }
}

const deleteQuestion = async (id) => {
  if (!confirm('Deseja excluir definitivamente esta pergunta?')) return
  try {
    const response = await fetch(`${apiBaseUrl}/questions/${id}`, {
      method: 'DELETE',
      headers: authHeaders(),
    })
    if (response.ok) {
      adminQuestions.value = adminQuestions.value.filter(q => q.id !== id)
    }
  } catch (error) {
    console.error('Failed to delete question:', error)
  }
}

const filteredQuestions = computed(() => {
  if (selectedFilter.value === 'all') return adminQuestions.value
  return adminQuestions.value.filter(q => q.status === selectedFilter.value)
})

// --- OBS OVERLAY FUNCTIONS ---
const fetchOBSActiveQuestion = async () => {
  try {
    const response = await fetch(`${apiBaseUrl}/lives/active/question`)
    if (response.ok) {
      const data = await response.json()
      // Direct comparison of properties to avoid flickering
      if (!data) {
        activeQuestion.value = null
      } else if (!activeQuestion.value || activeQuestion.value.id !== data.id) {
        activeQuestion.value = data
      }
    }
  } catch (error) {
    console.error('Failed to fetch active question for OBS:', error)
  }
}

// Router Setup
const initRouter = () => {
  const hash = window.location.hash
  if (hash === '#/admin') {
    currentView.value = 'admin'
    fetchLives()
  } else if (hash === '#/obs') {
    currentView.value = 'obs'
    document.body.classList.add('obs-overlay-body')
    fetchOBSActiveQuestion()
  } else {
    currentView.value = 'public'
    document.body.classList.remove('obs-overlay-body')
    selectedPublicLive.value = null
    fetchPublicLives()
  }
}

// Handle navigation updates
const navigateTo = (view) => {
  window.location.hash = `#/${view}`
  // Let hashchange listener handle view updates
}

// Format Datetime
const formatDateTime = (dtStr) => {
  const d = new Date(dtStr)
  return d.toLocaleDateString('pt-BR', {
    day: '2-digit',
    month: '2-digit',
    hour: '2-digit',
    minute: '2-digit'
  })
}

// Lifecycle Hooks
onMounted(() => {
  initRouter()
  window.addEventListener('hashchange', initRouter)

  checkConnection()
  connectionIntervalId = setInterval(checkConnection, 10000)

  // OBS view polling every 2 seconds
  obsIntervalId = setInterval(() => {
    if (currentView.value === 'obs') {
      fetchOBSActiveQuestion()
    }
  }, 2000)
})

onUnmounted(() => {
  window.removeEventListener('hashchange', initRouter)
  clearInterval(connectionIntervalId)
  clearInterval(obsIntervalId)
})
</script>

<template>
  <!-- ========================================== -->
  <!-- OBS OVERLAY VIEW (No surrounding container)-->
  <!-- ========================================== -->
  <div v-if="currentView === 'obs'" style="width: 100%; height: 100%;">
    <div v-if="activeQuestion" class="obs-card">
      <div class="obs-left-panel">
        <span class="obs-user-name">{{ activeQuestion.name }}</span>
        <span class="obs-tiktok" v-if="activeQuestion.tiktok_handle">
          <svg class="obs-tiktok-icon" viewBox="0 0 448 512">
            <path d="M448,209.91a210.06,210.06,0,0,1-122.77-39.25V349.38A162.55,162.55,0,1,1,185,188.31c8.08,0,15.79.62,23.36,1.88l.1,0H208.5v72.33l-.1,0A89.92,89.92,0,1,0,248.8,349.38V0h79.52c1.7,46.7,29.9,85.67,69.57,105.51v74.65c-20.9-9-39.6-22.9-54.8-40.4V209.91C375.4,209.91,413.4,209.91,448,209.91Z"/>
          </svg>
          {{ activeQuestion.tiktok_handle }}
        </span>
      </div>
      <div class="obs-question-text">
        {{ activeQuestion.question_text }}
      </div>
      <div class="obs-passcode-badge">
        {{ activeQuestion.passcode }}
      </div>
    </div>
  </div>

  <!-- ========================================== -->
  <!-- SPECTATOR OR ADMIN FULL APPLICATION VIEW  -->
  <!-- ========================================== -->
  <div v-else class="app-container">
    <!-- Header -->
    <header class="app-header">
      <div class="brand-section">
        <div class="logo-container">
          <!-- Vue Logo -->
          <svg class="brand-logo" viewBox="0 0 128 128" width="28" height="28">
            <path fill="#42b883" d="M78.8,10L64,35.4L49.2,10H0l64,110l64-110H78.8z"/>
            <path fill="#35495e" d="M78.8,10L64,35.4L49.2,10H25.6L64,76.5l38.4-66.5H78.8z"/>
          </svg>
          <span class="logo-divider">+</span>
          <!-- Laravel Logo -->
          <svg class="brand-logo" viewBox="0 0 128 128" width="28" height="28">
            <path fill="#ff2d20" d="M96.1,19.3L64,1.1L31.9,19.3V55.6L0,73.8v36.4L32.1,128l32.1-18.2V73.4L96.1,55.2V19.3z M64.2,9.3l21,11.9l-21,11.9l-21-11.9L64.2,9.3z M37.3,27.2l21.3,12.1v24.2L37.3,51.4V27.2z M31.9,59l21,11.9l-21,11.9l-21-11.9L31.9,59z M5.2,81l21.3,12.1v24.2L5.2,105.2V81z M64.2,118.7l-21-11.9l21-11.9l21,11.9L64.2,118.7z M90.8,47.8V23.6l-21.3,12.1v24.2L90.8,47.8z"/>
          </svg>
        </div>
        <div>
          <h1 class="brand-title">Live Q&A</h1>
          <p class="brand-subtitle">Vue.js + Laravel API</p>
        </div>
      </div>

      <!-- Navigation Badges -->
      <div class="nav-badges">
        <button 
          @click="navigateTo('public')" 
          :class="['nav-btn', { active: currentView === 'public' }]"
        >
          Enviar Pergunta
        </button>
        <button 
          @click="navigateTo('admin')" 
          :class="['nav-btn', { active: currentView === 'admin' }]"
        >
          Painel Streamer
        </button>
        <a 
          href="#/obs" 
          target="_blank" 
          class="nav-btn"
        >
          Tela OBS
        </a>
        <button 
          v-if="isAuthenticated" 
          @click="logout" 
          class="nav-btn logout-btn"
        >
          Sair
        </button>
      </div>

      <!-- Connection Status Card -->
      <div class="status-card">
        <div class="status-indicator">
          <div :class="['status-dot', connectionStatus]"></div>
        </div>
        <div class="status-info">
          <span class="status-label">API Server</span>
          <span class="status-value" v-if="connectionStatus === 'checking'">Verificando...</span>
          <span class="status-value" v-else-if="connectionStatus === 'online'">Online</span>
          <span class="status-value" v-else>Offline</span>
          <span class="live-badge" v-if="selectedPublicLive && selectedPublicLive.status === 'active' && currentView === 'public'">
            Live Ativa
          </span>
        </div>
      </div>
    </header>

    <!-- ========================================== -->
    <!-- PUBLIC SPECTATOR VIEW                     -->
    <!-- ========================================== -->
    <main v-if="currentView === 'public'">
      <!-- Success Code Screen -->
      <div v-if="generatedPasscode" class="success-card">
        <div class="success-icon">
          <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" style="width: 32px; height: 32px;">
            <path stroke-linecap="round" stroke-linejoin="round" d="M4.5 12.75l6 6 9-13.5" />
          </svg>
        </div>
        <h2 style="font-size: 1.8rem; font-weight: 800; margin-top: 0; margin-bottom: 0.5rem; color:#fff;">Pergunta Enviada!</h2>
        <p style="color: var(--text-secondary); max-width: 500px; margin: 0 auto 1.5rem;">
          Sua pergunta foi cadastrada com sucesso. Copie a sua **Palavra-Passe** abaixo e envie no chat da live para validar sua identidade!
        </p>

        <div class="passcode-container">
          <span style="font-size: 0.75rem; text-transform: uppercase; letter-spacing: 0.05em; color: var(--text-muted)">Sua Palavra-Passe</span>
          <span class="passcode-value">{{ generatedPasscode }}</span>
          <button @click="copyPasscode" class="btn-copy">
            <span v-if="copySuccess">Copiado!</span>
            <span v-else>Copiar Código</span>
            <svg v-if="!copySuccess" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" style="width: 14px; height: 14px;">
              <path stroke-linecap="round" stroke-linejoin="round" d="M15.75 17.25v3.375c0 .621-.504 1.125-1.125 1.125h-9.75a1.125 1.125h-9.75a1.125 1.125H2.25A1.125 1.125 0 011.125 19.5v-9.75c0-.621.504-1.125 1.125-1.125h9.75c.621 0 1.125.504 1.125 1.125V13.5M9 13.5h3.375c.621 0 1.125.504 1.125 1.125v9.75c0 .621-.504 1.125-1.125 1.125H9.75a1.125 1.125 0 01-1.125-1.125V15M9 13.5H5.625c-.621 0-1.125-.504-1.125-1.125v-9.75c0-.621.504-1.125 1.125-1.125h9.75c.621 0 1.125.504 1.125 1.125V9" />
            </svg>
          </button>
        </div>

        <button @click="resetSuccessScreen" class="btn-secondary" style="margin-top: 1rem;">
          Enviar outra pergunta
        </button>
      </div>

      <!-- Question Submission Form -->
      <div v-else class="dashboard-grid">
        <section class="glass-panel">
          <h2 class="panel-title">
            <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M7.5 8.25h9s0 0 0 0M7.5 12h9m-9 3.75h3m-3 3.75h12M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" />
            </svg>
            Faça sua Pergunta
          </h2>

          <!-- No lives at all -->
          <div v-if="connectionStatus === 'online' && publicLives.length === 0" class="empty-state" style="border: none; background: rgba(255,255,255,0.02); margin-bottom: 2rem;">
            <svg class="empty-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M12 6.042A8.967 8.967 0 006 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 016 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 016-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0018 18a8.967 8.967 0 00-6 2.292m0-14.25v14.25" />
            </svg>
            <h3 class="empty-title">Nenhuma Live Disponível</h3>
            <p class="empty-text">Não é possível enviar perguntas no momento. O streamer ainda não agendou ou iniciou uma live.</p>
          </div>

          <!-- Live selection list -->
          <div v-else-if="!selectedPublicLive" style="display: flex; flex-direction: column; gap: 0.75rem;">
            <p style="color: var(--text-secondary); font-size: 0.9rem; margin: 0 0 0.5rem;">Selecione a live para enviar sua pergunta:</p>
            <div
              v-for="live in publicLives"
              :key="live.id"
              class="sidebar-item"
              @click="selectPublicLive(live)"
            >
              <h4 class="sidebar-list-item-title sidebar-item-title" style="margin: 0 0 0.25rem;">{{ live.title }}</h4>
              <div class="sidebar-item-desc">
                <span>{{ formatDateTime(live.scheduled_at) }}</span>
                <span v-if="live.status === 'active'" style="color: var(--success); font-weight: 700; text-transform: uppercase; font-size:0.65rem;">Ao Vivo</span>
                <span v-else style="color: var(--primary); font-size:0.65rem;">Agendada</span>
              </div>
            </div>
          </div>

          <!-- Question form after selecting a live -->
          <div v-else>
            <div style="margin-bottom: 1.5rem; background: rgba(139,92,246,0.05); padding: 1rem; border-radius: 12px; border: 1px solid rgba(139,92,246,0.15)">
              <span style="font-size: 0.75rem; text-transform: uppercase; color: var(--primary); font-weight: 700; display: block; margin-bottom: 0.2rem;">Live Selecionada</span>
              <div style="display: flex; justify-content: space-between; align-items: center;">
                <div>
                  <span style="font-size: 1.1rem; font-weight: 800; color: #fff; display: block;">{{ selectedPublicLive.title }}</span>
                  <span style="font-size: 0.8rem; color: var(--text-secondary);">{{ formatDateTime(selectedPublicLive.scheduled_at) }}</span>
                </div>
                <button @click="selectedPublicLive = null" class="btn-secondary" style="font-size:0.75rem; padding:0.3rem 0.7rem;">Trocar</button>
              </div>
            </div>

            <form @submit.prevent="submitQuestion">
              <div class="form-group">
                <label class="form-label" for="user-name">Seu Nome / Apelido</label>
                <input 
                  v-model="questionForm.name"
                  type="text" 
                  id="user-name" 
                  class="form-input" 
                  placeholder="Ex: Carlos Silva"
                  required
                  :disabled="isSubmittingQuestion"
                />
              </div>

              <div class="form-group">
                <label class="form-label" for="tiktok-handle">TikTok Username (Opcional)</label>
                <input 
                  v-model="questionForm.tiktok_handle"
                  type="text" 
                  id="tiktok-handle" 
                  class="form-input" 
                  placeholder="Ex: @carlostiktok"
                  :disabled="isSubmittingQuestion"
                />
              </div>

              <div class="form-group">
                <label class="form-label" for="question-text">Sua Pergunta</label>
                <textarea 
                  v-model="questionForm.question_text"
                  id="question-text" 
                  class="form-textarea" 
                  placeholder="Digite a sua pergunta aqui de forma clara..."
                  required
                  maxlength="280"
                  :disabled="isSubmittingQuestion"
                ></textarea>
              </div>

              <div v-if="submitQuestionError" style="color: var(--error); font-size: 0.85rem; margin-bottom: 1rem;">
                {{ submitQuestionError }}
              </div>

              <button 
                type="submit" 
                class="btn-primary" 
                :disabled="isSubmittingQuestion || !questionForm.name.trim() || !questionForm.question_text.trim()"
              >
                <div v-if="isSubmittingQuestion" class="spinner"></div>
                <span v-else>Enviar Pergunta</span>
                <svg v-if="!isSubmittingQuestion" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2.5" stroke="currentColor" style="width:16px; height:16px;">
                  <path stroke-linecap="round" stroke-linejoin="round" d="M6 12L3.269 3.126A59.768 59.768 0 0121.485 12 59.77 59.77 0 013.27 20.876L5.999 12zm0 0h7.5" />
                </svg>
              </button>
            </form>

            <!-- Public Questions List -->
            <div v-if="publicQuestions.length > 0" style="margin-top: 1.5rem; border-top: 1px solid var(--border-card); padding-top: 1.5rem;">
              <h3 style="font-size: 1rem; font-weight: 700; color: var(--text-secondary); margin: 0 0 1rem;">
                Perguntas {{ selectedPublicLive.status === 'active' ? 'sendo exibidas' : 'selecionadas' }}
              </h3>
              <div class="questions-list">
                <div v-for="q in publicQuestions" :key="q.id" class="question-card" style="background: rgba(255,255,255,0.01);">
                  <div class="question-card-header">
                    <div class="user-info">
                      <span class="user-name">{{ q.name }}</span>
                    </div>
                  </div>
                  <p class="question-text-content">{{ q.question_text }}</p>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- Instructions Card -->
        <section class="glass-panel" style="display: flex; flex-direction: column; justify-content: center; background: radial-gradient(circle at 0% 0%, rgba(139, 92, 246, 0.08) 0%, rgba(0,0,0,0) 70%), var(--bg-card);">
          <h2 style="font-size: 1.5rem; font-weight: 800; color: #fff; margin-top: 0; margin-bottom: 1rem;">Como Funciona?</h2>
          
          <div style="display: flex; flex-direction: column; gap: 1.5rem;">
            <div style="display: flex; gap: 1rem; align-items: flex-start;">
              <span style="font-size: 1rem; font-weight: 800; background: var(--primary-gradient); color: #fff; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">1</span>
              <div>
                <h4 style="margin: 0 0 0.25rem; font-weight: 700; color: #fff;">Escreva sua Pergunta</h4>
                <p style="margin: 0; font-size: 0.85rem; color: var(--text-secondary);">Cadastre seu nome, TikTok (se tiver) e sua dúvida relevante para o streamer.</p>
              </div>
            </div>

            <div style="display: flex; gap: 1rem; align-items: flex-start;">
              <span style="font-size: 1rem; font-weight: 800; background: var(--primary-gradient); color: #fff; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">2</span>
              <div>
                <h4 style="margin: 0 0 0.25rem; font-weight: 700; color: #fff;">Gere a Palavra-Passe</h4>
                <p style="margin: 0; font-size: 0.85rem; color: var(--text-secondary);">Ao concluir o cadastro, guarde o código em português (ex: **`pipoca-doce`**) que aparece na tela.</p>
              </div>
            </div>

            <div style="display: flex; gap: 1rem; align-items: flex-start;">
              <span style="font-size: 1rem; font-weight: 800; background: var(--primary-gradient); color: #fff; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">3</span>
              <div>
                <h4 style="margin: 0 0 0.25rem; font-weight: 700; color: #fff;">Valide no Chat da Live</h4>
                <p style="margin: 0; font-size: 0.85rem; color: var(--text-secondary);">Quando o streamer chamar sua pergunta, digite a Palavra-Passe no chat. Assim provamos que você está assistindo!</p>
              </div>
            </div>

            <div style="display: flex; gap: 1rem; align-items: flex-start;">
              <span style="font-size: 1rem; font-weight: 800; background: var(--accent-gradient); color: #fff; width: 28px; height: 28px; border-radius: 50%; display: flex; align-items: center; justify-content: center; flex-shrink: 0;">🎬</span>
              <div>
                <h4 style="margin: 0 0 0.25rem; font-weight: 700; color: #fff;">Cortes & Destaques</h4>
                <p style="margin: 0; font-size: 0.85rem; color: var(--text-secondary);">Deixando seu TikTok, o streamer poderá fazer um corte da resposta e marcar seu perfil oficial na rede social!</p>
              </div>
            </div>
          </div>
        </section>
      </div>
    </main>

    <!-- ========================================== -->
    <!-- LOGIN VIEW                               -->
    <!-- ========================================== -->
    <main v-if="currentView === 'admin' && !isAuthenticated" class="login-container">
      <section class="glass-panel login-card">
        <div class="login-header">
          <svg class="brand-logo" viewBox="0 0 128 128" width="40" height="40">
            <path fill="#ff2d20" d="M96.1,19.3L64,1.1L31.9,19.3V55.6L0,73.8v36.4L32.1,128l32.1-18.2V73.4L96.1,55.2V19.3z M64.2,9.3l21,11.9l-21,11.9l-21-11.9L64.2,9.3z M37.3,27.2l21.3,12.1v24.2L37.3,51.4V27.2z M31.9,59l21,11.9l-21,11.9l-21-11.9L31.9,59z M5.2,81l21.3,12.1v24.2L5.2,105.2V81z M64.2,118.7l-21-11.9l21-11.9l21,11.9L64.2,118.7z M90.8,47.8V23.6l-21.3,12.1v24.2L90.8,47.8z"/>
          </svg>
          <h2>Acesso do Streamer</h2>
          <p>Faça login para gerenciar lives e perguntas.</p>
        </div>
        <form @submit.prevent="login">
          <div class="form-group">
            <label class="form-label" for="login-email">E-mail</label>
            <input
              v-model="loginForm.email"
              type="email"
              id="login-email"
              class="form-input"
              placeholder="seu@email.com"
              required
              :disabled="isLoggingIn"
            />
          </div>
          <div class="form-group">
            <label class="form-label" for="login-password">Senha</label>
            <input
              v-model="loginForm.password"
              type="password"
              id="login-password"
              class="form-input"
              placeholder="••••••"
              required
              :disabled="isLoggingIn"
            />
          </div>
          <div v-if="loginError" class="login-error">{{ loginError }}</div>
          <button type="submit" class="btn-primary login-btn" :disabled="isLoggingIn">
            <div v-if="isLoggingIn" class="spinner"></div>
            <span v-else>Entrar</span>
          </button>
        </form>
      </section>
    </main>

    <!-- ========================================== -->
    <!-- STREAMER ADMIN VIEW                       -->
    <!-- ========================================== -->
    <main v-if="currentView === 'admin' && isAuthenticated" class="admin-grid">
      <!-- Admin Sidebar (Lives management) -->
      <aside class="glass-panel" style="padding: 1.5rem;">
        <h3 style="font-size: 1.15rem; font-weight: 800; margin-top: 0; margin-bottom: 1.25rem; color:#fff;">Agendar Nova Live</h3>
        <form @submit.prevent="createLive" style="margin-bottom: 2rem; border-bottom: 1px solid var(--border-card); padding-bottom: 1.5rem;">
          <div class="form-group">
            <label class="form-label" style="font-size: 0.75rem;">Título da Live</label>
            <input 
              v-model="newLiveForm.title"
              type="text" 
              class="form-input" 
              placeholder="Ex: Live de Sexta" 
              required
            />
          </div>
          <div class="form-group">
            <label class="form-label" style="font-size: 0.75rem;">Data e Hora</label>
            <input 
              v-model="newLiveForm.scheduled_at"
              type="datetime-local" 
              class="form-input" 
              required
            />
          </div>
          <button type="submit" class="btn-primary" style="padding: 0.7rem 1.2rem; font-size:0.85rem;" :disabled="isCreatingLive">
            <span v-if="isCreatingLive">Criando...</span>
            <span v-else>Agendar Live</span>
          </button>
        </form>

        <h3 style="font-size: 1.15rem; font-weight: 800; margin-top: 0; margin-bottom: 1rem; color:#fff;">Suas Lives</h3>
        <div class="sidebar-list">
          <div 
            v-for="live in lives" 
            :key="live.id"
            :class="['sidebar-item', { active: selectedLive && selectedLive.id === live.id }]"
            @click="selectLive(live)"
          >
            <h4 class="sidebar-list-item-title sidebar-item-title">{{ live.title }}</h4>
            <div class="sidebar-item-desc">
              <span>{{ formatDateTime(live.scheduled_at) }}</span>
              <span v-if="live.status === 'active'" style="color: var(--success); font-weight: 700; text-transform: uppercase; font-size:0.65rem;">Ativa</span>
              <span v-else-if="live.status === 'finished'" style="color: var(--text-muted); font-size:0.65rem;">Finalizada</span>
              <span v-else style="color: var(--primary); font-size:0.65rem;">Agendada</span>
            </div>
          </div>
          <div v-if="lives.length === 0" style="color: var(--text-muted); text-align: center; font-size:0.85rem; padding: 2rem 0;">
            Nenhuma live agendada.
          </div>
        </div>
      </aside>

      <!-- Main Moderation Panel -->
      <section class="glass-panel">
        <!-- Live Selected Header -->
        <div v-if="selectedLive" style="border-bottom: 1px solid var(--border-card); padding-bottom: 1.5rem; margin-bottom: 1.5rem;">
          <div style="display: flex; justify-content: space-between; align-items: flex-start; flex-wrap: wrap; gap: 1rem;">
            <div>
              <span style="font-size: 0.75rem; text-transform: uppercase; color: var(--text-muted); font-weight: 700; letter-spacing: 0.05em;">Live Selecionada</span>
              <h2 style="font-size: 1.6rem; font-weight: 800; color: #fff; margin: 0.15rem 0;">{{ selectedLive.title }}</h2>
              <p style="margin: 0; font-size: 0.85rem; color: var(--text-secondary);">Agendada: {{ formatDateTime(selectedLive.scheduled_at) }}</p>
            </div>
            
            <div style="display: flex; gap: 0.5rem;">
              <button 
                v-if="selectedLive.status !== 'active'" 
                @click="toggleLiveStatus('active')"
                class="btn-secondary" 
                style="border-color: var(--success); color: var(--success); background: rgba(16, 185, 129, 0.05);"
              >
                🔴 Iniciar Live
              </button>
              <button 
                v-if="selectedLive.status === 'active'" 
                @click="toggleLiveStatus('finished')"
                class="btn-secondary" 
                style="border-color: var(--text-muted); color: var(--text-secondary);"
              >
                ⏹️ Encerrar Live
              </button>
              <button 
                @click="deleteLive(selectedLive.id)"
                class="btn-secondary" 
                style="border-color: var(--error); color: var(--error); background: rgba(239, 68, 68, 0.05);"
              >
                Excluir
              </button>
            </div>
          </div>
        </div>

        <!-- Filter Bar -->
        <div v-if="selectedLive" class="filter-bar">
          <button @click="selectedFilter = 'all'" :class="['filter-btn', { active: selectedFilter === 'all' }]">
            Todas ({{ adminQuestions.length }})
          </button>
          <button @click="selectedFilter = 'pending'" :class="['filter-btn pending', { active: selectedFilter === 'pending' }]">
            Pendentes ({{ adminQuestions.filter(q => q.status === 'pending').length }})
          </button>
          <button @click="selectedFilter = 'approved'" :class="['filter-btn approved', { active: selectedFilter === 'approved' }]">
            Aprovadas ({{ adminQuestions.filter(q => q.status === 'approved').length }})
          </button>
          <button @click="selectedFilter = 'active'" :class="['filter-btn active', { active: selectedFilter === 'active' }]">
            Na Tela ({{ adminQuestions.filter(q => q.status === 'active').length }})
          </button>
          <button @click="selectedFilter = 'archived'" :class="['filter-btn archived', { active: selectedFilter === 'archived' }]">
            Respondidas ({{ adminQuestions.filter(q => q.status === 'archived').length }})
          </button>
        </div>

        <!-- Admin Questions List -->
        <div v-if="selectedLive">
          <div v-if="filteredQuestions.length > 0" class="questions-list">
            <div 
              v-for="q in filteredQuestions" 
              :key="q.id" 
              :class="['question-card', q.status]"
            >
              <div class="question-card-header">
                <div class="user-info">
                  <span class="user-name">
                    {{ q.name }}
                    <a 
                      v-if="q.tiktok_handle" 
                      :href="'https://www.tiktok.com/' + q.tiktok_handle" 
                      target="_blank" 
                      class="tiktok-badge"
                    >
                      <svg viewBox="0 0 448 512">
                        <path d="M448,209.91a210.06,210.06,0,0,1-122.77-39.25V349.38A162.55,162.55,0,1,1,185,188.31c8.08,0,15.79.62,23.36,1.88l.1,0H208.5v72.33l-.1,0A89.92,89.92,0,1,0,248.8,349.38V0h79.52c1.7,46.7,29.9,85.67,69.57,105.51v74.65c-20.9-9-39.6-22.9-54.8-40.4V209.91C375.4,209.91,413.4,209.91,448,209.91Z"/>
                      </svg>
                      {{ q.tiktok_handle }}
                    </a>
                  </span>
                </div>
                <div class="question-passcode">
                  Palavra-Passe: <strong>{{ q.passcode }}</strong>
                </div>
              </div>

              <p class="question-text-content">{{ q.question_text }}</p>

              <div class="question-actions">
                <!-- Action buttons -->
                <div class="action-buttons">
                  <button 
                    v-if="q.status === 'pending'" 
                    @click="updateQuestionStatus(q.id, 'approved')"
                    class="action-btn-small approve"
                  >
                    Aprovar
                  </button>
                  <button 
                    v-if="q.status === 'approved' || q.status === 'pending'" 
                    @click="updateQuestionStatus(q.id, 'active')"
                    class="action-btn-small screen"
                  >
                    Exibir na Tela (OBS)
                  </button>
                  <button 
                    v-if="q.status === 'active'" 
                    @click="updateQuestionStatus(q.id, 'archived')"
                    class="action-btn-small archive"
                  >
                    Marcar como Respondida
                  </button>
                  <button 
                    v-if="q.status !== 'archived' && q.status !== 'pending'"
                    @click="updateQuestionStatus(q.id, 'archived')"
                    class="action-btn-small archive"
                  >
                    Arquivar
                  </button>
                  <button 
                    v-if="q.status === 'archived'" 
                    @click="updateQuestionStatus(q.id, 'approved')"
                    class="action-btn-small approve"
                  >
                    Desarquivar
                  </button>
                  <button 
                    @click="deleteQuestion(q.id)"
                    class="btn-delete"
                    style="padding: 0.35rem 0.5rem;"
                    title="Excluir Pergunta"
                  >
                    <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="2" stroke="currentColor" style="width: 14px; height: 14px;">
                      <path stroke-linecap="round" stroke-linejoin="round" d="M14.74 9l-.346 9m-4.788 0L9.26 9m9.968-3.21c.342.052.682.107 1.022.166m-1.022-.165L18.16 19.673a2.25 2.25 0 01-2.244 2.077H8.084a2.25 2.25 0 01-2.244-2.077L4.772 5.79m14.456 0a48.108 48.108 0 00-3.478-.397m-12 .562c.34-.059.68-.114 1.022-.165m0 0a48.11 48.11 0 013.478-.397m7.5 0v-.916c0-1.18-.91-2.164-2.09-2.201a51.964 51.964 0 00-3.32 0c-1.18.037-2.09 1.022-2.09 2.201v.916m7.5 0a48.667 48.667 0 00-7.5 0" />
                    </svg>
                  </button>
                  <button
                    @click="toggleQuestionHidden(q)"
                    :class="['action-btn-small', q.is_hidden ? 'approve' : 'archive']"
                    :title="q.is_hidden ? 'Mostrar ao público' : 'Ocultar do público'"
                  >
                    {{ q.is_hidden ? 'Mostrar' : 'Ocultar' }}
                  </button>
                </div>

                <!-- TikTok clip toggle -->
                <div 
                  v-if="q.tiktok_handle"
                  @click="toggleQuestionTagStatus(q)"
                  :class="['switch-container', { active: q.is_tagged }]"
                  title="Marque quando criar o corte e marcar a pessoa no TikTok"
                >
                  <span>Corte Criado / Marcado</span>
                  <div class="switch-track">
                    <div class="switch-thumb"></div>
                  </div>
                </div>
              </div>
            </div>
          </div>

          <div v-else class="empty-state">
            <svg class="empty-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
              <path stroke-linecap="round" stroke-linejoin="round" d="M9.879 7.519c1.171-1.025 3.071-1.025 4.242 0 1.172 1.025 1.172 2.687 0 3.712-.203.179-.43.326-.67.442-.745.361-1.45.999-1.45 1.827v.75M21 12a9 9 0 11-18 0 9 9 0 0118 0zm-9 5.25h.008v.008H12v-.008z" />
            </svg>
            <h3 class="empty-title">Nenhuma Pergunta</h3>
            <p class="empty-text">Nenhuma pergunta encontrada com este filtro para esta live.</p>
          </div>
        </div>

        <div v-else class="empty-state" style="padding: 5rem 2rem;">
          <svg class="empty-icon" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
          </svg>
          <h3 class="empty-title">Nenhuma Live Selecionada</h3>
          <p class="empty-text">Selecione ou crie uma live na barra lateral esquerda para gerenciar as perguntas.</p>
        </div>
      </section>
    </main>
  </div>
</template>
