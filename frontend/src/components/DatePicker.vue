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
  fp = flatpickr(inputRef.value, {
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
  <input
    ref="inputRef"
    type="text"
    class="form-input"
    :placeholder="placeholder"
    :value="modelValue"
    readonly
  />
</template>
