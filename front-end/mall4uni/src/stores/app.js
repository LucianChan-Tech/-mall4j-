import { defineStore } from 'pinia'
import { ref } from 'vue'
import { cartApi } from '@/api/cart'

export const useAppStore = defineStore('app', () => {
  const cartCount = ref(0)
  const isLoading = ref(false)
  const globalConfig = ref({})

  async function refreshCartCount() {
    try {
      const res = await cartApi.getCount()
      cartCount.value = res.data || 0
    } catch {
      cartCount.value = 0
    }
  }

  return {
    cartCount,
    isLoading,
    globalConfig,
    refreshCartCount
  }
})
