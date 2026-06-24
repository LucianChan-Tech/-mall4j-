<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { categoryApi } from '@/api/category'
import ProductCard from '@/components/product/ProductCard.vue'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const router = useRouter()
const categories = ref([])
const currentCategory = ref(null)
const products = ref([])
const loading = ref(true)
const prodLoading = ref(false)

async function fetchCategories() {
  loading.value = true
  try {
    const res = await categoryApi.getCategories()
    categories.value = res.data || []
    if (categories.value.length) {
      selectCategory(categories.value[0])
    }
  } catch (err) {
    console.error('加载分类失败:', err)
  } finally {
    loading.value = false
  }
}

async function selectCategory(cat) {
  currentCategory.value = cat
  prodLoading.value = true
  try {
    const res = await categoryApi.getProducts({ categoryId: cat.categoryId })
    products.value = res.data?.records || []
  } catch (err) {
    console.error('加载分类商品失败:', err)
    products.value = []
  } finally {
    prodLoading.value = false
  }
}

function goSubCategory(cat) {
  router.push(`/category/sub?categoryId=${cat.categoryId}&name=${cat.categoryName}`)
}

onMounted(fetchCategories)
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <LoadingSpinner v-if="loading" />

    <div v-else class="max-w-7xl mx-auto px-4 py-6">
      <!-- 面包屑 -->
      <div class="flex items-center gap-2 text-sm text-slate-400 mb-4">
        <a href="/" class="hover:text-brand-600" @click.prevent="router.push('/')">首页</a>
        <span>/</span>
        <span class="text-slate-600">分类商品</span>
      </div>

      <div class="flex gap-6">
        <!-- 左：分类列表 -->
        <div class="w-48 shrink-0">
          <div class="bg-white rounded-xl shadow-sm overflow-hidden">
            <div class="p-3 border-b border-slate-100">
              <h3 class="text-sm font-semibold text-slate-800">全部分类</h3>
            </div>
            <div class="divide-y divide-slate-50">
              <button
                v-for="cat in categories"
                :key="cat.categoryId"
                class="w-full text-left px-4 py-3 text-sm transition-colors"
                :class="currentCategory?.categoryId === cat.categoryId
                  ? 'bg-brand-50 text-brand-600 font-medium'
                  : 'text-slate-600 hover:bg-slate-50'"
                @click="selectCategory(cat)"
              >
                {{ cat.categoryName }}
              </button>
            </div>
          </div>
        </div>

        <!-- 右：商品列表 -->
        <div class="flex-1 min-w-0">
          <div v-if="currentCategory" class="bg-white rounded-xl shadow-sm p-4">
            <!-- 分类标题 + 子分类 -->
            <div class="flex items-center justify-between mb-4">
              <h2 class="text-lg font-semibold text-slate-800">{{ currentCategory.categoryName }}</h2>
              <button
                v-if="currentCategory.categories?.length"
                class="text-sm text-brand-600 hover:text-brand-700 flex items-center gap-1"
                @click="goSubCategory(currentCategory)"
              >
                查看全部
                <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
                </svg>
              </button>
            </div>

            <!-- 子分类标签 -->
            <div v-if="currentCategory.categories?.length" class="flex flex-wrap gap-2 mb-6">
              <button
                v-for="sub in currentCategory.categories"
                :key="sub.categoryId"
                class="px-3 py-1 text-xs rounded-full bg-slate-100 text-slate-600 hover:bg-brand-50 hover:text-brand-600 transition-colors"
                @click="goSubCategory(sub)"
              >
                {{ sub.categoryName }}
              </button>
            </div>

            <!-- 商品列表 -->
            <LoadingSpinner v-if="prodLoading" />
            <div v-else-if="products.length" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-4 gap-4">
              <ProductCard
                v-for="prod in products"
                :key="prod.prodId"
                :prod="prod"
                mode="grid"
              />
            </div>
            <div v-else class="py-12 text-center text-slate-400 text-sm">
              该分类暂无商品
            </div>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
