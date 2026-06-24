<script setup>
import { ref, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import { homeApi } from '@/api/home'
import ProductGrid from '@/components/product/ProductGrid.vue'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const route = useRoute()
const router = useRouter()

const products = ref([])
const loading = ref(true)
const title = ref('')

async function fetchProducts() {
  loading.value = true
  const tagId = route.query.tagid
  title.value = route.query.title || '商品列表'

  try {
    if (tagId) {
      const res = await homeApi.getProductsByTag(tagId, 20)
      products.value = res.data?.records || []
    }
  } catch (err) {
    console.error('加载商品列表失败:', err)
  } finally {
    loading.value = false
  }
}

onMounted(fetchProducts)
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-7xl mx-auto px-4 py-6">
      <div class="flex items-center gap-2 text-sm text-slate-400 mb-4">
        <a href="/" class="hover:text-brand-600" @click.prevent="router.push('/')">首页</a>
        <span>/</span>
        <span class="text-slate-600">{{ title }}</span>
      </div>

      <h2 class="text-xl font-bold text-slate-800 mb-6">{{ title }}</h2>

      <LoadingSpinner v-if="loading" />
      <ProductGrid
        v-else-if="products.length"
        :products="products"
        mode="grid"
        :animated="true"
      />
      <div v-else class="py-16 text-center text-slate-400 text-sm">
        暂无商品
      </div>
    </div>
  </div>
</template>
