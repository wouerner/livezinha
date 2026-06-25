<script setup>
import { ref, onMounted, onUnmounted, computed } from 'vue'
import DatePicker from './components/DatePicker.vue'

const apiBaseUrl = import.meta.env.VITE_API_BASE_URL || 'http://localhost/api'

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
  streamer_name: '',
  live_url: '',
  scheduled_at: '',
})
const isCreatingLive = ref(false)
const adminQuestions = ref([])
const selectedFilter = ref('all') // 'all' | 'pending' | 'approved' | 'active' | 'archived'

// --- OBS VIEW STATE ---
const activeQuestions = ref([])
let obsIntervalId = null
let connectionIntervalId = null
const becameOlderMap = {}

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

// --- VOTE STATE ---
const userVotes = ref(JSON.parse(localStorage.getItem('user_votes') || '{}'))
const isVotingQuestion = ref(null) // question id being voted on

const getUserVote = (questionId) => {
  return userVotes.value[questionId] || null
}

const persistUserVotes = () => {
  localStorage.setItem('user_votes', JSON.stringify(userVotes.value))
}

const voteQuestion = async (questionId, voteType) => {
  isVotingQuestion.value = questionId
  try {
    const response = await fetch(`${apiBaseUrl}/questions/${questionId}/vote`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: JSON.stringify({ vote: voteType }),
    })
    if (response.ok) {
      const data = await response.json()
      // Update counts in all question lists
      const updateCounts = (q) => {
        if (q.id === questionId) {
          q.likes_count = data.likes_count
          q.dislikes_count = data.dislikes_count
        }
        return q
      }
      publicQuestions.value = publicQuestions.value.map(updateCounts)
      adminQuestions.value = adminQuestions.value.map(updateCounts)
      activeQuestions.value = activeQuestions.value.map(updateCounts)

      // Update user vote state
      const currentVote = userVotes.value[questionId]
      if (currentVote === voteType) {
        delete userVotes.value[questionId]
      } else {
        userVotes.value[questionId] = voteType
      }
      persistUserVotes()
    }
  } catch (error) {
    console.error('Failed to vote:', error)
  } finally {
    isVotingQuestion.value = null
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

const shareLive = async (live) => {
  const shareUrl = window.location.origin + '/#/public'
  const shareTitle = `📺 ${live.title}`
  const shareText = live.live_url
    ? `Assista à live "${live.title}"${live.streamer_name ? ' com ' + live.streamer_name : ''}!\n\n📡 Link da transmissão: ${live.live_url}\n\n💬 Envie sua pergunta: ${shareUrl}`
    : `Participe da live "${live.title}"${live.streamer_name ? ' com ' + live.streamer_name : ''}!\n\n💬 Envie sua pergunta: ${shareUrl}`

  if (navigator.share) {
    try {
      await navigator.share({ title: shareTitle, text: shareText, url: shareUrl })
    } catch { /* user cancelled */ }
  } else {
    await navigator.clipboard.writeText(shareText)
    copySuccess.value = true
    setTimeout(() => { copySuccess.value = false }, 2000)
  }
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
        streamer_name: newLiveForm.value.streamer_name || null,
        live_url: newLiveForm.value.live_url || null,
        scheduled_at: newLiveForm.value.scheduled_at,
      }),
    })
    if (response.ok) {
      const data = await response.json()
      lives.value.unshift(data)
      selectedLive.value = data
      newLiveForm.value.title = ''
      newLiveForm.value.streamer_name = ''
      newLiveForm.value.live_url = ''
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

const updateLive = async (id, data) => {
  try {
    const response = await fetch(`${apiBaseUrl}/lives/${id}`, {
      method: 'PUT',
      headers: authHeaders(),
      body: JSON.stringify(data),
    })
    if (response.ok) {
      fetchLives()
    }
  } catch (error) {
    console.error('Failed to update live:', error)
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
const hideOBSQuestion = async (questionId) => {
  try {
    await fetch(`${apiBaseUrl}/questions/${questionId}`, {
      method: 'PUT',
      headers: authHeaders(),
      body: JSON.stringify({ is_hidden: true }),
    })
  } catch (error) {
    console.error('Failed to auto-hide OBS question:', error)
  }
}

const fetchOBSActiveQuestion = async () => {
  try {
    const response = await fetch(`${apiBaseUrl}/lives/active/question`)
    if (response.ok) {
      const data = await response.json()
      const currentStr = JSON.stringify(activeQuestions.value)
      const newStr = JSON.stringify(data || [])
      if (currentStr !== newStr) {
        activeQuestions.value = data || []
      }

      // Track "other" (older) questions and their timers
      if (activeQuestions.value.length > 1) {
        const newestId = activeQuestions.value[activeQuestions.value.length - 1].id
        activeQuestions.value.forEach((q) => {
          if (q.id !== newestId) {
            // This is an older question. Mark when it became older if not already tracked.
            if (!becameOlderMap[q.id]) {
              becameOlderMap[q.id] = Date.now()
            }
          } else {
            // Newest question is not older
            delete becameOlderMap[q.id]
          }
        })
      } else {
        // Clear all timers since there are no older questions active
        Object.keys(becameOlderMap).forEach(key => delete becameOlderMap[key])
      }

      // Clean up IDs that are no longer in the active list
      const activeIds = new Set(activeQuestions.value.map(q => q.id))
      Object.keys(becameOlderMap).forEach(idStr => {
        const id = Number(idStr)
        if (!activeIds.has(id)) {
          delete becameOlderMap[idStr]
        }
      })

      // Check if any older question has exceeded 15 seconds
      const now = Date.now()
      for (const [idStr, becameOlderAt] of Object.entries(becameOlderMap)) {
        if (now - becameOlderAt >= 15000) {
          const id = Number(idStr)
          hideOBSQuestion(id)
          delete becameOlderMap[idStr]
        }
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
 
// Format Relative Time to Live Stream Start
const formatRelativeTime = (timeStr, baseTimeStr) => {
  if (!timeStr || !baseTimeStr) return null
  const time = new Date(timeStr)
  const base = new Date(baseTimeStr)
  const diffMs = time - base
  if (diffMs < 0) return '00:00'
  
  const totalSeconds = Math.floor(diffMs / 1000)
  const hours = Math.floor(totalSeconds / 3600)
  const minutes = Math.floor((totalSeconds % 3600) / 60)
  const seconds = totalSeconds % 60
  
  const pad = (num) => String(num).padStart(2, '0')
  
  if (hours > 0) {
    return `${pad(hours)}:${pad(minutes)}:${pad(seconds)}`
  }
  return `${pad(minutes)}:${pad(seconds)}`
}
 
const formatDuration = (seconds) => {
  if (seconds === null || seconds === undefined) return null
  const mins = Math.floor(seconds / 60)
  const secs = seconds % 60
  return `${mins}m ${secs}s`
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
  <div v-if="currentView === 'obs'" class="obs-container">
    <TransitionGroup name="obs-list" tag="div" class="obs-container-inner">
      <div 
        v-for="(q, index) in activeQuestions" 
        :key="q.id" 
        :class="['obs-card', { 'is-newest': index === activeQuestions.length - 1 }]"
      >
        <!-- Loading timer bar for older messages -->
        <div v-if="index !== activeQuestions.length - 1" class="obs-card-timer"></div>

        <div class="obs-left-panel">
          <span class="obs-user-name">{{ q.name }}</span>
          <span class="obs-tiktok" v-if="q.tiktok_handle">
            <svg class="obs-tiktok-icon" viewBox="0 0 448 512">
              <path d="M448,209.91a210.06,210.06,0,0,1-122.77-39.25V349.38A162.55,162.55,0,1,1,185,188.31c8.08,0,15.79.62,23.36,1.88l.1,0H208.5v72.33l-.1,0A89.92,89.92,0,1,0,248.8,349.38V0h79.52c1.7,46.7,29.9,85.67,69.57,105.51v74.65c-20.9-9-39.6-22.9-54.8-40.4V209.91C375.4,209.91,413.4,209.91,448,209.91Z"/>
            </svg>
            {{ q.tiktok_handle }}
          </span>
        </div>
        <div class="obs-question-text">
          {{ q.question_text }}
        </div>
        <div class="obs-stats">
          <span class="obs-stat">
            <svg class="obs-stat-icon" viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M23,10C23,8.89 22.1,8 21,8H14.68L15.64,3.43C15.66,3.33 15.67,3.22 15.67,3.11C15.67,2.7 15.5,2.32 15.23,2.05L14.17,1L7.59,7.58C7.22,7.95 7,8.45 7,9V19A2,2 0 0,0 9,21H18C18.83,21 19.54,20.5 19.84,19.78L22.86,12.73C22.95,12.5 23,12.26 23,12V10M1,21H5V9H1V21Z"/></svg>
            <span>{{ q.likes_count ?? 0 }}</span>
          </span>
          <span class="obs-stat">
            <svg class="obs-stat-icon" viewBox="0 0 24 24" width="14" height="14" fill="currentColor"><path d="M19,15H23V3H19M15,3H6C5.17,3 4.46,3.5 4.16,4.22L1.14,11.27C1.05,11.5 1,11.74 1,12V14A2,2 0 0,0 3,16H9.31L8.36,20.57C8.34,20.67 8.33,20.77 8.33,20.88C8.33,21.3 8.5,21.67 8.77,21.94L9.83,23L16.41,16.42C16.78,16.05 17,15.55 17,15V5A2,2 0 0,0 15,3Z"/></svg>
            <span>{{ q.dislikes_count ?? 0 }}</span>
          </span>
        </div>
        <div class="obs-passcode-badge">
          {{ q.passcode }}
        </div>
      </div>
    </TransitionGroup>
  </div>

  <!-- ========================================== -->
  <!-- SPECTATOR OR ADMIN FULL APPLICATION VIEW  -->
  <!-- ========================================== -->
  <v-app v-else class="app-background">
    <!-- Floating Glass Glow Background Bubbles -->
    <div class="glass-bg-glows">
      <div class="glow-bubble bubble-1"></div>
      <div class="glow-bubble bubble-2"></div>
    </div>

    <v-main class="app-main-content">
      <v-container class="app-container">
        <!-- Header -->
        <v-card class="glass-panel pa-4 mb-6" variant="flat">
          <div class="d-flex flex-wrap justify-space-between align-center" style="gap: 1.5rem;">
            <div class="d-flex align-center" style="gap: 1rem;">
              <v-icon color="primary" size="36">mdi-broadcast</v-icon>
              <div>
                <h1 class="brand-title text-h6 font-weight-bold text-white mb-0" style="line-height: 1.2;">livezinha</h1>
                <p class="brand-subtitle text-caption text-grey-lighten-1 mb-0">Faça suas perguntas!</p>
              </div>
            </div>

            <!-- Connection Status and Admin Subtle Access -->
            <div class="d-flex align-center flex-wrap" style="gap: 0.75rem;">
              <!-- Subtle Admin Menu / Actions -->
              <div v-if="currentView === 'admin'" class="d-flex align-center" style="gap: 0.5rem;">
                <v-btn 
                  @click="navigateTo('public')" 
                  color="grey-lighten-3"
                  variant="outlined"
                  size="small"
                  prepend-icon="mdi-arrow-left"
                >
                  Voltar
                </v-btn>
                <v-btn 
                  href="#/obs" 
                  target="_blank" 
                  color="grey-lighten-3"
                  variant="outlined"
                  size="small"
                  icon="mdi-television-play"
                  style="width: 28px; height: 28px;"
                  title="Tela OBS"
                ></v-btn>
                <v-btn 
                  v-if="isAuthenticated" 
                  @click="logout" 
                  color="error"
                  variant="outlined"
                  size="small"
                  icon="mdi-logout"
                  style="width: 28px; height: 28px;"
                  title="Sair"
                ></v-btn>
              </div>
              <div v-else class="d-flex align-center">
                <v-btn
                  v-if="isAuthenticated"
                  @click="navigateTo('admin')"
                  color="primary"
                  variant="flat"
                  size="small"
                  prepend-icon="mdi-shield-crown-outline"
                >
                  Painel Admin
                </v-btn>
                <v-btn
                  v-else
                  @click="navigateTo('admin')"
                  icon="mdi-lock-outline"
                  variant="text"
                  color="grey-darken-1"
                  style="width: 28px; height: 28px;"
                  title="Acesso do Streamer"
                ></v-btn>
              </div>
            </div>
          </div>
        </v-card>

        <!-- ========================================== -->
        <!-- PUBLIC SPECTATOR VIEW                     -->
        <!-- ========================================== -->
        <div v-if="currentView === 'public'">
          <!-- Success Code Screen -->
          <v-card v-if="generatedPasscode" class="mx-auto text-center pa-6 glass-panel" max-width="600">
            <v-avatar color="success" size="64" class="mb-4">
              <v-icon size="36" color="white">mdi-check</v-icon>
            </v-avatar>
            <h2 class="text-h5 font-weight-bold mb-2 text-white">Pergunta Enviada!</h2>
            <p class="text-body-2 text-grey-lighten-1 mb-6">
              Sua pergunta foi cadastrada com sucesso. Copie a sua <strong>Palavra-Passe</strong> abaixo e envie no chat da live para validar sua identidade!
            </p>

            <v-card variant="outlined" color="primary" class="pa-4 mb-6 rounded-lg bg-black-opacity" style="border-style: dashed;">
              <span class="text-caption text-uppercase text-grey-lighten-1 d-block mb-1">Sua Palavra-Passe</span>
              <span class="text-h4 font-weight-bold text-white d-block py-2" style="letter-spacing: 0.05em;">{{ generatedPasscode }}</span>
              <v-btn
                @click="copyPasscode"
                color="primary"
                class="mt-2"
                size="small"
                :prepend-icon="copySuccess ? 'mdi-check' : 'mdi-content-copy'"
              >
                {{ copySuccess ? 'Copiado!' : 'Copiar Código' }}
              </v-btn>
            </v-card>

            <v-btn @click="resetSuccessScreen" variant="text" color="grey-lighten-1">
              Enviar outra pergunta
            </v-btn>
          </v-card>

          <!-- Question Submission Form -->
          <v-row v-else>
            <v-col cols="12" md="7">
              <v-card class="glass-panel pa-6 home-form-card">
                <v-card-title class="d-flex align-center px-0 pb-4 text-white">
                  <v-icon color="primary" class="mr-2">mdi-message-text-outline</v-icon>
                  Faça sua Pergunta
                </v-card-title>

                <!-- No lives at all -->
                <v-card
                  v-if="connectionStatus === 'online' && publicLives.length === 0"
                  class="text-center pa-6 bg-transparent"
                  variant="flat"
                >
                  <v-icon size="48" color="grey-lighten-1" class="mb-3">mdi-video-off-outline</v-icon>
                  <h3 class="text-h6 text-white mb-1">Nenhuma Live Disponível</h3>
                  <p class="text-body-2 text-grey-lighten-1">
                    Não é possível enviar perguntas no momento. O streamer ainda não agendou ou iniciou uma live.
                  </p>
                </v-card>

                <!-- Live selection list -->
                <div v-else-if="!selectedPublicLive">
                  <p class="text-body-2 text-grey-lighten-1 mb-3">Selecione a live para enviar sua pergunta:</p>
                  <v-list class="bg-transparent pa-0">
                    <v-list-item
                      v-for="live in publicLives"
                      :key="live.id"
                      class="glass-panel mb-2"
                      @click="selectPublicLive(live)"
                      link
                      style="border: 1px solid rgba(255,255,255,0.05);"
                    >
                      <v-list-item-title class="text-white font-weight-bold">
                        {{ live.title }}
                        <span v-if="live.streamer_name" class="text-caption text-grey-lighten-2 font-weight-regular ml-2">por {{ live.streamer_name }}</span>
                      </v-list-item-title>
                      <v-list-item-subtitle class="text-grey-lighten-1">
                        {{ formatDateTime(live.scheduled_at) }}
                      </v-list-item-subtitle>
                      <template v-slot:append>
                        <div class="d-flex align-center" style="gap: 0.25rem;">
                          <v-btn
                            v-if="live.live_url"
                            :href="live.live_url"
                            target="_blank"
                            size="x-small"
                            icon="mdi-open-in-new"
                            variant="text"
                            color="grey-lighten-1"
                            title="Abrir transmissão"
                          ></v-btn>
                          <v-chip
                            size="small"
                            :color="live.status === 'active' ? 'error' : 'primary'"
                            variant="flat"
                          >
                            {{ live.status === 'active' ? 'Ao Vivo' : 'Agendada' }}
                          </v-chip>
                        </div>
                      </template>
                    </v-list-item>
                  </v-list>
                </div>

                <!-- Question form after selecting a live -->
                <div v-else>
                  <v-alert
                    color="primary"
                    variant="tonal"
                    class="mb-4 pa-4 rounded-lg"
                    border="start"
                  >
                    <div class="d-flex justify-space-between align-center">
                      <div>
                        <span class="text-caption text-uppercase text-grey-lighten-1 d-block font-weight-bold">Live Selecionada</span>
                        <span class="text-subtitle-1 text-white font-weight-bold d-block">{{ selectedPublicLive.title }}</span>
                        <span class="text-caption text-grey-lighten-2">
                          {{ formatDateTime(selectedPublicLive.scheduled_at) }}
                          <template v-if="selectedPublicLive.streamer_name"> · por {{ selectedPublicLive.streamer_name }}</template>
                        </span>
                      </div>
                      <div class="d-flex" style="gap: 0.5rem;">
                        <v-btn
                          size="small"
                          variant="outlined"
                          color="white"
                          prepend-icon="mdi-share-variant"
                          @click="shareLive(selectedPublicLive)"
                        >
                          Compartilhar
                        </v-btn>
                        <v-btn size="small" variant="outlined" color="white" @click="selectedPublicLive = null">
                          Trocar
                        </v-btn>
                      </div>
                    </div>
                  </v-alert>

                  <v-form @submit.prevent="submitQuestion">
                    <v-text-field
                      v-model="questionForm.name"
                      label="Seu Nome / Apelido"
                      placeholder="Ex: Carlos Silva"
                      variant="outlined"
                      required
                      :disabled="isSubmittingQuestion"
                      class="mb-2"
                      density="comfortable"
                    ></v-text-field>

                    <v-text-field
                      v-model="questionForm.tiktok_handle"
                      label="TikTok Username (Opcional)"
                      placeholder="Ex: @carlostiktok"
                      variant="outlined"
                      :disabled="isSubmittingQuestion"
                      class="mb-2"
                      density="comfortable"
                      prepend-inner-icon="mdi-music-note"
                    ></v-text-field>

                    <v-textarea
                      v-model="questionForm.question_text"
                      label="Sua Pergunta"
                      placeholder="Digite a sua pergunta aqui de forma clara..."
                      variant="outlined"
                      required
                      maxlength="280"
                      counter
                      rows="3"
                      :disabled="isSubmittingQuestion"
                      class="mb-2"
                      density="comfortable"
                    ></v-textarea>

                    <div v-if="submitQuestionError" class="text-error text-caption mb-3">
                      {{ submitQuestionError }}
                    </div>

                    <v-btn
                      type="submit"
                      color="primary"
                      block
                      size="large"
                      :loading="isSubmittingQuestion"
                      :disabled="!questionForm.name.trim() || !questionForm.question_text.trim()"
                      append-icon="mdi-send"
                    >
                      Enviar Pergunta
                    </v-btn>
                  </v-form>

                  <!-- Public Questions List -->
                  <div v-if="publicQuestions.length > 0" class="mt-6">
                    <h3 class="text-subtitle-2 font-weight-bold text-grey-lighten-1 mb-3">
                      Perguntas {{ selectedPublicLive.status === 'active' ? 'sendo exibidas' : 'selecionadas' }}
                    </h3>
                    <div class="d-flex flex-column" style="gap: 0.5rem;">
                      <v-card
                        v-for="q in publicQuestions"
                        :key="q.id"
                        class="pa-4 rounded-lg bg-black-opacity"
                        variant="outlined"
                        style="border-color: rgba(255,255,255,0.05);"
                      >
                        <div class="d-flex align-center mb-1">
                          <span class="text-subtitle-2 font-weight-bold text-white">{{ q.name }}</span>
                        </div>
                        <p class="text-body-2 text-grey-lighten-2 mb-2">{{ q.question_text }}</p>
                        <div class="d-flex align-center" style="gap: 0.75rem;">
                          <v-btn
                            size="x-small"
                            :color="getUserVote(q.id) === 'like' ? 'success' : 'grey-darken-1'"
                            variant="text"
                            :loading="isVotingQuestion === q.id"
                            :disabled="isVotingQuestion !== null"
                            @click="voteQuestion(q.id, 'like')"
                            class="pa-1"
                            style="min-width: 0;"
                          >
                            <v-icon size="small" class="mr-1">mdi-thumb-up</v-icon>
                            <span class="text-caption">{{ q.likes_count ?? 0 }}</span>
                          </v-btn>
                          <v-btn
                            size="x-small"
                            :color="getUserVote(q.id) === 'dislike' ? 'error' : 'grey-darken-1'"
                            variant="text"
                            :loading="isVotingQuestion === q.id"
                            :disabled="isVotingQuestion !== null"
                            @click="voteQuestion(q.id, 'dislike')"
                            class="pa-1"
                            style="min-width: 0;"
                          >
                            <v-icon size="small" class="mr-1">mdi-thumb-down</v-icon>
                            <span class="text-caption">{{ q.dislikes_count ?? 0 }}</span>
                          </v-btn>
                        </div>
                      </v-card>
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>

            <!-- Instructions Column -->
            <v-col cols="12" md="5">
              <v-card class="glass-panel pa-6 d-flex flex-column justify-center fill-height" style="background: radial-gradient(circle at 0% 0%, rgba(139, 92, 246, 0.08) 0%, rgba(0,0,0,0) 70%), rgba(15, 17, 28, 0.7);">
                <h2 class="text-h5 font-weight-bold text-white mb-4">Como Funciona?</h2>
                
                <div class="d-flex flex-column" style="gap: 1.5rem;">
                  <div class="d-flex align-start">
                    <v-avatar color="primary" size="32" class="mr-3 text-white font-weight-bold">1</v-avatar>
                    <div>
                      <h4 class="text-subtitle-2 font-weight-bold text-white">Escreva sua Pergunta</h4>
                      <p class="text-caption text-grey-lighten-1 mb-0">Cadastre seu nome, TikTok (se tiver) e sua dúvida relevante para o streamer.</p>
                    </div>
                  </div>

                  <div class="d-flex align-start">
                    <v-avatar color="primary" size="32" class="mr-3 text-white font-weight-bold">2</v-avatar>
                    <div>
                      <h4 class="text-subtitle-2 font-weight-bold text-white">Gere a Palavra-Passe</h4>
                      <p class="text-caption text-grey-lighten-1 mb-0">Ao concluir o cadastro, guarde o código em português (ex: <strong>gato-azul-42</strong>) que aparece na tela.</p>
                    </div>
                  </div>

                  <div class="d-flex align-start">
                    <v-avatar color="primary" size="32" class="mr-3 text-white font-weight-bold">3</v-avatar>
                    <div>
                      <h4 class="text-subtitle-2 font-weight-bold text-white">Valide no Chat da Live</h4>
                      <p class="text-caption text-grey-lighten-1 mb-0">Quando o streamer chamar sua pergunta, digite a Palavra-Passe no chat. Assim provamos que você está assistindo!</p>
                    </div>
                  </div>

                  <div class="d-flex align-start">
                    <v-avatar color="accent" size="32" class="mr-3 text-white font-weight-bold">🎬</v-avatar>
                    <div>
                      <h4 class="text-subtitle-2 font-weight-bold text-white">Cortes & Destaques</h4>
                      <p class="text-caption text-grey-lighten-1 mb-0">Deixando seu TikTok, o streamer poderá fazer um corte da resposta e marcar seu perfil oficial na rede social!</p>
                    </div>
                  </div>
                </div>
              </v-card>
            </v-col>
          </v-row>
        </div>

        <!-- ========================================== -->
        <!-- LOGIN VIEW                               -->
        <!-- ========================================== -->
        <v-card v-if="currentView === 'admin' && !isAuthenticated" class="mx-auto glass-panel pa-6 text-center" max-width="450">
          <div class="d-flex justify-center mb-4">
            <svg class="brand-logo" viewBox="0 0 128 128" width="48" height="48">
              <path fill="#ff2d20" d="M96.1,19.3L64,1.1L31.9,19.3V55.6L0,73.8v36.4L32.1,128l32.1-18.2V73.4L96.1,55.2V19.3z M64.2,9.3l21,11.9l-21,11.9l-21-11.9L64.2,9.3z M37.3,27.2l21.3,12.1v24.2L37.3,51.4V27.2z M31.9,59l21,11.9l-21,11.9l-21-11.9L31.9,59z M5.2,81l21.3,12.1v24.2L5.2,105.2V81z M64.2,118.7l-21-11.9l21-11.9l21,11.9L64.2,118.7z M90.8,47.8V23.6l-21.3,12.1v24.2L90.8,47.8z"/>
            </svg>
          </div>
          <h2 class="text-h5 font-weight-bold text-white mb-1">Acesso do Streamer</h2>
          <p class="text-body-2 text-grey-lighten-1 mb-6">Faça login para gerenciar lives e perguntas.</p>
          
          <v-form @submit.prevent="login">
            <v-text-field
              v-model="loginForm.email"
              label="E-mail"
              type="email"
              placeholder="seu@email.com"
              variant="outlined"
              required
              :disabled="isLoggingIn"
              class="mb-2"
              density="comfortable"
              prepend-inner-icon="mdi-email"
            ></v-text-field>

            <v-text-field
              v-model="loginForm.password"
              label="Senha"
              type="password"
              placeholder="••••••"
              variant="outlined"
              required
              :disabled="isLoggingIn"
              class="mb-4"
              density="comfortable"
              prepend-inner-icon="mdi-lock"
            ></v-text-field>

            <div v-if="loginError" class="text-error text-caption mb-3">{{ loginError }}</div>

            <v-btn
              type="submit"
              color="primary"
              block
              size="large"
              :loading="isLoggingIn"
            >
              Entrar
            </v-btn>
          </v-form>
        </v-card>

        <!-- ========================================== -->
        <!-- STREAMER ADMIN VIEW                       -->
        <!-- ========================================== -->
        <v-row v-if="currentView === 'admin' && isAuthenticated">
          <!-- Admin Sidebar (Lives management) -->
          <v-col cols="12" md="4" class="order-last order-md-first">
            <v-card class="glass-panel pa-4">
              <h3 class="text-subtitle-1 font-weight-bold text-white mb-3">Agendar Nova Live</h3>
              <v-form @submit.prevent="createLive" class="pb-4 mb-4" style="border-bottom: 1px solid rgba(255,255,255,0.08);">
                <v-text-field
                  v-model="newLiveForm.title"
                  label="Título da Live"
                  placeholder="Ex: Live de Sexta"
                  variant="outlined"
                  required
                  density="compact"
                  class="mb-3"
                ></v-text-field>

                <v-text-field
                  v-model="newLiveForm.streamer_name"
                  label="Nome do Streamer"
                  placeholder="Ex: Admin"
                  variant="outlined"
                  density="compact"
                  class="mb-3"
                ></v-text-field>

                <v-text-field
                  v-model="newLiveForm.live_url"
                  label="Link da Transmissão"
                  placeholder="Ex: https://twitch.tv/seucanal"
                  variant="outlined"
                  density="compact"
                  class="mb-3"
                ></v-text-field>
                
                <div class="mb-3">
                  <span class="text-caption text-grey-lighten-1 d-block mb-1">Data e Hora</span>
                  <DatePicker
                    v-model="newLiveForm.scheduled_at"
                    placeholder="Selecione data e hora"
                  />
                </div>

                <v-btn
                  type="submit"
                  color="primary"
                  block
                  size="small"
                  :loading="isCreatingLive"
                >
                  Agendar Live
                </v-btn>
              </v-form>

              <h3 class="text-subtitle-1 font-weight-bold text-white mb-2">Suas Lives</h3>
              <v-list class="bg-transparent pa-0 overflow-y-auto" style="max-height: 400px; gap: 0.5rem; display: flex; flex-direction: column;">
                <v-list-item
                  v-for="live in lives"
                  :key="live.id"
                  :active="selectedLive?.id === live.id"
                  class="glass-panel"
                  style="border: 1px solid rgba(255, 255, 255, 0.05);"
                  @click="selectLive(live)"
                  link
                >
                  <v-list-item-title class="text-white font-weight-bold text-body-2">{{ live.title }}</v-list-item-title>
                  <v-list-item-subtitle class="text-caption text-grey-lighten-1">
                    {{ formatDateTime(live.scheduled_at) }}
                  </v-list-item-subtitle>
                  <template v-slot:append>
                    <v-chip
                      size="x-small"
                      :color="live.status === 'active' ? 'error' : live.status === 'finished' ? 'grey' : 'primary'"
                      variant="flat"
                    >
                      {{ live.status === 'active' ? 'Ativa' : live.status === 'finished' ? 'Finalizada' : 'Agendada' }}
                    </v-chip>
                  </template>
                </v-list-item>
                <div v-if="lives.length === 0" class="text-center text-caption text-grey-lighten-1 py-4">
                  Nenhuma live agendada.
                </div>
              </v-list>
            </v-card>
          </v-col>

          <!-- Main Moderation Panel -->
          <v-col cols="12" md="8" class="order-first order-md-last">
            <v-card class="glass-panel pa-6">
              <!-- Live Selected Header -->
              <div v-if="selectedLive" class="pb-4 mb-4" style="border-bottom: 1px solid rgba(255,255,255,0.08);">
                <v-row align="center" justify="space-between">
                  <v-col cols="12" sm="7">
                    <span class="text-caption text-uppercase text-grey-lighten-1 font-weight-bold">Live Selecionada</span>
                    <h2 class="text-h5 font-weight-bold text-white my-1">{{ selectedLive.title }}</h2>
                    <div class="d-flex align-center mt-1" style="gap: 0.5rem;">
                      <v-text-field
                        v-model="selectedLive.streamer_name"
                        label="Streamer"
                        placeholder="Nome do streamer"
                        variant="outlined"
                        density="compact"
                        hide-details
                        class="mb-0"
                        style="max-width: 200px;"
                      ></v-text-field>
                      <v-text-field
                        v-model="selectedLive.live_url"
                        label="Link da Live"
                        placeholder="https://twitch.tv/..."
                        variant="outlined"
                        density="compact"
                        hide-details
                        class="mb-0"
                        style="max-width: 300px;"
                      ></v-text-field>
                      <v-btn
                        v-if="selectedLive.live_url"
                        :href="selectedLive.live_url"
                        target="_blank"
                        size="x-small"
                        icon="mdi-open-in-new"
                        variant="text"
                        color="grey-lighten-1"
                        title="Abrir link"
                      ></v-btn>
                      <v-btn
                        size="x-small"
                        color="primary"
                        variant="flat"
                        @click="updateLive(selectedLive.id, { streamer_name: selectedLive.streamer_name, live_url: selectedLive.live_url })"
                      >
                        Salvar
                      </v-btn>
                    </div>
                    <p class="text-caption text-grey-lighten-2 mt-1 mb-0">Agendada: {{ formatDateTime(selectedLive.scheduled_at) }}</p>
                  </v-col>
                  <v-col cols="12" sm="5" class="d-flex justify-sm-end" style="gap: 0.5rem;">
                    <v-btn
                      v-if="selectedLive.status !== 'active'"
                      color="success"
                      size="small"
                      variant="flat"
                      @click="toggleLiveStatus('active')"
                    >
                      🔴 Iniciar Live
                    </v-btn>
                    <v-btn
                      v-if="selectedLive.status === 'active'"
                      color="grey-lighten-1"
                      size="small"
                      variant="flat"
                      @click="toggleLiveStatus('finished')"
                    >
                      ⏹️ Encerrar Live
                    </v-btn>
                    <v-btn
                      color="error"
                      size="small"
                      variant="outlined"
                      @click="deleteLive(selectedLive.id)"
                    >
                      Excluir
                    </v-btn>
                  </v-col>
                </v-row>
              </div>

              <!-- Filter Bar -->
              <div v-if="selectedLive" class="d-flex flex-wrap mb-4" style="gap: 0.5rem;">
                <v-btn
                  size="x-small"
                  :variant="selectedFilter === 'all' ? 'flat' : 'outlined'"
                  color="white"
                  @click="selectedFilter = 'all'"
                >
                  Todas ({{ adminQuestions.length }})
                </v-btn>
                <v-btn
                  size="x-small"
                  :variant="selectedFilter === 'pending' ? 'flat' : 'outlined'"
                  color="warning"
                  @click="selectedFilter = 'pending'"
                >
                  Pendentes ({{ adminQuestions.filter(q => q.status === 'pending').length }})
                </v-btn>
                <v-btn
                  size="x-small"
                  :variant="selectedFilter === 'approved' ? 'flat' : 'outlined'"
                  color="primary"
                  @click="selectedFilter = 'approved'"
                >
                  Aprovadas ({{ adminQuestions.filter(q => q.status === 'approved').length }})
                </v-btn>
                <v-btn
                  size="x-small"
                  :variant="selectedFilter === 'active' ? 'flat' : 'outlined'"
                  color="error"
                  @click="selectedFilter = 'active'"
                >
                  Na Tela ({{ adminQuestions.filter(q => q.status === 'active').length }})
                </v-btn>
                <v-btn
                  size="x-small"
                  :variant="selectedFilter === 'archived' ? 'flat' : 'outlined'"
                  color="grey"
                  @click="selectedFilter = 'archived'"
                >
                  Respondidas ({{ adminQuestions.filter(q => q.status === 'archived').length }})
                </v-btn>
              </div>

              <!-- Admin Questions List -->
              <div v-if="selectedLive">
                <div v-if="filteredQuestions.length > 0" class="d-flex flex-column" style="gap: 0.75rem;">
                  <v-card
                    v-for="q in filteredQuestions"
                    :key="q.id"
                    :class="['pa-4 border-left-3', q.status]"
                    variant="outlined"
                    style="background: rgba(255, 255, 255, 0.02); border-color: rgba(255,255,255,0.05);"
                  >
                    <div class="d-flex flex-wrap justify-space-between align-center mb-2" style="gap: 0.5rem;">
                      <div>
                        <span class="text-subtitle-2 font-weight-bold text-white mr-2">{{ q.name }}</span>
                        <v-chip
                          v-if="q.tiktok_handle"
                          size="x-small"
                          color="accent"
                          variant="flat"
                          :href="'https://www.tiktok.com/' + q.tiktok_handle"
                          target="_blank"
                          link
                          prepend-icon="mdi-music-note"
                        >
                          {{ q.tiktok_handle }}
                        </v-chip>
                      </div>
                      <div class="text-caption text-grey-lighten-1">
                        Palavra-Passe: <strong class="text-white font-weight-bold">{{ q.passcode }}</strong>
                      </div>
                    </div>

                    <p class="text-body-2 text-grey-lighten-2 mb-2">{{ q.question_text }}</p>
 
                    <!-- Vote Counts -->
                    <div class="mt-1 mb-3 d-flex align-center" style="gap: 1rem; border-top: 1px solid rgba(255,255,255,0.03); padding-top: 0.5rem;">
                      <span>
                        <v-icon size="x-small" color="success" class="mr-1">mdi-thumb-up</v-icon>
                        <strong class="text-white text-caption">{{ q.likes_count ?? 0 }}</strong>
                      </span>
                      <span>
                        <v-icon size="x-small" color="error" class="mr-1">mdi-thumb-down</v-icon>
                        <strong class="text-white text-caption">{{ q.dislikes_count ?? 0 }}</strong>
                      </span>
                    </div>

                    <!-- Timing Information -->
                    <div v-if="q.displayed_at" class="mt-1 mb-3 text-caption text-grey-lighten-1 d-flex flex-wrap align-center" style="gap: 1rem; border-top: 1px solid rgba(255,255,255,0.03); padding-top: 0.5rem;">
                      <span v-if="selectedLive?.started_at">
                        <v-icon size="x-small" class="mr-1">mdi-play-circle-outline</v-icon>
                        Início: <strong class="text-white">{{ formatRelativeTime(q.displayed_at, selectedLive.started_at) }}</strong>
                      </span>
                      <span v-if="q.removed_at && selectedLive?.started_at">
                        <v-icon size="x-small" class="mr-1">mdi-stop-circle-outline</v-icon>
                        Fim: <strong class="text-white">{{ formatRelativeTime(q.removed_at, selectedLive.started_at) }}</strong>
                      </span>
                      <span>
                        <v-icon size="x-small" class="mr-1">mdi-clock-outline</v-icon>
                        Duração: <strong class="text-white">{{ q.duration_seconds !== null ? formatDuration(q.duration_seconds) : 'Exibindo...' }}</strong>
                      </span>
                    </div>
 
                    <div class="d-flex flex-wrap justify-space-between align-center" style="gap: 0.75rem;">
                      <!-- Action Buttons -->
                      <div class="d-flex flex-wrap" style="gap: 0.25rem;">
                        <v-btn
                          v-if="q.status === 'pending'"
                          size="x-small"
                          color="success"
                          variant="flat"
                          @click="updateQuestionStatus(q.id, 'approved')"
                        >
                          Aprovar
                        </v-btn>
                        <v-btn
                          v-if="q.status === 'approved' || q.status === 'pending'"
                          size="x-small"
                          color="error"
                          variant="flat"
                          @click="updateQuestionStatus(q.id, 'active')"
                        >
                          Exibir na Tela (OBS)
                        </v-btn>
                        <v-btn
                          v-if="q.status === 'active'"
                          size="x-small"
                          color="grey-lighten-1"
                          variant="flat"
                          @click="updateQuestionStatus(q.id, 'archived')"
                        >
                          Marcar como Respondida
                        </v-btn>
                        <v-btn
                          v-if="q.status !== 'archived' && q.status !== 'pending'"
                          size="x-small"
                          color="grey-darken-1"
                          variant="flat"
                          @click="updateQuestionStatus(q.id, 'archived')"
                        >
                          Arquivar
                        </v-btn>
                        <v-btn
                          v-if="q.status === 'archived'"
                          size="x-small"
                          color="success"
                          variant="flat"
                          @click="updateQuestionStatus(q.id, 'approved')"
                        >
                          Desarquivar
                        </v-btn>
                        <v-btn
                          size="x-small"
                          :color="q.is_hidden ? 'success' : 'grey'"
                          variant="outlined"
                          @click="toggleQuestionHidden(q)"
                        >
                          {{ q.is_hidden ? 'Mostrar' : 'Ocultar' }}
                        </v-btn>
                        <v-btn
                          size="x-small"
                          color="error"
                          variant="outlined"
                          icon="mdi-delete"
                          style="min-width: 24px; width: 24px; height: 24px;"
                          @click="deleteQuestion(q.id)"
                        ></v-btn>
                      </div>

                      <!-- TikTok clip toggle -->
                      <div v-if="q.tiktok_handle">
                        <v-switch
                          :model-value="q.is_tagged === 1 || q.is_tagged === true"
                          @update:model-value="toggleQuestionTagStatus(q)"
                          color="accent"
                          hide-details
                          density="compact"
                          label="Corte Criado"
                          inline
                        ></v-switch>
                      </div>
                    </div>
                  </v-card>
                </div>

                <v-card v-else class="text-center pa-6 bg-transparent" variant="flat">
                  <v-icon size="48" color="grey-lighten-1" class="mb-3">mdi-help-circle-outline</v-icon>
                  <h3 class="text-h6 text-white mb-1">Nenhuma Pergunta</h3>
                  <p class="text-body-2 text-grey-lighten-1">Nenhuma pergunta encontrada com este filtro para esta live.</p>
                </v-card>
              </div>

              <v-card v-else class="text-center pa-10 bg-transparent" variant="flat">
                <v-icon size="48" color="grey-lighten-1" class="mb-3">mdi-alert-circle-outline</v-icon>
                <h3 class="text-h6 text-white mb-1">Nenhuma Live Selecionada</h3>
                <p class="text-body-2 text-grey-lighten-1">Selecione ou crie uma live na barra lateral esquerda para gerenciar as perguntas.</p>
              </v-card>
            </v-card>
          </v-col>
        </v-row>
      </v-container>
    </v-main>
  </v-app>
</template>

