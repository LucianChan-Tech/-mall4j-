<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { homeApi } from '@/api/home'
import { orderApi } from '@/api/order'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const route = useRoute()
const router = useRouter()

const content = ref('')
const loading = ref(true)

async function fetchDetail() {
  loading.value = true
  try {
    // 公告详情从 /shop/notice/info/{id} 获取
    const noticeId = route.params.id
    const res = await homeApi.getNotices()
    // 从列表中找到对应公告
    const notice = (res.data || []).find(n => String(n.id) === String(noticeId))
    content.value = notice?.content || notice?.title || '暂无内容'
  } catch (err) {
    console.error('加载公告详情失败:', err)
    content.value = '加载失败'
  } finally {
    loading.value = false
  }
}

onMounted(fetchDetail)
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-3xl mx-auto px-4 py-6">
      <LoadingSpinner v-if="loading" />

      <div v-else class="bg-white rounded-xl shadow-sm p-6">
        <div
          class="prose prose-sm max-w-none text-slate-700 leading-relaxed"
          v-html="content"
        />
      </div>
    </div>
  </div>
</template>
