<script setup>
import AppLayout from '@/components/layout/AppLayout.vue'
import { onMounted } from 'vue'
import { useAppStore } from '@/stores/app'
import { useUserStore } from '@/stores/user'

const appStore = useAppStore()
const userStore = useUserStore()

onMounted(() => {
  if (userStore.isLoggedIn) {
    appStore.refreshCartCount()
  }
})
</script>

<template>
  <AppLayout />
</template>
