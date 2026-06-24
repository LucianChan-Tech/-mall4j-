<script setup>
import { useRouter } from 'vue-router'
import PriceDisplay from './PriceDisplay.vue'
import ImageWithFallback from '@/components/common/ImageWithFallback.vue'

const props = defineProps({
  prod: { type: Object, required: true },
  mode: { type: String, default: 'grid' } // grid | list
})

const router = useRouter()

function goDetail() {
  router.push(`/product/${props.prod.prodId}`)
}
</script>

<template>
  <div
    class="bg-white rounded-xl shadow-sm hover:shadow-card-hover transition-all duration-300 cursor-pointer group"
    :class="mode === 'grid' ? 'overflow-hidden' : 'flex gap-4 p-4'"
    @click="goDetail"
  >
    <!-- 图片 -->
    <div
      class="overflow-hidden bg-slate-50"
      :class="mode === 'grid' ? 'aspect-square' : 'w-[120px] h-[120px] shrink-0 rounded-lg'"
    >
      <ImageWithFallback
        :src="prod.pic"
        class="w-full h-full object-cover group-hover:scale-105 transition-transform duration-500"
      />
    </div>

    <!-- 信息 -->
    <div :class="mode === 'grid' ? 'p-3' : 'flex-1 min-w-0 flex flex-col justify-between'">
      <!-- 商品名称 -->
      <h3
        class="text-sm text-slate-800 leading-snug line-clamp-2"
        :class="mode === 'list' ? 'mb-2' : 'mb-2'"
      >
        {{ prod.prodName }}
      </h3>

      <!-- 简介（仅列表模式） -->
      <p v-if="mode === 'list' && prod.brief" class="text-xs text-slate-400 mb-3 line-clamp-1">
        {{ prod.brief }}
      </p>

      <!-- 价格 -->
      <div class="flex items-center gap-2">
        <PriceDisplay :price="prod.price" size="sm" />
        <span v-if="prod.oriPrice" class="text-xs text-slate-300 line-through">
          ¥{{ prod.oriPrice }}
        </span>
      </div>
    </div>
  </div>
</template>
