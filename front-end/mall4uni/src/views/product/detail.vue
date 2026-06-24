<script setup>
import { ref, computed, onMounted } from 'vue'
import { useRoute, useRouter } from 'vue-router'
import gsap from 'gsap'
import { productApi } from '@/api/product'
import { cartApi } from '@/api/cart'
import { useAppStore } from '@/stores/app'
import { useUserStore } from '@/stores/user'
import PriceDisplay from '@/components/product/PriceDisplay.vue'
import ImageWithFallback from '@/components/common/ImageWithFallback.vue'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const route = useRoute()
const router = useRouter()
const appStore = useAppStore()
const userStore = useUserStore()

const product = ref(null)
const imgs = ref([])
const content = ref('')
const loading = ref(true)
const isCollected = ref(false)
const prodNum = ref(1)
const currentImgIndex = ref(0)

// SKU 相关
const skuList = ref([])
const skuGroupList = ref([])
const selectedPropObj = ref({})
const selectedPropStr = ref('')
const currentSku = ref(null)
const showSkuPanel = ref(false)

const prodId = computed(() => route.params.id)

async function fetchProduct() {
  loading.value = true
  try {
    const res = await productApi.getDetail(prodId.value)
    const data = res.data
    product.value = data
    imgs.value = data.imgs?.split(',') || []
    content.value = data.content || ''
    skuList.value = data.skuList || []
    buildSkuGroups()

    // 检查收藏
    if (userStore.isLoggedIn) {
      const colRes = await productApi.isCollected(prodId.value)
      isCollected.value = colRes.data
    }
  } catch (err) {
    console.error('加载商品失败:', err)
  } finally {
    loading.value = false
  }
}

function buildSkuGroups() {
  const groupMap = {}
  const selected = {}
  let first = true

  for (const sku of skuList.value) {
    if (!sku.properties) {
      // 没有多规格，单SKU
      currentSku.value = sku
      return
    }
    const propsList = sku.properties.split(';')
    for (const p of propsList) {
      const [key, val] = p.split(':')
      if (!groupMap[key]) groupMap[key] = []
      if (!groupMap[key].includes(val)) groupMap[key].push(val)
      if (first) selected[key] = val
    }
    first = false
  }

  skuGroupList.value = Object.entries(groupMap).map(([key, vals]) => ({
    key,
    values: vals
  }))
  selectedPropObj.value = selected
  selectedPropStr.value = Object.values(selected).join(', ')

  // 查找匹配的SKU
  findSku()
}

function selectProp(key, val) {
  selectedPropObj.value[key] = val
  selectedPropStr.value = Object.values(selectedPropObj.value).join(', ')
  findSku()
}

function findSku() {
  const propsStr = skuGroupList.value
    .map(g => `${g.key}:${selectedPropObj.value[g.key] || ''}`)
    .join(';')

  const matched = skuList.value.find(s => s.properties === propsStr)
  if (matched) {
    currentSku.value = matched
  }
}

async function addToCart() {
  if (!currentSku.value) return
  try {
    await cartApi.changeItem({
      basketId: 0,
      count: prodNum.value,
      prodId: prodId.value,
      shopId: 1,
      skuId: currentSku.value.skuId
    })
    appStore.refreshCartCount()
    // GSAP 飞入动画（找购物车图标位置）
    flyToCart()
  } catch (err) {
    console.error('加购失败:', err)
  }
}

function flyToCart() {
  const btn = document.querySelector('.cart-btn')
  const cartIcon = document.querySelector('.cart-icon-wrapper')
  if (!btn || !cartIcon) return

  const btnRect = btn.getBoundingClientRect()
  const cartRect = cartIcon.getBoundingClientRect()

  // 创建飞行元素
  const flyer = document.createElement('div')
  flyer.className = 'fixed w-8 h-8 rounded-full bg-brand-500 z-[999] pointer-events-none'
  flyer.style.left = btnRect.left + btnRect.width / 2 - 16 + 'px'
  flyer.style.top = btnRect.top + 'px'

  document.body.appendChild(flyer)

  gsap.to(flyer, {
    x: cartRect.left - btnRect.left - btnRect.width / 2 + cartRect.width / 2,
    y: cartRect.top - btnRect.top - 20,
    scale: 0.2,
    opacity: 0.6,
    duration: 0.6,
    ease: 'power3.in',
    onComplete: () => {
      flyer.remove()
    }
  })
}

async function buyNow() {
  if (!currentSku.value) return
  // 存到sessionStorage，结算页读取
  sessionStorage.setItem('orderItem', JSON.stringify({
    prodId: prodId.value,
    skuId: currentSku.value.skuId,
    prodCount: prodNum.value,
    shopId: 1
  }))
  router.push('/checkout?orderEntry=1')
}

