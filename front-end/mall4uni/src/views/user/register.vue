<script setup>
import { ref } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const userStore = useUserStore()

const username = ref('')
const password = ref('')
const confirmPassword = ref('')
const loading = ref(false)
const error = ref('')

async function doRegister() {
  error.value = ''

  if (!username.value.trim() || !password.value.trim()) {
    error.value = '请填写所有字段'
    return
  }
  if (password.value !== confirmPassword.value) {
    error.value = '两次密码不一致'
    return
  }
  if (password.value.length < 6) {
    error.value = '密码至少6位'
    return
  }

  loading.value = true
  try {
    await userStore.register({
      userName: username.value.trim(),
      passWord: password.value.trim()
    })
    // 注册成功后自动登录
    await userStore.login({
      userName: username.value.trim(),
      passWord: password.value.trim()
    })
    router.push('/')
  } catch (err) {
    error.value = err.message || '注册失败，请重试'
  } finally {
    loading.value = false
  }
}

function goLogin() {
  router.push('/login')
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 flex items-center justify-center py-12">
    <div class="w-full max-w-sm mx-4">
      <!-- Logo -->
      <div class="text-center mb-8">
        <h1 class="text-2xl font-bold text-brand-600">mall4j</h1>
        <p class="text-sm text-slate-400 mt-1">注册新账号</p>
      </div>

      <!-- 注册卡片 -->
      <div class="bg-white rounded-2xl shadow-sm p-6">
        <h2 class="text-lg font-semibold text-slate-800 mb-6">用户注册</h2>

        <!-- 错误提示 -->
        <div
          v-if="error"
          class="mb-4 p-3 bg-rose-50 text-rose-600 text-sm rounded-lg"
        >
          {{ error }}
        </div>

        <!-- 表单 -->
        <form @submit.prevent="doRegister" class="space-y-4">
          <div>
            <label class="block text-sm text-slate-600 mb-1">用户名</label>
            <input
              v-model="username"
              type="text"
              placeholder="请设置用户名"
              class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
              autocomplete="username"
            />
          </div>

          <div>
            <label class="block text-sm text-slate-600 mb-1">密码</label>
            <input
              v-model="password"
              type="password"
              placeholder="请设置密码（至少6位）"
              class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
              autocomplete="new-password"
            />
          </div>

          <div>
            <label class="block text-sm text-slate-600 mb-1">确认密码</label>
            <input
              v-model="confirmPassword"
              type="password"
              placeholder="请再次输入密码"
              class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
              autocomplete="new-password"
              @keydown.enter="doRegister"
            />
          </div>

          <button
            type="submit"
            class="w-full h-11 rounded-xl text-sm font-medium bg-brand-600 text-white hover:bg-brand-700 disabled:opacity-50 transition-colors"
            :disabled="loading"
          >
            {{ loading ? '注册中...' : '注册' }}
          </button>
        </form>

        <!-- 登录入口 -->
        <div class="mt-6 text-center">
          <span class="text-sm text-slate-400">已有账号？</span>
          <button class="text-sm text-brand-600 hover:text-brand-700 font-medium ml-1" @click="goLogin">
            立即登录
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
