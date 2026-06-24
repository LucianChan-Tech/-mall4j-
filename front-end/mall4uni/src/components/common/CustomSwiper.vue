<script setup>
import { ref, onMounted, watch, computed } from 'vue'

const props = defineProps({
  images: { type: Array, default: () => [] },
  autoplay: { type: Boolean, default: true },
  interval: { type: Number, default: 4000 },
  height: { type: String, default: '400px' }
})

const current = ref(0)
let timer = null

function startAutoplay() {
  if (!props.autoplay || props.images.length <= 1) return
  timer = setInterval(() => {
    current.value = (current.value + 1) % props.images.length
  }, props.interval)
}

function stopAutoplay() {
  if (timer) clearInterval(timer)
  timer = null
}

function goTo(index) {
  current.value = index
  stopAutoplay()
  startAutoplay()
}

function prev() {
  current.value = current.value > 0 ? current.value - 1 : props.images.length - 1
}

function next() {
  current.value = (current.value + 1) % props.images.length
}

onMounted(() => {
  startAutoplay()
})

watch(() => props.images.length, () => {
  current.value = 0
  stopAutoplay()
  startAutoplay()
})
</script>

<template>
  <div
    class="relative overflow-hidden rounded-2xl bg-slate-100 select-none"
    :style="{ height }"
    @mouseenter="stopAutoplay"
    @mouseleave="startAutoplay"
  >
    <!-- 图片容器 -->
    <div
      class="flex h-full transition-transform duration-500 ease-out"
      :style="{ transform: `translateX(-${current * 100}%)` }"
    >
      <div
        v-for="(img, idx) in images"
        :key="idx"
        class="w-full h-full shrink-0"
      >
        <img
          :src="img.imgUrl || img"
          :alt="`banner-${idx}`"
          class="w-full h-full object-cover"
        />
      </div>
    </div>

    <!-- 左右箭头 -->
    <button
      v-if="images.length > 1"
      class="absolute left-3 top-1/2 -translate-y-1/2 w-9 h-9 flex items-center justify-center bg-white/80 hover:bg-white rounded-full shadow-sm text-slate-600 transition-colors"
      @click="prev"
    >
      ‹
    </button>
    <button
      v-if="images.length > 1"
      class="absolute right-3 top-1/2 -translate-y-1/2 w-9 h-9 flex items-center justify-center bg-white/80 hover:bg-white rounded-full shadow-sm text-slate-600 transition-colors"
      @click="next"
    >
      ›
    </button>

    <!-- 指示器 -->
    <div
      v-if="images.length > 1"
      class="absolute bottom-4 left-1/2 -translate-x-1/2 flex gap-2"
    >
      <button
        v-for="(_, idx) in images"
        :key="idx"
        class="w-2 h-2 rounded-full transition-all duration-300"
        :class="current === idx ? 'bg-white w-6' : 'bg-white/50 hover:bg-white/70'"
        @click="goTo(idx)"
      />
    </div>
  </div>
</template>
