<script setup>
import { ref, onMounted, watch } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { searchApi } from '@/api/search'
import ProductGrid from '@/components/product/ProductGrid.vue'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const route = useRoute()
const router = useRouter()

const products = ref([])
const loading = ref(true)
const sortBy = ref('') // '' | 'sale' | 'price' | 'time'
const sortOrder = ref('asc')
const viewMode = ref('grid') // grid | list
const currentPage = ref(1)
const totalPages = ref(1)
const keyword = ref('')

async function fetchResults() {
  keyword.value = route.query.q || ''
  if (!keyword.value) return

  loading.value = true
  try {
    const params = {
      current: currentPage.value,
      size: 20,
      sort: sortBy.value || undefined,
      order: sortBy.value ? sortOrder.value : undefined
    }
    const res = await searchApi.searchProducts(params)
    products.value = res.data?.records || []
    totalPages.value = res.data?.pages || 1
  } catch (err) {
    console.error('搜索失败:', err)
    products.value = []
  } finally {
    loading.value = false
  }
}

function setSort(field) {
  if (sortBy.value === field) {
    sortOrder.value = sortOrder.value === 'asc' ? 'desc' : 'asc'
  } else {
    sortBy.value = field
    sortOrder.value = 'asc'
  }
  currentPage.value = 1
  fetchResults()
}

function toggleView() {
  viewMode.value = viewMode.value === 'grid' ? 'list' : 'grid'
}

function prevPage() {
  if (currentPage.value > 1) {
    currentPage.value--
    fetchResults()
  }
}

function nextPage() {
  if (currentPage.value < totalPages.value) {
    currentPage.value++
    fetchResults()
  }
}

watch(() => route.query.q, () => {
  currentPage.value = 1
  fetchResults()
})

