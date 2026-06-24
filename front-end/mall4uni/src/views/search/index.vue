<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { searchApi } from '@/api/search'

const router = useRouter()
const keyword = ref('')
const hotSearches = ref([])
const searchHistory = ref([])

function loadHistory() {
  try {
    const saved = localStorage.getItem('searchHistory')
    searchHistory.value = saved ? JSON.parse(saved) : []
  } catch {
    searchHistory.value = []
  }
}

function saveHistory(keyword) {
  if (!keyword.trim()) return
  let history = [keyword.trim(), ...searchHistory.value.filter(h => h !== keyword.trim())]
  if (history.length > 10) history = history.slice(0, 10)
  searchHistory.value = history
  localStorage.setItem('searchHistory', JSON.stringify(history))
}

function doSearch(key) {
  const q = (key || keyword.value).trim()
  if (!q) return
  saveHistory(q)
  router.push({ path: '/search/result', query: { q } })
}

function clearHistory() {
  searchHistory.value = []
  localStorage.removeItem('searchHistory')
}

function onKeydown(e) {
  if (e.key === 'Enter') doSearch()
}

onMounted(async () => {
  loadHistory()
  try {
    const res = await searchApi.getHotSearch()
    hotSearches.value = res.data || []
  } catch {
    // ignore
  }
})
</script>

<template>
  <div class="min-h-screen bg-white">
    <div class="max-w-3xl mx-auto px-4 pt-8">
      <!-- 搜索框 -->
      <div class="relative mb-8">
        <svg class="absolute left-4 top-1/2 -translate-y-1/2 w-5 h-5 text-slate-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <input
          v-model="keyword"
          type="text"
          placeholder="搜索商品"
          class="w-full h-12 pl-12 pr-4 bg-slate-100 rounded-xl text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:bg-white transition-all"
          @keydown="onKeydown"
        />
        <button
          class="absolute right-2 top-1/2 -translate-y-1/2 px-4 h-8 rounded-lg bg-brand-600 text-white text-sm font-medium hover:bg-brand-700 transition-colors"
          @click="doSearch()"
        >
          搜索
        </button>
      </div>

      <!-- 热搜 -->
      <div v-if="hotSearches.length" class="mb-8">
        <h3 class="text-sm font-medium text-slate-800 mb-3">热门搜索</h3>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="item in hotSearches"
            :key="item"
            class="px-3 py-1.5 text-sm rounded-full bg-slate-100 text-slate-600 hover:bg-brand-50 hover:text-brand-600 transition-colors"
            @click="doSearch(item)"
          >
            {{ item }}
          </button>
        </div>
      </div>

      <!-- 搜索历史 -->
      <div v-if="searchHistory.length">
        <div class="flex items-center justify-between mb-3">
          <h3 class="text-sm font-medium text-slate-800">搜索历史</h3>
          <button class="text-xs text-slate-400 hover:text-slate-600 transition-colors" @click="clearHistory">
            清除历史
          </button>
        </div>
        <div class="flex flex-wrap gap-2">
          <button
            v-for="item in searchHistory"
            :key="item"
            class="px-3 py-1.5 text-sm rounded-full bg-slate-50 text-slate-500 hover:bg-slate-100 transition-colors"
            @click="doSearch(item)"
          >
            {{ item }}
          </button>
        </div>
      </div>

      <!-- 引导 -->
      <div v-if="!hotSearches.length && !searchHistory.length" class="py-20 text-center">
        <svg class="w-16 h-16 mx-auto text-slate-200 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <p class="text-sm text-slate-400">搜索你想要的商品</p>
      </div>
    </div>
  </div>
</template>
