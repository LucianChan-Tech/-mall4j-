<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { addressApi } from '@/api/address'
import { orderApi } from '@/api/order'
import { useUserStore } from '@/stores/user'
import PriceDisplay from '@/components/product/PriceDisplay.vue'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()

const loading = ref(true)
const submitting = ref(false)

// 订单数据
const orderItem = ref(null)
const addresses = ref([])
const selectedAddress = ref(null)
const paymentType = ref(1) // 1=微信支付

// 如果是直接购买（从商品详情跳来）
const isDirectBuy = computed(() => route.query.orderEntry === '1')

onMounted(async () => {
  if (!userStore.isLoggedIn) {
    router.push('/login')
    return
  }

  try {
    // 加载订单项
    if (isDirectBuy.value) {
      const stored = sessionStorage.getItem('orderItem')
      orderItem.value = stored ? JSON.parse(stored) : null
    } else {
      // 从购物车结算：从 store 读取选中项
      const { useCartStore } = await import('@/stores/cart')
      const cartStore = useCartStore()
      orderItem.value = {
        shopCartItems: cartStore.selectedItems,
        total: cartStore.totalPrice
      }
    }

    // 加载地址
    const addrRes = await addressApi.getList()
    addresses.value = addrRes.data || []
    if (addresses.value.length) {
      const defaultAddr = addresses.value.find(a => a.isDefault === 1)
      selectedAddress.value = defaultAddr || addresses.value[0]
    }
  } catch (err) {
    console.error('加载结算数据失败:', err)
  } finally {
    loading.value = false
  }
})

async function submitOrder() {
  if (!selectedAddress.value) {
    alert('请选择收货地址')
    return
  }
  submitting.value = true
  try {
    const data = {
      addrId: selectedAddress.value.addrId,
      paymentType: paymentType.value,
      orderItems: isDirectBuy.value
        ? [orderItem.value]
        : orderItem.value?.shopCartItems?.map(i => ({
            prodId: i.prodId,
            skuId: i.skuId,
            prodCount: i.prodCount,
            shopId: i.shopId
          }))
    }
    const res = await orderApi.submit(data)
    // 跳转到支付结果
    router.push(`/payment/result?orderId=${res.data?.orderId || ''}&amount=${orderItem.value?.total || 0}`)
  } catch (err) {
    alert(err.message || '提交订单失败')
  } finally {
    submitting.value = false
  }
}

function goAddressList() {
  router.push('/address')
}
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-4xl mx-auto px-4 py-6">
      <h1 class="text-xl font-bold text-slate-800 mb-6">确认订单</h1>

      <LoadingSpinner v-if="loading" />

      <template v-else>
        <!-- 收货地址 -->
        <section class="bg-white rounded-xl shadow-sm p-5 mb-3">
          <div v-if="selectedAddress" class="cursor-pointer hover:bg-slate-50 -m-5 p-5 rounded-xl transition-colors" @click="goAddressList">
            <div class="flex items-center justify-between mb-2">
              <div class="flex items-center gap-3">
                <span class="font-medium text-slate-800">{{ selectedAddress.receiver }}</span>
                <span class="text-sm text-slate-500">{{ selectedAddress.mobile }}</span>
              </div>
              <svg class="w-4 h-4 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </div>
            <p class="text-sm text-slate-500">
              {{ selectedAddress.province }}{{ selectedAddress.city }}{{ selectedAddress.area }}
              {{ selectedAddress.addr }}
            </p>
          </div>
          <div v-else class="text-center py-4">
            <p class="text-sm text-slate-400 mb-2">请添加收货地址</p>
            <button class="text-sm text-brand-600 font-medium" @click="goAddressList">去添加</button>
          </div>
        </section>

        <!-- 商品确认 -->
        <section class="bg-white rounded-xl shadow-sm p-5 mb-3">
          <h3 class="text-sm font-medium text-slate-700 mb-3">商品信息</h3>

          <!-- 直接购买 -->
          <div v-if="isDirectBuy && orderItem" class="flex items-center gap-3">
            <div class="text-sm text-slate-600">
              商品 ID: {{ orderItem.prodId }} | SKU: {{ orderItem.skuId }} | 数量: {{ orderItem.prodCount }}
            </div>
          </div>

          <!-- 购物车结算 -->
          <div v-else-if="orderItem?.shopCartItems?.length">
            <div
              v-for="item in orderItem.shopCartItems"
              :key="item.basketId"
              class="flex items-center gap-3 py-2 border-b border-slate-50 last:border-0"
            >
              <div class="flex-1 min-w-0">
                <p class="text-sm text-slate-700 truncate">{{ item.prodName }}</p>
                <p v-if="item.skuName" class="text-xs text-slate-400">{{ item.skuName }}</p>
              </div>
              <div class="text-right shrink-0">
                <p class="text-sm text-rose-500 font-medium">¥{{ Number(item.productPrice).toFixed(2) }}</p>
                <p class="text-xs text-slate-400">x{{ item.prodCount }}</p>
              </div>
            </div>
          </div>
        </section>

        <!-- 支付方式 -->
        <section class="bg-white rounded-xl shadow-sm p-5 mb-3">
          <h3 class="text-sm font-medium text-slate-700 mb-3">支付方式</h3>
          <div class="space-y-2">
            <label class="flex items-center gap-3 cursor-pointer p-2 rounded-lg hover:bg-slate-50 transition-colors">
              <input
                type="radio"
                :value="1"
                v-model="paymentType"
                class="text-brand-600 focus:ring-brand-500"
              />
              <span class="text-sm text-slate-700">微信支付</span>
            </label>
            <label class="flex items-center gap-3 cursor-pointer p-2 rounded-lg hover:bg-slate-50 transition-colors">
              <input
                type="radio"
                :value="2"
                v-model="paymentType"
                class="text-brand-600 focus:ring-brand-500"
              />
              <span class="text-sm text-slate-700">支付宝</span>
            </label>
          </div>
        </section>

        <!-- 价格汇总 -->
        <section class="bg-white rounded-xl shadow-sm p-5 mb-24">
          <div class="space-y-2 text-sm">
            <div class="flex justify-between text-slate-500">
              <span>商品金额</span>
              <span>¥{{ Number(orderItem?.total || 0).toFixed(2) }}</span>
            </div>
            <div class="flex justify-between text-slate-500">
              <span>运费</span>
              <span>免运费</span>
            </div>
            <div class="flex justify-between font-medium text-slate-800 pt-2 border-t border-slate-100">
              <span>合计</span>
              <span class="text-rose-500 text-lg">¥{{ Number(orderItem?.total || 0).toFixed(2) }}</span>
            </div>
          </div>
        </section>

        <!-- 提交按钮 -->
        <div class="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 z-40">
          <div class="max-w-4xl mx-auto px-4 h-16 flex items-center justify-end gap-4">
            <span class="text-sm text-slate-500">
              合计：
              <span class="text-rose-500 font-bold text-lg">¥{{ Number(orderItem?.total || 0).toFixed(2) }}</span>
            </span>
            <button
              class="px-10 h-10 rounded-lg text-sm font-medium bg-rose-500 text-white hover:bg-rose-600 disabled:opacity-50 transition-colors"
              :disabled="submitting || !selectedAddress"
              @click="submitOrder"
            >
              {{ submitting ? '提交中...' : '提交订单' }}
            </button>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
