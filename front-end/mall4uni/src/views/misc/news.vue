<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { homeApi } from '@/api/home'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'
import EmptyState from '@/components/common/EmptyState.vue'

const router = useRouter()
const notices = ref([])
const loading = ref(true)

async function fetchNotices() {
  loading.value = true
  try {
    const res = await homeApi.getNotices()
    notices.value = res.data || []
  } catch (err) {
    console.error('加载公告失败:', err)
  } finally {
    loading.value = false
  }
}

function goDetail(id) {
  router.push(`/news/${id}`)
}

onMounted(fetchNotices)
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-3xl mx-auto px-4 py-6">
      <h1 class="text-xl font-bold text-slate-800 mb-6">最新公告</h1>

      <LoadingSpinner v-if="loading" />
      <EmptyState v-else-if="!notices.length" message="暂无公告" />

      <div v-else class="space-y-2">
        <div
          v-for="notice in notices"
          :key="notice.id"
          class="bg-white rounded-xl shadow-sm p-4 cursor-pointer hover:shadow-card-hover transition-shadow"
          @click="goDetail(notice.id)"
        >
          <div class="flex items-start justify-between gap-4">
            <div class="flex items-center gap-2 min-w-0">
              <span class="w-1.5 h-1.5 rounded-full bg-rose-400 shrink-0 mt-2" />
              <p class="text-sm text-slate-700 line-clamp-1">{{ notice.title }}</p>
            </div>
            <svg class="w-4 h-4 text-slate-300 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
            </svg>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
