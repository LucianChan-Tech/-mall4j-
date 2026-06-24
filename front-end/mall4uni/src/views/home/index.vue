<script setup>
import { ref, nextTick } from 'vue'
import { useRouter } from 'vue-router'
import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'
import { homeApi } from '@/api/home'
import { useAppStore } from '@/stores/app'
import CustomSwiper from '@/components/common/CustomSwiper.vue'

import ImageWithFallback from '@/components/common/ImageWithFallback.vue'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

gsap.registerPlugin(ScrollTrigger)

const router = useRouter()
const appStore = useAppStore()

const banners = ref([])
const notices = ref([])
const tagList = ref([])
const loading = ref(true)

// 动画 ref
const newArrivalRef = ref(null)
const hotSaleRef = ref(null)

function triggerAnimations() {
  nextTick(() => {
    if (newArrivalRef.value) {
      gsap.from(newArrivalRef.value.children, {
        opacity: 0,
        y: 30,
        stagger: 0.08,
        duration: 0.5,
        ease: 'power2.out',
        scrollTrigger: {
          trigger: newArrivalRef.value,
          start: 'top 85%'
        }
      })
    }
    if (hotSaleRef.value) {
      gsap.from(hotSaleRef.value.children, {
        opacity: 0,
        y: 20,
        stagger: 0.06,
        duration: 0.4,
        ease: 'power2.out',
        scrollTrigger: {
          trigger: hotSaleRef.value,
          start: 'top 85%'
        }
      })
    }
    ScrollTrigger.refresh()
  })
}

async function fetchData() {
  loading.value = true
  try {
    const [bannerRes, noticeRes, tagRes] = await Promise.all([
      homeApi.getBanners(),
      homeApi.getNotices(),
      homeApi.getTagList()
    ])
    banners.value = bannerRes.data || []
    notices.value = noticeRes.data || []

    // 为每个 tag 加载商品
    const tags = tagRes.data || []
    for (const tag of tags) {
      try {
        const prodRes = await homeApi.getProductsByTag(tag.id, 6)
        tag.prods = prodRes.data?.records || []
      } catch {
        tag.prods = []
      }
    }
    tagList.value = tags
  } catch (err) {
    console.error('首页数据加载失败:', err)
  } finally {
    loading.value = false
    triggerAnimations()
  }
}

// 页面初始化
fetchData()

function goClassify(sts, tagId, title) {
  let path = `/product/classify?sts=${sts}`
  if (tagId) path += `&tagid=${tagId}&title=${title}`
  router.push(path)
}

function goProduct(prodId) {
  router.push(`/product/${prodId}`)
}

function goSearch() {
  router.push('/search')
}

function goCoupon() {
  // 原项目该功能未开源
  alert('该功能未开源')
}

function goNews() {
  router.push('/news')
}

function addToCart(prod) {
  // 跳转到商品详情页让用户选规格
  router.push(`/product/${prod.prodId}`)
}

