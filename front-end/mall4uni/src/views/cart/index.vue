<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import gsap from 'gsap'
import { cartApi } from '@/api/cart'
import { useCartStore } from '@/stores/cart'
import { useUserStore } from '@/stores/user'
import ImageWithFallback from '@/components/common/ImageWithFallback.vue'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'
import EmptyState from '@/components/common/EmptyState.vue'

const router = useRouter()
const cartStore = useCartStore()
const userStore = useUserStore()

const loading = ref(true)
const editing = ref(false)

const isAllSelected = computed(() =>
  cartStore.items.length > 0 && cartStore.selectedIds.length === cartStore.items.length
)

function toggleSelectAll() {
  cartStore.toggleSelectAll(!isAllSelected.value)
}

function toggleSelect(basketId) {
  cartStore.toggleSelect(basketId)
}

function toggleEdit() {
  editing.value = !editing.value
}

async function updateCount(item, delta) {
  const newCount = item.prodCount + delta
  if (newCount < 1 || newCount > 999) return

  try {
    await cartStore.updateCount(
      item.basketId,
      newCount,
      item.prodId,
      item.shopId,
      item.skuId
    )
    // 计数弹动微动效
    const el = document.querySelector(`.count-${item.basketId}`)
    if (el) {
      gsap.fromTo(el, { scale: 1.2 }, { scale: 1, duration: 0.2, ease: 'elastic.out(1, 0.3)' })
    }
  } catch (err) {
    console.error('更新数量失败:', err)
  }
}

async function removeItem(basketId) {
  try {
    await cartStore.removeItem(basketId)
    await cartStore.fetchCount()
  } catch (err) {
    console.error('删除失败:', err)
  }
}

async function checkout() {
  if (!cartStore.selectedIds.length) return
  router.push('/checkout')
}

async function goProduct(prodId) {
  router.push(`/product/${prodId}`)
}

onMounted(async () => {
  if (!userStore.isLoggedIn) {
    router.push('/login')
    return
  }
  loading.value = true
  try {
    await cartStore.fetchCart()
    // 默认全选
    cartStore.toggleSelectAll(true)
  } catch (err) {
    console.error('加载购物车失败:', err)
  } finally {
    loading.value = false
  }
})
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-5xl mx-auto px-4 py-6">
      <!-- 标题栏 -->
      <div class="flex items-center justify-between mb-4">
        <h1 class="text-xl font-bold text-slate-800">购物车</h1>
        <button
          class="text-sm text-slate-500 hover:text-brand-600 transition-colors"
          @click="toggleEdit"
        >
          {{ editing ? '完成' : '管理' }}
        </button>
      </div>

      <LoadingSpinner v-if="loading" />

      <!-- 空购物车 -->
      <EmptyState
        v-else-if="!cartStore.items.length"
        message="购物车是空的，去逛逛吧"
      />

      <template v-else>
        <!-- 商品列表 -->
        <div class="space-y-3 mb-24">
          <div
            v-for="item in cartStore.items"
            :key="item.basketId"
            class="bg-white rounded-xl shadow-sm p-4 flex items-start gap-4"
          >
            <!-- 复选框 -->
            <button
              class="mt-5 w-5 h-5 rounded-full border-2 flex items-center justify-center shrink-0 transition-colors"
              :class="cartStore.selectedIds.includes(item.basketId)
                ? 'bg-brand-500 border-brand-500 text-white'
                : 'border-slate-300 hover:border-brand-400'"
              @click="toggleSelect(item.basketId)"
            >
              <svg v-if="cartStore.selectedIds.includes(item.basketId)" class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
              </svg>
            </button>

            <!-- 商品图片 -->
            <div
              class="w-20 h-20 sm:w-24 sm:h-24 shrink-0 bg-slate-50 rounded-xl overflow-hidden cursor-pointer"
              @click="goProduct(item.prodId)"
            >
              <ImageWithFallback :src="item.pic" class="w-full h-full object-cover" />
            </div>

            <!-- 商品信息 -->
            <div class="flex-1 min-w-0">
              <div class="flex justify-between">
                <h3
                  class="text-sm font-medium text-slate-800 line-clamp-2 cursor-pointer hover:text-brand-600 transition-colors"
                  @click="goProduct(item.prodId)"
                >
                  {{ item.prodName }}
                </h3>
              </div>

              <!-- 规格信息 -->
              <p v-if="item.skuName" class="text-xs text-slate-400 mt-1">{{ item.skuName }}</p>

              <!-- 价格 -->
              <p class="text-rose-500 font-bold text-sm mt-2">
                ¥{{ Number(item.productPrice).toFixed(2) }}
              </p>

              <!-- 数量控制 -->
              <div class="flex items-center justify-between mt-2">
                <div class="flex items-center border border-slate-200 rounded-lg overflow-hidden">
                  <button
                    class="w-7 h-7 flex items-center justify-center text-slate-500 hover:bg-slate-50 transition-colors disabled:opacity-30"
                    :disabled="item.prodCount <= 1"
                    @click="updateCount(item, -1)"
                  >
                    −
                  </button>
                  <span
                    :class="'count-' + item.basketId"
                    class="w-8 text-center text-xs font-medium text-slate-700 select-none"
                  >
                    {{ item.prodCount }}
                  </span>
                  <button
                    class="w-7 h-7 flex items-center justify-center text-slate-500 hover:bg-slate-50 transition-colors disabled:opacity-30"
                    :disabled="item.prodCount >= 999"
                    @click="updateCount(item, 1)"
                  >
                    +
                  </button>
                </div>

                <!-- 编辑模式：删除 -->
                <button
                  v-if="editing"
                  class="text-xs text-rose-500 hover:text-rose-600 font-medium"
                  @click="removeItem(item.basketId)"
                >
                  删除
                </button>
              </div>
            </div>
          </div>
        </div>

        <!-- 底部结算栏 -->
        <div class="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 z-40">
          <div class="max-w-5xl mx-auto px-4 h-16 flex items-center justify-between">
            <div class="flex items-center gap-3">
              <!-- 全选 -->
              <button
                class="flex items-center gap-2 text-sm"
                @click="toggleSelectAll"
              >
                <span
                  class="w-5 h-5 rounded-full border-2 flex items-center justify-center transition-colors"
                  :class="isAllSelected
                    ? 'bg-brand-500 border-brand-500 text-white'
                    : 'border-slate-300 hover:border-brand-400'"
                >
                  <svg v-if="isAllSelected" class="w-3 h-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="3" d="M5 13l4 4L19 7" />
                  </svg>
                </span>
                <span class="text-slate-600">全选</span>
              </button>

              <!-- 合计 -->
              <div class="hidden sm:block text-sm text-slate-500">
                合计：
                <span class="text-rose-500 font-bold text-lg">
                  ¥{{ cartStore.totalPrice.toFixed(2) }}
                </span>
              </div>
            </div>

            <button
              class="px-8 h-10 rounded-lg text-sm font-medium transition-colors"
              :class="cartStore.selectedIds.length
                ? 'bg-brand-600 text-white hover:bg-brand-700'
                : 'bg-slate-200 text-slate-400 cursor-not-allowed'"
              :disabled="!cartStore.selectedIds.length"
              @click="checkout"
            >
              结算 ({{ cartStore.selectedIds.length }})
            </button>
          </div>
        </div>
      </template>
    </div>
  </div>
</template>
