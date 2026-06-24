<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { orderApi } from '@/api/order'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const route = useRoute()
const router = useRouter()

const deliveryInfo = ref(null)
const loading = ref(true)

const orderId = computed(() => route.params.id)

async function fetchLogistics() {
  loading.value = true
  try {
    const res = await orderApi.getDelivery(orderId.value)
    deliveryInfo.value = res.data
  } catch (err) {
    console.error('加载物流信息失败:', err)
  } finally {
    loading.value = false
  }
}

onMounted(fetchLogistics)
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-3xl mx-auto px-4 py-6">
      <h1 class="text-xl font-bold text-slate-800 mb-6">物流查询</h1>

      <LoadingSpinner v-if="loading" />

      <template v-if="deliveryInfo">
        <!-- 物流公司 + 单号 -->
        <div class="bg-white rounded-xl shadow-sm p-5 mb-4">
          <div class="flex items-center justify-between mb-3">
            <div>
              <p class="text-sm text-slate-500">承运公司</p>
              <p class="text-sm font-medium text-slate-800">{{ deliveryInfo.companyName || '暂无' }}</p>
            </div>
            <div class="text-right">
              <p class="text-sm text-slate-500">运单编号</p>
              <p class="text-sm font-medium text-slate-800">{{ deliveryInfo.deliveryId || '暂无' }}</p>
            </div>
          </div>
        </div>

        <!-- 物流时间线 -->
        <div class="bg-white rounded-xl shadow-sm p-5">
          <h3 class="text-sm font-medium text-slate-700 mb-4">物流详情</h3>

          <div v-if="deliveryInfo.tracks?.length" class="relative">
            <!-- 竖线 -->
            <div class="absolute left-[7px] top-2 bottom-2 w-0.5 bg-slate-200" />

            <!-- 时间线项 -->
            <div
              v-for="(track, idx) in deliveryInfo.tracks"
              :key="idx"
              class="relative flex gap-4 pb-6 last:pb-0"
            >
              <!-- 圆点 -->
              <div
                class="relative z-10 mt-1 w-[16px] h-[16px] rounded-full border-2 shrink-0 flex items-center justify-center"
                :class="idx === 0
                  ? 'border-brand-500 bg-brand-500'
                  : 'border-slate-300 bg-white'"
              >
                <div v-if="idx === 0" class="w-[6px] h-[6px] rounded-full bg-white" />
              </div>

              <!-- 内容 -->
              <div class="flex-1 min-w-0">
                <p
                  class="text-sm"
                  :class="idx === 0 ? 'text-slate-800 font-medium' : 'text-slate-500'"
                >
                  {{ track.msg || track.status || '暂无信息' }}
                </p>
                <p class="text-xs text-slate-400 mt-0.5">{{ track.time || '' }}</p>
              </div>
            </div>
          </div>

          <div v-else class="py-8 text-center text-sm text-slate-400">
            暂无物流信息
          </div>
        </div>
      </template>

      <!-- 无数据 -->
      <div v-if="!loading && !deliveryInfo" class="py-16 text-center text-sm text-slate-400">
        暂无物流信息
      </div>
    </div>
  </div>
</template>
