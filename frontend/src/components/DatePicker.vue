<script setup>
import { ref, onMounted, onUnmounted, watch } from 'vue'
import flatpickr from 'flatpickr'
import 'flatpickr/dist/flatpickr.min.css'

const props = defineProps({
  modelValue: { type: String, default: '' },
  placeholder: { type: String, default: '' },
})

const emit = defineEmits(['update:modelValue'])

const inputRef = ref(null)
let fp = null

onMounted(() => {
  const nativeInput = inputRef.value?.$el?.querySelector('input')
  if (nativeInput) {
    fp = flatpickr(nativeInput, {
      enableTime: true,
      dateFormat: 'Y-m-d H:i:S',
      time_24hr: true,
      minuteIncrement: 5,
      defaultHour: 20,
      defaultMinute: 0,
      onChange: (selectedDates, dateStr) => {
        emit('update:modelValue', dateStr)
      },
    })
  }
})

watch(() => props.modelValue, (val) => {
  if (fp && val !== fp.input.value) {
    fp.setDate(val, false)
  }
})

onUnmounted(() => {
  if (fp) fp.destroy()
})
</script>

<template>
  <v-text-field
    ref="inputRef"
    :placeholder="placeholder"
    :model-value="modelValue"
    readonly
    prepend-inner-icon="mdi-calendar-clock"
    variant="outlined"
    density="comfortable"
    hide-details
  />
</template>

