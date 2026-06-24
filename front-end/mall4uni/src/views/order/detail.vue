<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { orderApi } from '@/api/order'
import { useUserStore } from '@/stores/user'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const route = useRoute()
const router = useRouter()
const userStore = useUserStore()

const order = ref(null)
const loading = ref(true)

const orderId = computed(() => route.params.id)

const statusMap = {
  'unpay': { label: '待支付', color: 'text-amber-500 bg-amber-50' },
  'consignment': { label: '待发货', color: 'text-brand-500 bg-brand-50' },
  'unReceive': { label: '待收货', color: 'text-brand-600 bg-brand-50' },
  'success': { label: '已完成', color: 'text-emerald-500 bg-emerald-50' },
  'cancel': { label: '已取消', color: 'text-slate-400 bg-slate-50' }
}

const statusInfo = computed(() => statusMap[order.value?.status] || { label: '未知', color: 'text-slate-400' })

async function fetchDetail() {
  loading.value = true
  try {
    const res = await orderApi.getDetail(orderId.value)
    order.value = res.data
  } catch (err) {
    console.error('加载订单详情失败:', err)
  } finally {
    loading.value = false
  }
}

async function cancelOrder() {
  if (!confirm('确定取消该订单？')) return
  try {
    await orderApi.cancel(orderId.value)
    fetchDetail()
  } catch (err) {
    alert(err.message || '取消失败')
  }
}

function goPayment() {
  router.push(`/payment/result?orderId=${orderId.value}&amount=${order.value?.total || 0}`)
}

function goLogistics() {
  router.push(`/logistics/${orderId.value}`)
}

onMounted(() => {
  if (!userStore.isLoggedIn) {
    router.push('/login')
    return
  }
  fetchDetail()
})
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-4xl mx-auto px-4 py-6">
      <LoadingSpinner v-if="loading" />

      <template v-if="order">
        <!-- 订单状态 -->
        <div class="bg-white rounded-xl shadow-sm p-6 mb-3">
          <div class="flex items-center gap-3 mb-1">
            <span
              class="px-3 py-1 rounded-full text-xs font-medium"
              :class="statusInfo.color"
            >
              {{ statusInfo.label }}
            </span>
          </div>
          <p class="text-xs text-slate-400 mt-2">订单号：{{ order.orderId }}</p>
          <p class="text-xs text-slate-400">下单时间：{{ order.createTime }}</p>
        </div>

        <!-- 收货地址 -->
        <div class="bg-white rounded-xl shadow-sm p-5 mb-3">
          <div class="flex items-center gap-3 mb-1">
            <span class="font-medium text-slate-800">{{ order.receiver }}</span>
            <span class="text-sm text-slate-500">{{ order.receiverMobile }}</span>
          </div>
          <p class="text-sm text-slate-500">
            {{ order.receiverProvince }}{{ order.receiverCity }}{{ order.receiverArea }}{{ order.receiverAddress }}
          </p>
        </div>

        <!-- 商品列表 -->
        <div class="bg-white rounded-xl shadow-sm p-5 mb-3">
          <h3 class="text-sm font-medium text-slate-700 mb-3">商品信息</h3>
          <div
            v-for="item in order.orderItems"
            :key="item.orderItemId"
            class="flex items-center gap-3 py-2 border-b border-slate-50 last:border-0"
          >
            <div class="flex-1 min-w-0">
              <p class="text-sm text-slate-700">{{ item.prodName }}</p>
              <p v-if="item.skuName" class="text-xs text-slate-400">{{ item.skuName }}</p>
            </div>
            <div class="text-right shrink-0">
              <p class="text-sm text-rose-500 font-medium">¥{{ Number(item.price).toFixed(2) }}</p>
              <p class="text-xs text-slate-400">x{{ item.prodCount }}</p>
            </div>
          </div>
        </div>

        <!-- 价格明细 -->
        <div class="bg-white rounded-xl shadow-sm p-5 mb-24">
          <div class="space-y-2 text-sm">
            <div class="flex justify-between text-slate-500">
              <span>商品金额</span>
              <span>¥{{ Number(order.total).toFixed(2) }}</span>
            </div>
            <div class="flex justify-between text-slate-500">
              <span>运费</span>
              <span>免运费</span>
            </div>
            <div class="flex justify-between font-medium text-slate-800 pt-2 border-t border-slate-100">
              <span>实付金额</span>
              <span class="text-rose-500 text-lg">¥{{ Number(order.total).toFixed(2) }}</span>
            </div>
          </div>
        </div>

        <!-- 底部操作 -->
        <div class="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 z-40">
          <div class="max-w-4xl mx-auto px-4 h-16 flex items-center justify-end gap-3">
            <button
              v-if="order.status === 'consignment' || order.status === 'unReceive'"
              class="px-5 h-9 rounded-lg text-sm border border-slate-200 text-slate-600 hover:bg-slate-50 transition-colors"
              @click="goLogistics"
            >
              查看物流
            </button>
            <button
              v-if="order.status === 'unpay'"
              class="px-5 h-9 rounded-lg text-sm border border-slate-200 text-slate-600 hover:bg-slate-50 transition-colors"
              @click="cancelOrder"
            >
              取消订单
            </button>
            <button
              v-if="order.status === 'unpay'"
              class="px-8 h-9 rounded-lg text-sm font-medium bg-rose-500 text-white hover:bg-rose-600 transition-colors"
              @click="goPayment"
            >
              立即支付
            </button>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
