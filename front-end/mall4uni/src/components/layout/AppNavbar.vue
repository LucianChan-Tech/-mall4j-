<script setup>
import { ref, watch } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { useAppStore } from '@/stores/app'
import { useUserStore } from '@/stores/user'

const router = useRouter()
const route = useRoute()
const appStore = useAppStore()
const userStore = useUserStore()

const searchKeyword = ref('')

function doSearch() {
  const keyword = searchKeyword.value.trim()
  if (!keyword) return
  router.push({ path: '/search/result', query: { q: keyword } })
  searchKeyword.value = ''
}

// 路由变化时触发购物车数量刷新
watch(
  () => route.path,
  () => {
    if (userStore.isLoggedIn) {
      appStore.refreshCartCount()
    }
  }
)

const navLinks = [
  { path: '/', label: '首页' },
  { path: '/category', label: '分类' }
]

function isActive(path) {
  if (path === '/') return route.path === '/'
  return route.path.startsWith(path)
}
</script>

<template>
  <header class="fixed top-0 left-0 right-0 z-50 bg-white border-b border-slate-200">
    <div class="max-w-7xl mx-auto px-4 h-16 flex items-center gap-6">
      <!-- Logo -->
      <a href="/" class="flex items-center gap-2 shrink-0" @click.prevent="router.push('/')">
        <span class="text-xl font-bold text-brand-600">mall4j</span>
      </a>

      <!-- 导航菜单 -->
      <nav class="hidden sm:flex items-center gap-1">
        <a
          v-for="link in navLinks"
          :key="link.path"
          :href="link.path"
          class="px-3 py-2 text-sm rounded-lg transition-colors"
          :class="isActive(link.path) ? 'text-brand-600 bg-brand-50 font-medium' : 'text-slate-600 hover:text-slate-900 hover:bg-slate-100'"
          @click.prevent="router.push(link.path)"
        >
          {{ link.label }}
        </a>
      </nav>

      <!-- 搜索框 -->
      <div class="flex-1 max-w-md mx-auto">
        <form @submit.prevent="doSearch" class="relative">
          <input
            v-model="searchKeyword"
            type="text"
            placeholder="搜索商品..."
            class="w-full h-9 pl-4 pr-10 text-sm bg-slate-100 border-0 rounded-lg focus:ring-2 focus:ring-brand-500 focus:bg-white transition-colors"
          />
          <button
            type="submit"
            class="absolute right-1 top-1/2 -translate-y-1/2 w-7 h-7 flex items-center justify-center text-slate-400 hover:text-brand-600 transition-colors"
          >
            <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
            </svg>
          </button>
        </form>
      </div>

      <!-- 右侧操作区 -->
      <div class="flex items-center gap-3 shrink-0">
        <!-- 购物车 -->
        <button
          class="relative p-2 text-slate-600 hover:text-brand-600 transition-colors"
          @click="router.push('/cart')"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 100 4 2 2 0 000-4z" />
          </svg>
          <span
            v-if="appStore.cartCount > 0"
            class="absolute -top-0.5 -right-0.5 w-4.5 h-4.5 flex items-center justify-center bg-rose-500 text-white text-[10px] font-bold rounded-full min-w-[18px]"
          >
            {{ appStore.cartCount > 99 ? '99+' : appStore.cartCount }}
          </span>
        </button>

        <!-- 用户 -->
        <template v-if="userStore.isLoggedIn">
          <button
            class="p-2 text-slate-600 hover:text-brand-600 transition-colors"
            @click="router.push('/user')"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
            </svg>
          </button>
        </template>
        <template v-else>
          <button
            class="text-sm text-brand-600 hover:text-brand-700 font-medium whitespace-nowrap"
            @click="router.push('/login')"
          >
            登录
          </button>
        </template>
      </div>
    </div>
  </header>
</template>
