import { createApp } from 'vue'
import './style.css'
import App from './App.vue'

// Vuetify
import 'vuetify/styles'
import { createVuetify } from 'vuetify'
import '@mdi/font/css/materialdesignicons.css'

const vuetify = createVuetify({
  theme: {
    defaultTheme: 'dark',
    themes: {
      dark: {
        colors: {
          primary: '#b84a3a',
          accent: '#d97706',
          error: '#ef4444',
          success: '#10b981',
          warning: '#f59e0b',
        },
      },
    },
  },
})

createApp(App).use(vuetify).mount('#app')

