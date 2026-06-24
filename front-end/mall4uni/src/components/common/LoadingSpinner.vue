<script setup>
defineProps({
  size: { type: String, default: 'md' }
})
</script>

<template>
  <div class="flex items-center justify-center py-12">
    <div
      class="animate-spin rounded-full border-brand-200 border-t-brand-500"
      :class="size === 'sm' ? 'w-5 h-5 border-2' : size === 'lg' ? 'w-10 h-10 border-[3px]' : 'w-8 h-8 border-[3px]'"
    />
  </div>
</template>
