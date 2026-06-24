<script setup>
import { ref, computed } from 'vue'
import { useRoute, useRouter } from 'vue-router'

const route = useRoute()
const router = useRouter()

const orderId = route.query.orderId || ''
const amount = route.query.amount || '0'
const isSuccess = ref(true) // 简化：默认成功，实际应根据 API 判断

function goOrderDetail() {
  router.push(`/orders/${orderId}`)
}

function goHome() {
  router.push('/')
}
</script>

<template>
  <div class="min-h-screen bg-slate-50 flex items-center justify-center">
    <div class="max-w-md w-full mx-4">
      <div class="bg-white rounded-2xl shadow-sm p-8 text-center">
        <!-- 图标 -->
        <div
          class="w-20 h-20 mx-auto mb-5 rounded-full flex items-center justify-center"
          :class="isSuccess ? 'bg-emerald-50' : 'bg-rose-50'"
        >
          <svg
            v-if="isSuccess"
            class="w-10 h-10 text-emerald-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <svg
            v-else
            class="w-10 h-10 text-rose-500"
            fill="none"
            stroke="currentColor"
            viewBox="0 0 24 24"
          >
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M10 14l2-2m0 0l2-2m-2 2l-2-2m2 2l2 2m7-2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>

        <!-- 状态文字 -->
        <h2 class="text-xl font-semibold" :class="isSuccess ? 'text-slate-800' : 'text-rose-500'">
          {{ isSuccess ? '支付成功' : '支付失败' }}
        </h2>
        <p class="text-sm text-slate-400 mt-2">
          {{ isSuccess ? '您的订单已支付成功，我们会尽快为您发货' : '支付遇到问题，请重试或换个支付方式' }}
        </p>

        <!-- 金额 -->
        <div class="mt-6 p-4 bg-slate-50 rounded-xl">
          <p class="text-sm text-slate-500">支付金额</p>
          <p class="text-2xl font-bold text-rose-500 mt-1">¥{{ Number(amount).toFixed(2) }}</p>
        </div>

        <!-- 订单号 -->
        <p v-if="orderId" class="text-xs text-slate-400 mt-4">订单号：{{ orderId }}</p>

        <!-- 操作按钮 -->
        <div class="mt-8 flex flex-col gap-3">
          <button
            v-if="isSuccess"
            class="w-full h-11 rounded-xl text-sm font-medium bg-brand-600 text-white hover:bg-brand-700 transition-colors"
            @click="goOrderDetail"
          >
            查看订单
          </button>
          <button
            v-if="!isSuccess"
            class="w-full h-11 rounded-xl text-sm font-medium bg-rose-500 text-white hover:bg-rose-600 transition-colors"
            @click="goOrderDetail"
          >
            重新支付
          </button>
          <button
            class="w-full h-11 rounded-xl text-sm font-medium text-slate-600 border border-slate-200 hover:bg-slate-50 transition-colors"
            @click="goHome"
          >
            返回首页
          </button>
        </div>
      </div>
    </div>
  </div>
</template>
