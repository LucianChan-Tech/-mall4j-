<script setup>
import { computed } from 'vue'

const props = defineProps({
  price: { type: [Number, String], required: true },
  size: { type: String, default: 'base' } // sm | base | lg
})

const priceParts = computed(() => {
  const num = Number(props.price)
  const intPart = Math.floor(num)
  const decPart = Math.round((num - intPart) * 100)
  return {
    int: intPart.toLocaleString(),
    dec: String(decPart).padStart(2, '0')
  }
})

const sizeClasses = {
  sm: { symbol: 'text-xs', int: 'text-sm', dec: 'text-xs' },
  base: { symbol: 'text-sm', int: 'text-xl', dec: 'text-sm' },
  lg: { symbol: 'text-base', int: 'text-2xl', dec: 'text-base' }
}
</script>

<template>
  <span class="inline-flex items-baseline text-rose-500 font-semibold">
    <span :class="sizeClasses[size].symbol">¥</span>
    <span :class="sizeClasses[size].int">{{ priceParts.int }}</span>
    <span :class="[sizeClasses[size].dec, 'text-rose-400']">.{{ priceParts.dec }}</span>
  </span>
</template>
