<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { orderApi } from '@/api/order'
import { useUserStore } from '@/stores/user'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'
import EmptyState from '@/components/common/EmptyState.vue'

const router = useRouter()
const userStore = useUserStore()

const orders = ref([])
const loading = ref(true)
const currentTab = ref('all')

const tabs = [
  { key: 'all', label: '全部' },
  { key: 'unpay', label: '待支付' },
  { key: 'consignment', label: '待发货' },
  { key: 'unReceive', label: '待收货' },
  { key: 'success', label: '已完成' }
]

async function fetchOrders() {
  loading.value = true
  try {
    const params = { current: 1, size: 20 }
    if (currentTab.value !== 'all') {
      params.status = currentTab.value
    }
    const res = await orderApi.getList(params)
    orders.value = res.data?.records || []
  } catch (err) {
    console.error('加载订单列表失败:', err)
    orders.value = []
  } finally {
    loading.value = false
  }
}

function switchTab(tab) {
  currentTab.value = tab
  fetchOrders()
}

function goDetail(orderId) {
  router.push(`/orders/${orderId}`)
}

function getStatusText(order) {
  const map = {
    'unpay': '待支付',
    'consignment': '待发货',
    'unReceive': '待收货',
    'success': '已完成',
    'cancel': '已取消'
  }
  return map[order.status] || order.status
}

function getStatusClass(order) {
  const map = {
    'unpay': 'text-amber-500',
    'consignment': 'text-brand-500',
    'unReceive': 'text-brand-600',
    'success': 'text-emerald-500',
    'cancel': 'text-slate-400'
  }
  return map[order.status] || 'text-slate-500'
}

onMounted(() => {
  if (!userStore.isLoggedIn) {
    router.push('/login')
    return
  }
  fetchOrders()
})
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-5xl mx-auto px-4 py-6">
      <h1 class="text-xl font-bold text-slate-800 mb-6">我的订单</h1>

      <!-- Tab 切换 -->
      <div class="bg-white rounded-xl shadow-sm p-1 flex mb-4 overflow-x-auto">
        <button
          v-for="tab in tabs"
          :key="tab.key"
          class="px-4 py-2 text-sm rounded-lg whitespace-nowrap transition-colors"
          :class="currentTab === tab.key
            ? 'bg-brand-50 text-brand-600 font-medium'
            : 'text-slate-500 hover:text-slate-700'"
          @click="switchTab(tab.key)"
        >
          {{ tab.label }}
        </button>
      </div>

      <LoadingSpinner v-if="loading" />
      <EmptyState v-else-if="!orders.length" message="暂无订单" />

      <div v-else class="space-y-3">
        <div
          v-for="order in orders"
          :key="order.orderId"
          class="bg-white rounded-xl shadow-sm overflow-hidden cursor-pointer hover:shadow-card-hover transition-shadow"
          @click="goDetail(order.orderId)"
        >
          <!-- 订单头部 -->
          <div class="flex items-center justify-between px-5 py-3 border-b border-slate-50">
            <span class="text-xs text-slate-400">
              订单号：{{ order.orderId }}
            </span>
            <span class="text-xs font-medium" :class="getStatusClass(order)">
              {{ getStatusText(order) }}
            </span>
          </div>

          <!-- 商品列表 -->
          <div class="px-5 py-3 space-y-2">
            <div
              v-for="item in order.orderItems"
              :key="item.orderItemId"
              class="flex items-center gap-3"
            >
              <div class="flex-1 min-w-0">
                <p class="text-sm text-slate-700 truncate">{{ item.prodName }}</p>
                <p class="text-xs text-slate-400">x{{ item.prodCount }}</p>
              </div>
              <span class="text-sm text-rose-500 font-medium shrink-0">
                ¥{{ Number(item.price).toFixed(2) }}
              </span>
            </div>
          </div>

          <!-- 订单底部 -->
          <div class="px-5 py-3 bg-slate-50/50 flex items-center justify-between">
            <span class="text-xs text-slate-400">{{ order.createTime }}</span>
            <span class="text-sm text-slate-700">
              合计：
              <span class="text-rose-500 font-bold">¥{{ Number(order.total).toFixed(2) }}</span>
            </span>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