async function toggleCollection() {
  if (!userStore.isLoggedIn) {
    router.push('/login')
    return
  }
  try {
    await productApi.toggleCollection(prodId.value)
    isCollected.value = !isCollected.value
  } catch (err) {
    console.error('收藏操作失败:', err)
  }
}

function goHome() {
  router.push('/')
}

function goCart() {
  router.push('/cart')
}

function formatRichText(html) {
  if (!html) return ''
  // 简单的图片适配处理
  return html.replace(/<img /g, '<img style="max-width:100%;height:auto" ')
}

onMounted(() => {
  fetchProduct()
})
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <LoadingSpinner v-if="loading" />

    <template v-if="product">
      <!-- 图片轮播 -->
      <section class="bg-white">
        <div class="max-w-5xl mx-auto">
          <div class="relative">
            <!-- 大图 -->
            <div class="aspect-[4/3] lg:aspect-[16/9] bg-slate-100 overflow-hidden">
              <ImageWithFallback
                :src="imgs[currentImgIndex] || product.pic"
                class="w-full h-full object-cover"
              />
            </div>
            <!-- 缩略图导航 -->
            <div v-if="imgs.length > 1" class="flex gap-2 px-4 py-3 overflow-x-auto">
              <button
                v-for="(img, idx) in imgs"
                :key="idx"
                class="w-16 h-16 shrink-0 rounded-lg overflow-hidden border-2 transition-colors"
                :class="currentImgIndex === idx ? 'border-brand-500' : 'border-transparent hover:border-slate-300'"
                @click="currentImgIndex = idx"
              >
                <ImageWithFallback
                  :src="img"
                  class="w-full h-full object-cover"
                />
              </button>
            </div>
          </div>
        </div>
      </section>

      <!-- 商品信息 -->
      <section class="bg-white mt-2">
        <div class="max-w-5xl mx-auto px-6 py-5">
          <!-- 价格 -->
          <div class="flex items-baseline gap-3 mb-3">
            <PriceDisplay
              :price="currentSku?.price || product.price"
              size="lg"
            />
            <span v-if="currentSku?.oriPrice" class="text-sm text-slate-300 line-through">
              ¥{{ Number(currentSku.oriPrice).toFixed(2) }}
            </span>
          </div>

          <!-- 标题 + 收藏 -->
          <div class="flex items-start justify-between gap-4">
            <div class="flex-1 min-w-0">
              <h1 class="text-xl font-semibold text-slate-900 leading-snug">{{ product.prodName }}</h1>
              <p v-if="product.brief" class="text-sm text-slate-500 mt-1">{{ product.brief }}</p>
            </div>
            <button
              class="flex flex-col items-center gap-0.5 shrink-0 text-slate-400 hover:text-rose-500 transition-colors"
              @click="toggleCollection"
            >
              <svg class="w-6 h-6" :class="isCollected ? 'text-rose-500 fill-rose-500' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
              </svg>
              <span class="text-xs">{{ isCollected ? '已收藏' : '收藏' }}</span>
            </button>
          </div>
        </div>
      </section>

      <!-- 已选规格入口 -->
      <section class="bg-white mt-2">
        <div class="max-w-5xl mx-auto px-6 py-4">
          <button
            class="w-full flex items-center justify-between text-left"
            @click="showSkuPanel = !showSkuPanel"
          >
            <div class="flex items-center gap-6">
              <span class="text-sm text-slate-400 shrink-0">已选</span>
              <span class="text-sm text-slate-700">
                {{ selectedPropStr || '请选择规格' }}
                {{ prodNum > 1 ? `，${prodNum}件` : '' }}
              </span>
            </div>
            <svg class="w-4 h-4 text-slate-400 transition-transform" :class="showSkuPanel ? 'rotate-180' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
            </svg>
          </button>

          <!-- 展开的 SKU 选择面板 -->
          <Transition name="slide">
            <div v-if="showSkuPanel" class="mt-4 pt-4 border-t border-slate-100 space-y-4">
              <div v-for="group in skuGroupList" :key="group.key">
                <p class="text-sm font-medium text-slate-700 mb-2">{{ group.key }}</p>
                <div class="flex flex-wrap gap-2">
                  <button
                    v-for="val in group.values"
                    :key="val"
                    class="px-4 py-1.5 text-sm rounded-lg border transition-colors"
                    :class="selectedPropObj[group.key] === val
                      ? 'border-brand-500 bg-brand-50 text-brand-600'
                      : 'border-slate-200 text-slate-600 hover:border-slate-300'"
                    @click="selectProp(group.key, val)"
                  >
                    {{ val }}
                  </button>
                </div>
              </div>

              <!-- 数量选择 -->
              <div class="flex items-center justify-between">
                <span class="text-sm text-slate-600">数量</span>
                <div class="flex items-center gap-3">
                  <button
                    class="w-8 h-8 flex items-center justify-center rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-50 disabled:opacity-30"
                    :disabled="prodNum <= 1"
                    @click="prodNum > 1 && prodNum--"
                  >
                    −
                  </button>
                  <span class="w-8 text-center text-sm font-medium">{{ prodNum }}</span>
                  <button
                    class="w-8 h-8 flex items-center justify-center rounded-lg border border-slate-200 text-slate-500 hover:bg-slate-50 disabled:opacity-30"
                    :disabled="prodNum >= 999"
                    @click="prodNum < 999 && prodNum++"
                  >
                    +
                  </button>
                </div>
              </div>
            </div>
          </Transition>
        </div>
      </section>

      <!-- 商品详情（富文本） -->
      <section class="bg-white mt-2 mb-24">
        <div class="max-w-5xl mx-auto">
          <div class="px-6 py-4 border-b border-slate-100">
            <h3 class="text-base font-semibold text-slate-800">商品详情</h3>
          </div>
          <div class="px-6 py-6 prose prose-sm max-w-none" v-html="formatRichText(content)" />
        </div>
      </section>
    </template>

    <!-- 底部固定操作栏 -->
    <div class="fixed bottom-0 left-0 right-0 bg-white border-t border-slate-200 z-40">
      <div class="max-w-5xl mx-auto px-4 h-16 flex items-center gap-3">
        <button
          class="flex flex-col items-center gap-0.5 text-slate-500 hover:text-brand-600 transition-colors min-w-[48px]"
          @click="goHome"
        >
          <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 12l2-2m0 0l7-7 7 7M5 10v10a1 1 0 001 1h3m10-11l2 2m-2-2v10a1 1 0 01-1 1h-3m-6 0a1 1 0 001-1v-4a1 1 0 011-1h2a1 1 0 011 1v4a1 1 0 001 1m-6 0h6" />
          </svg>
          <span class="text-[10px]">首页</span>
        </button>

        <div class="relative cart-icon-wrapper">
          <button
            class="flex flex-col items-center gap-0.5 text-slate-500 hover:text-brand-600 transition-colors min-w-[48px]"
            @click="goCart"
          >
            <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M3 3h2l.4 2M7 13h10l4-8H5.4M7 13L5.4 5M7 13l-2.293 2.293c-.63.63-.184 1.707.707 1.707H17m0 0a2 2 0 100 4 2 2 0 000-4zm-8 2a2 2 0 100 4 2 2 0 000-4z" />
            </svg>
            <span class="text-[10px]">购物车</span>
            <span
              v-if="appStore.cartCount > 0"
              class="absolute -top-1 -right-1 w-4 h-4 flex items-center justify-center bg-rose-500 text-white text-[9px] font-bold rounded-full"
            >
              {{ appStore.cartCount > 99 ? '99+' : appStore.cartCount }}
            </span>
          </button>
        </div>

        <button
          class="flex flex-col items-center gap-0.5 text-slate-500 hover:text-rose-500 transition-colors min-w-[48px]"
          @click="toggleCollection"
        >
          <svg class="w-5 h-5" :class="isCollected ? 'text-rose-500 fill-rose-500' : ''" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4.318 6.318a4.5 4.5 0 000 6.364L12 20.364l7.682-7.682a4.5 4.5 0 00-6.364-6.364L12 7.636l-1.318-1.318a4.5 4.5 0 00-6.364 0z" />
          </svg>
          <span class="text-[10px]">{{ isCollected ? '已收藏' : '收藏' }}</span>
        </button>

        <div class="flex-1 flex gap-2">
          <button
            class="cart-btn flex-1 h-10 rounded-lg text-sm font-medium bg-brand-50 text-brand-600 hover:bg-brand-100 transition-colors"
            @click="addToCart"
          >
            加入购物车
          </button>
          <button
            class="flex-1 h-10 rounded-lg text-sm font-medium bg-rose-500 text-white hover:bg-rose-600 transition-colors"
            @click="buyNow"
          >
            立即购买
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<style scoped>
.slide-enter-active, .slide-leave-active {
  transition: all 0.2s ease;
}
.slide-enter-from, .slide-leave-to {
  opacity: 0;
  max-height: 0;
  padding-top: 0;
  padding-bottom: 0;
}
</style>
