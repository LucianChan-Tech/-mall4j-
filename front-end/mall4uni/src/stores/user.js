import { defineStore } from 'pinia'
import { ref, computed } from 'vue'
import { userApi } from '@/api/user'

export const useUserStore = defineStore('user', () => {
  const token = ref(localStorage.getItem('token') || '')
  const userInfo = ref(null)
  const expiresAt = ref(Number(localStorage.getItem('expiresAt') || 0))

  const isLoggedIn = computed(() => !!token.value)
  const isTokenExpired = computed(() => Date.now() > expiresAt.value)

  async function login(credentials) {
    const res = await userApi.login(credentials)
    const data = res.data
    token.value = data.accessToken
    expiresAt.value = data.expiresIn * 1000 / 2 + Date.now()
    localStorage.setItem('token', data.accessToken)
    localStorage.setItem('expiresAt', String(expiresAt.value))
    localStorage.setItem('hadLogin', 'true')
    return data
  }

  async function register(data) {
    return await userApi.register(data)
  }

  function logout() {
    token.value = ''
    userInfo.value = null
    expiresAt.value = 0
    localStorage.removeItem('token')
    localStorage.removeItem('expiresAt')
    localStorage.removeItem('hadLogin')
  }

  async function refreshToken() {
    if (!token.value || !expiresAt.value) return
    if (!isTokenExpired.value) return
    try {
      const res = await userApi.refresh()
      expiresAt.value = res.data * 1000 / 2 + Date.now()
      localStorage.setItem('expiresAt', String(expiresAt.value))
    } catch {
      // refresh failed, ignore
    }
  }

  return {
    token,
    userInfo,
    expiresAt,
    isLoggedIn,
    isTokenExpired,
    login,
    register,
    logout,
    refreshToken
  }
})