onMounted(fetchResults)
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-7xl mx-auto px-4 py-6">
      <!-- 搜索词 + 结果数 -->
      <div class="flex items-center justify-between mb-4">
        <div>
          <span class="text-sm text-slate-500">
            搜索 "<span class="text-slate-800 font-medium">{{ keyword }}</span>"
          </span>
          <span v-if="!loading" class="text-sm text-slate-400 ml-2">
            共 {{ products.length }} 个结果
          </span>
        </div>
        <button class="text-sm text-brand-600 hover:text-brand-700" @click="router.push('/search')">
          重新搜索
        </button>
      </div>

      <!-- 排序 + 视图切换 -->
      <div class="bg-white rounded-xl shadow-sm p-3 mb-4 flex items-center justify-between">
        <div class="flex items-center gap-1">
          <button
            class="px-3 py-1.5 text-sm rounded-lg transition-colors"
            :class="!sortBy ? 'bg-brand-50 text-brand-600 font-medium' : 'text-slate-500 hover:bg-slate-50'"
            @click="sortBy = ''; currentPage = 1; fetchResults()"
          >
            综合
          </button>
          <button
            class="px-3 py-1.5 text-sm rounded-lg transition-colors"
            :class="sortBy === 'sale' ? 'bg-brand-50 text-brand-600 font-medium' : 'text-slate-500 hover:bg-slate-50'"
            @click="setSort('sale')"
          >
            销量
          </button>
          <button
            class="px-3 py-1.5 text-sm rounded-lg transition-colors flex items-center gap-1"
            :class="sortBy === 'price' ? 'bg-brand-50 text-brand-600 font-medium' : 'text-slate-500 hover:bg-slate-50'"
            @click="setSort('price')"
          >
            价格
            <svg v-if="sortBy === 'price'" class="w-3 h-3" :class="sortOrder === 'asc' ? '' : 'rotate-180'" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
            </svg>
          </button>
          <button
            class="px-3 py-1.5 text-sm rounded-lg transition-colors"
            :class="sortBy === 'time' ? 'bg-brand-50 text-brand-600 font-medium' : 'text-slate-500 hover:bg-slate-50'"
            @click="setSort('time')"
          >
            新品
          </button>
        </div>

        <!-- 视图切换 -->
        <div class="flex items-center border border-slate-200 rounded-lg overflow-hidden">
          <button
            class="p-1.5 transition-colors"
            :class="viewMode === 'grid' ? 'bg-brand-50 text-brand-600' : 'text-slate-400 hover:bg-slate-50'"
            @click="viewMode = 'grid'"
          >
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 16 16">
              <path d="M1 2.5A1.5 1.5 0 012.5 1h3A1.5 1.5 0 017 2.5v3A1.5 1.5 0 015.5 7h-3A1.5 1.5 0 011 5.5v-3zM2.5 2a.5.5 0 00-.5.5v3a.5.5 0 00.5.5h3a.5.5 0 00.5-.5v-3a.5.5 0 00-.5-.5h-3zm6.5.5A1.5 1.5 0 0110.5 1h3A1.5 1.5 0 0115 2.5v3A1.5 1.5 0 0113.5 7h-3A1.5 1.5 0 019 5.5v-3zm1.5-.5a.5.5 0 00-.5.5v3a.5.5 0 00.5.5h3a.5.5 0 00.5-.5v-3a.5.5 0 00-.5-.5h-3zM1 10.5A1.5 1.5 0 012.5 9h3A1.5 1.5 0 017 10.5v3A1.5 1.5 0 015.5 15h-3A1.5 1.5 0 011 13.5v-3zm1.5-.5a.5.5 0 00-.5.5v3a.5.5 0 00.5.5h3a.5.5 0 00.5-.5v-3a.5.5 0 00-.5-.5h-3zm6.5.5A1.5 1.5 0 0110.5 9h3a1.5 1.5 0 011.5 1.5v3a1.5 1.5 0 01-1.5 1.5h-3A1.5 1.5 0 019 13.5v-3zm1.5-.5a.5.5 0 00-.5.5v3a.5.5 0 00.5.5h3a.5.5 0 00.5-.5v-3a.5.5 0 00-.5-.5h-3z" />
            </svg>
          </button>
          <button
            class="p-1.5 transition-colors border-l border-slate-200"
            :class="viewMode === 'list' ? 'bg-brand-50 text-brand-600' : 'text-slate-400 hover:bg-slate-50'"
            @click="viewMode = 'list'"
          >
            <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 16 16">
              <path fill-rule="evenodd" d="M2.5 12a.5.5 0 01.5-.5h10a.5.5 0 010 1H3a.5.5 0 01-.5-.5zm0-4a.5.5 0 01.5-.5h10a.5.5 0 010 1H3a.5.5 0 01-.5-.5zm0-4a.5.5 0 01.5-.5h10a.5.5 0 010 1H3a.5.5 0 01-.5-.5z" />
            </svg>
          </button>
        </div>
      </div>

      <!-- 商品列表 -->
      <LoadingSpinner v-if="loading" />
      <ProductGrid
        v-else-if="products.length"
        :products="products"
        :mode="viewMode"
        :animated="false"
      />

      <!-- 空结果 -->
      <div v-if="!loading && !products.length" class="py-20 text-center">
        <svg class="w-16 h-16 mx-auto text-slate-200 mb-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
        <p class="text-sm text-slate-400">未找到相关商品</p>
      </div>

      <!-- 分页 -->
      <div v-if="totalPages > 1" class="flex items-center justify-center gap-3 mt-8">
        <button
          class="px-4 py-2 text-sm rounded-lg border border-slate-200 hover:bg-slate-50 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
          :disabled="currentPage <= 1"
          @click="prevPage"
        >
          上一页
        </button>
        <span class="text-sm text-slate-500">{{ currentPage }} / {{ totalPages }}</span>
        <button
          class="px-4 py-2 text-sm rounded-lg border border-slate-200 hover:bg-slate-50 disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
          :disabled="currentPage >= totalPages"
          @click="nextPage"
        >
          下一页
        </button>
      </div>
    </div>
  </div>
</template>
