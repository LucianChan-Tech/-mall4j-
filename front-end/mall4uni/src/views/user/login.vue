<script setup>
import { ref } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()

const username = ref('')
const password = ref('')
const loading = ref(false)
const error = ref('')

async function doLogin() {
  error.value = ''
  if (!username.value.trim() || !password.value.trim()) {
    error.value = '请输入用户名和密码'
    return
  }

  loading.value = true
  try {
    await userStore.login({
      userName: username.value.trim(),
      passWord: password.value.trim()
    })
    // 跳回登录前页面
    const redirect = sessionStorage.getItem('redirectAfterLogin') || '/'
    sessionStorage.removeItem('redirectAfterLogin')
    router.push(redirect)
  } catch (err) {
    error.value = err.message || '登录失败，请重试'
  } finally {
    loading.value = false
  }
}

function goRegister() {
  router.push('/register')
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 flex items-center justify-center py-12">
    <div class="w-full max-w-sm mx-4">
      <!-- Logo -->
      <div class="text-center mb-8">
        <h1 class="text-2xl font-bold text-brand-600">mall4j</h1>
        <p class="text-sm text-slate-400 mt-1">欢迎回来</p>
      </div>

      <!-- 登录卡片 -->
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <h2 class="text-lg font-semibold text-slate-800 mb-6">用户登录</h2>

        <!-- 错误提示 -->
        <div
          v-if="error"
          class="mb-4 p-3 bg-rose-50 text-rose-600 text-sm rounded-lg"
        >
          {{ error }}
        </div>

        <!-- 表单 -->
        <form @submit.prevent="doLogin" class="space-y-4">
          <div>
            <label class="block text-sm text-slate-600 mb-1">用户名</label>
            <input
              v-model="username"
              type="text"
              placeholder="请输入用户名"
              class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
              autocomplete="username"
            />
          </div>

          <div>
            <label class="block text-sm text-slate-600 mb-1">密码</label>
            <input
              v-model="password"
              type="password"
              placeholder="请输入密码"
              class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
              autocomplete="current-password"
              @keydown.enter="doLogin"
            />
          </div>

          <button
            type="submit"
            class="w-full h-11 rounded-xl text-sm font-medium bg-brand-600 text-white hover:bg-brand-700 disabled:opacity-50 transition-colors"
            :disabled="loading"
          >
            {{ loading ? '登录中...' : '登录' }}
          </button>
        </form>

        <!-- 注册入口 -->
        <div class="mt-6 text-center">
          <span class="text-sm text-slate-400">还没有账号？</span>
          <button class="text-sm text-brand-600 hover:text-brand-700 font-medium ml-1" @click="goRegister">
            立即注册
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