// 获取商品标签类型 icon
const tagIcons = [
  { icon: 'newProd', label: '新品推荐', sts: 1 },
  { icon: 'timePrice', label: '限时特惠', sts: 1 },
  { icon: 'neweveryday', label: '每日疯抢', sts: 3 },
  { icon: 'coupon', label: '领优惠券', sts: 0 }
]
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <!-- Banner 轮播 -->
    <section class="bg-white">
      <div class="max-w-7xl mx-auto px-4 pt-4 pb-2">
        <CustomSwiper
          :images="banners"
          :height="'380px'"
          :interval="3000"
        />
      </div>
    </section>

    <!-- 分类图标入口 -->
    <section class="bg-white">
      <div class="max-w-7xl mx-auto px-4 py-5">
        <div class="grid grid-cols-4 gap-4">
          <div
            v-for="item in tagIcons"
            :key="item.label"
            class="flex flex-col items-center gap-2 cursor-pointer group"
            @click="item.label === '领优惠券' ? goCoupon() : goClassify(item.sts)"
          >
            <div class="w-14 h-14 rounded-2xl bg-brand-50 flex items-center justify-center group-hover:bg-brand-100 transition-colors">
              <svg v-if="item.label === '新品推荐'" class="w-7 h-7 text-brand-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M5 8h14M5 8a2 2 0 110-4h14a2 2 0 110 4M5 8v10a2 2 0 002 2h10a2 2 0 002-2V8m-9 4h4" />
              </svg>
              <svg v-else-if="item.label === '限时特惠'" class="w-7 h-7 text-amber-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 8v4l3 3m6-3a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <svg v-else-if="item.label === '每日疯抢'" class="w-7 h-7 text-rose-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M13 10V3L4 14h7v7l9-11h-7z" />
              </svg>
              <svg v-else class="w-7 h-7 text-emerald-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="1.5" d="M12 8c-1.657 0-3 .895-3 2s1.343 2 3 2 3 .895 3 2-1.343 2-3 2m0-8c1.11 0 2.08.402 2.599 1M12 8V7m0 1v8m0 0v1m0-1c-1.11 0-2.08-.402-2.599-1M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
            </div>
            <span class="text-xs text-slate-600 group-hover:text-brand-600 transition-colors">{{ item.label }}</span>
          </div>
        </div>
      </div>
    </section>

    <!-- 公告滚动 -->
    <section v-if="notices.length" class="bg-white border-t border-slate-100">
      <div class="max-w-7xl mx-auto px-4">
        <div
          class="flex items-center gap-3 h-12 cursor-pointer hover:bg-slate-50 -mx-4 px-4 transition-colors"
          @click="goNews"
        >
          <div class="flex items-center gap-1.5 shrink-0">
            <svg class="w-4 h-4 text-amber-400" fill="currentColor" viewBox="0 0 20 20">
              <path d="M10 1.5a5.5 5.5 0 00-5.5 5.5v1.5H3a1 1 0 00-1 1v8a1 1 0 001 1h14a1 1 0 001-1V9a1 1 0 00-1-1h-1.5V7A5.5 5.5 0 0010 1.5zM7.5 7a2.5 2.5 0 015 0v1.5h-5V7z" />
            </svg>
            <span class="text-xs text-amber-600 font-medium">公告</span>
          </div>
          <div class="flex-1 overflow-hidden">
            <div class="animate-marquee whitespace-nowrap text-sm text-slate-500">
              {{ notices.map(n => n.title).join('  •  ') }}
            </div>
          </div>
          <svg class="w-4 h-4 text-slate-300 shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
          </svg>
        </div>
      </div>
    </section>

    <!-- 商品区块 -->
    <div class="max-w-7xl mx-auto px-4 py-6 space-y-8">
      <LoadingSpinner v-if="loading" />

      <template v-for="tag in tagList" :key="tag.id">
        <!-- 每日上新 (style=2) -->
        <section v-if="tag.style === '2' && tag.prods?.length" class="bg-gradient-to-br from-brand-500 to-brand-700 rounded-2xl p-6">
          <div class="flex items-center justify-between mb-5">
            <h2 class="text-xl font-bold text-white">{{ tag.title }}</h2>
            <button
              class="text-sm text-white/80 hover:text-white flex items-center gap-1 transition-colors"
              @click="goClassify(0, tag.id, tag.title)"
            >
              查看更多
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>
          <div ref="newArrivalRef" class="grid grid-cols-2 sm:grid-cols-3 lg:grid-cols-5 gap-3">
            <div
              v-for="prod in tag.prods"
              :key="prod.prodId"
              class="bg-white rounded-xl overflow-hidden cursor-pointer hover:shadow-lg transition-shadow group"
              @click="goProduct(prod.prodId)"
            >
              <div class="aspect-square overflow-hidden bg-slate-50">
                <ImageWithFallback
                  :src="prod.pic"
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                />
              </div>
              <div class="p-2.5">
                <p class="text-xs text-slate-700 line-clamp-2 leading-relaxed mb-2">{{ prod.prodName }}</p>
                <p class="text-rose-500 font-bold text-sm">
                  ¥{{ Number(prod.price).toFixed(2) }}
                </p>
              </div>
            </div>
          </div>
        </section>

        <!-- 商城热卖 (style=1) -->
        <section v-if="tag.style === '1' && tag.prods?.length">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-bold text-slate-800">{{ tag.title }}</h2>
            <button
              class="text-sm text-brand-600 hover:text-brand-700 flex items-center gap-1 transition-colors"
              @click="goClassify(0, tag.id, tag.title)"
            >
              更多
              <svg class="w-3.5 h-3.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5l7 7-7 7" />
              </svg>
            </button>
          </div>
          <div ref="hotSaleRef" class="grid grid-cols-1 sm:grid-cols-2 gap-3">
            <div
              v-for="prod in tag.prods"
              :key="prod.prodId"
              class="bg-white rounded-xl overflow-hidden flex cursor-pointer hover:shadow-card-hover transition-shadow group"
              @click="goProduct(prod.prodId)"
            >
              <div class="w-[140px] h-[140px] shrink-0 bg-slate-50 overflow-hidden">
                <ImageWithFallback
                  :src="prod.pic"
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                />
              </div>
              <div class="flex-1 p-3 flex flex-col justify-between min-w-0">
                <div>
                  <p class="text-sm text-slate-800 line-clamp-2 leading-snug">{{ prod.prodName }}</p>
                  <p v-if="prod.brief" class="text-xs text-slate-400 mt-1 line-clamp-1">{{ prod.brief }}</p>
                </div>
                <div class="flex items-center justify-between mt-2">
                  <p class="text-rose-500 font-bold">¥{{ Number(prod.price).toFixed(2) }}</p>
                  <button
                    class="w-8 h-8 flex items-center justify-center bg-brand-50 rounded-lg text-brand-500 hover:bg-brand-100 transition-colors"
                    @click.stop="addToCart(prod)"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </section>

        <!-- 更多宝贝 (style=0) -->
        <section v-if="tag.style === '0' && tag.prods?.length">
          <div class="flex items-center justify-between mb-4">
            <h2 class="text-lg font-bold text-slate-800">{{ tag.title }}</h2>
          </div>
          <div class="space-y-3">
            <div
              v-for="prod in tag.prods"
              :key="prod.prodId"
              class="bg-white rounded-xl overflow-hidden flex p-4 cursor-pointer hover:shadow-card-hover transition-shadow group"
              @click="goProduct(prod.prodId)"
            >
              <div class="w-[100px] h-[100px] shrink-0 bg-slate-50 rounded-lg overflow-hidden">
                <ImageWithFallback
                  :src="prod.pic"
                  class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
                />
              </div>
              <div class="flex-1 min-w-0 ml-4 flex flex-col justify-between">
                <div>
                  <p class="text-sm text-slate-800 line-clamp-2 leading-snug">{{ prod.prodName }}</p>
                  <p v-if="prod.brief" class="text-xs text-slate-400 mt-1 line-clamp-1">{{ prod.brief }}</p>
                </div>
                <div class="flex items-center justify-between mt-2">
                  <p class="text-rose-500 font-bold">¥{{ Number(prod.price).toFixed(2) }}</p>
                  <button
                    class="w-8 h-8 flex items-center justify-center bg-brand-50 rounded-lg text-brand-500 hover:bg-brand-100 transition-colors"
                    @click.stop="addToCart(prod)"
                  >
                    <svg class="w-4 h-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
                    </svg>
                  </button>
                </div>
              </div>
            </div>
          </div>
        </section>
      </template>
    </div>
  </div>
</template>

<style scoped>
@keyframes marquee {
  0% { transform: translateX(100%); }
  100% { transform: translateX(-100%); }
}
.animate-marquee {
  animation: marquee 15s linear infinite;
}
.animate-marquee:hover {
  animation-play-state: paused;
}
</style>
