<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { useUserStore } from '@/stores/user'
import { useAppStore } from '@/stores/app'

const router = useRouter()
const userStore = useUserStore()
const appStore = useAppStore()

const orderCounts = ref({
  unPay: 0,
  unDelivery: 0,
  unReceive: 0,
  receive: 0,
  success: 0
})

function goLogin() {
  router.push('/login')
}

function goLogout() {
  userStore.logout()
  router.push('/')
}

function goOrders(status) {
  router.push({ path: '/orders', query: { status } })
}

function goAddress() {
  router.push('/address')
}

function goNews() {
  router.push('/news')
}

onMounted(async () => {
  if (userStore.isLoggedIn) {
    await appStore.refreshCartCount()
  }
})

const menuItems = [
  { icon: 'location', label: '收货地址', action: goAddress },
  { icon: 'news', label: '最新公告', action: goNews }
]

const orderStatusItems = [
  { key: 'unpay', label: '待支付', icon: 'wallet' },
  { key: 'consignment', label: '待发货', icon: 'package' },
  { key: 'unReceive', label: '待收货', icon: 'truck' },
  { key: 'success', label: '已完成', icon: 'check' }
]
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <!-- 未登录 -->
    <div v-if="!userStore.isLoggedIn" class="flex flex-col items-center justify-center py-20">
      <svg class="w-20 h-20 text-slate-200 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
      </svg>
      <p class="text-sm text-slate-400 mb-4">登录后享受更多服务</p>
      <button
        class="px-8 h-10 rounded-xl text-sm font-medium bg-brand-600 text-white hover:bg-brand-700 transition-colors"
        @click="goLogin"
      >
        去登录
      </button>
    </div>

    <!-- 已登录 -->
    <template v-else>
      <!-- 用户信息头 -->
      <div class="bg-gradient-to-br from-brand-500 to-brand-700">
        <div class="max-w-5xl mx-auto px-4 py-8">
          <div class="flex items-center gap-4">
            <!-- 头像 -->
            <div class="w-16 h-16 rounded-full bg-white/20 flex items-center justify-center">
              <svg class="w-8 h-8 text-white" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" />
              </svg>
            </div>
            <div class="text-white">
              <p class="text-lg font-semibold">用户</p>
              <p class="text-sm text-white/70">欢迎回来</p>
            </div>
          </div>
        </div>
      </div>

      <div class="max-w-5xl mx-auto px-4 -mt-4">
        <!-- 订单状态卡片 -->
        <div class="bg-white rounded-xl shadow-sm p-4 mb-3">
          <div class="flex items-center justify-between mb-4">
            <h3 class="text-sm font-medium text-slate-700">我的订单</h3>
            <button
              class="text-xs text-brand-600 hover:text-brand-700"
              @click="goOrders('all')"
            >
              查看全部 →
            </button>
          </div>
          <div class="grid grid-cols-4 gap-2">
            <button
              v-for="item in orderStatusItems"
              :key="item.key"
              class="flex flex-col items-center gap-1.5 py-2 rounded-lg hover:bg-slate-50 transition-colors"
              @click="goOrders(item.key)"
            >
              <div class="w-9 h-9 rounded-full bg-slate-50 flex items-center justify-center">
                <svg v-if="item.key === 'unpay'" class="w-4 h-4 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 9V7a2 2 0 00-2-2H5a2 2 0 00-2 2v6a2 2 0 002 2h2m2 4h10a2 2 0 002-2v-6a2 2 0 00-2-2H9a2 2 0 00-2 2v6a2 2 0 002 2zm7-5a2 2 0 11-4 0 2 2 0 014 0z" />
                </svg>
                <svg v-else-if="item.key === 'consignment'" class="w-4 h-4 text-brand-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M20 7l-8-4-8 4m16 0l-8 4m8-4v10l-8 4m0-10L4 7m8 4v10M4 7v10l8 4" />
                </svg>
                <svg v-else-if="item.key === 'unReceive'" class="w-4 h-4 text-brand-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16V6a1 1 0 00-1-1H4a1 1 0 00-1 1v10l2-1m2 1l2-1m2 1l2-1m2 1V6a1 1 0 00-1-1h-2a1 1 0 00-1 1v10" />
                </svg>
                <svg v-else class="w-4 h-4 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
                </svg>
              </div>
              <span class="text-xs text-slate-600">{{ item.label }}</span>
            </button>
          </div>
        </div>

        <!-- 菜单列表 -->
        <div class="bg-white rounded-xl shadow-sm mb-6">
          <button
            v-for="(item, idx) in menuItems"
            :key="idx"
            class="w-full flex items-center justify-between px-5 py-4 hover:bg-slate-50 transition-colors"
            :class="idx < menuItems.length - 1 ? 'border-b border-slate-50' : ''"
            @click="item.action()"
          >
            <div class="flex items-center gap-3">
              <svg v-if="item.icon === 'location'" class="w-5 h-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17.657 16.657L13.414 20.9a1.998 1.998 0 01-2.827 0l-4.244-4.243a8 8 0 1111.314 0z" />
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 11a3 3 0 11-6 0 3 3 0 016 0z" />
              </svg>
              <svg v-else-if="item.icon === 'news'" class="w-5 h-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 20H5a2 2 0 01-2-2V6a2 2 0 012-2h10a2 2 0 012 2v1m2 13a2 2 0 01-2-2V7m2 13a2 2 0 002-2V9a2 2 0 00-2-2h-2m-4-3H9M7 16h6M7 8h6v4H7V8z" />
              </svg>
              <span class="text-sm text-slate-700">{{ item.label }}</span>
            </div>
            <svg class="w-4 h-4 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </button>
        </div>

        <!-- 退出登录 -->
        <button
          class="w-full h-11 rounded-xl text-sm text-rose-500 bg-white shadow-sm hover:bg-rose-50 transition-colors mb-8"
          @click="goLogout"
        >
          退出登录
        </button>
      </div>
    </template>
  </div>
</template>
