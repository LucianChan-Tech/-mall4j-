<script setup>
import { ref, computed } from 'vue'
import PriceDisplay from './PriceDisplay.vue'

const props = defineProps({
  skuList: { type: Array, default: () => [] },
  defaultSku: { type: Object, default: null },
  pic: { type: String, default: '' }
})

const emit = defineEmits(['add-to-cart', 'buy-now'])

const visible = ref(false)
const prodNum = ref(1)
const selectedProp = ref('')
const selectedPropObj = ref({})
const propKeys = ref([])
const skuGroupList = ref([])

const currentSku = computed(() => props.defaultSku)

function open() {
  visible.value = true
  if (props.skuList.length) {
    buildSkuGroups()
  }
}

function close() {
  visible.value = false
  prodNum.value = 1
}

function buildSkuGroups() {
  const groupMap = {}
  const keys = []
  const selected = {}
  let isFirst = true

  for (const sku of props.skuList) {
    if (!sku.properties) continue
    const propsList = sku.properties.split(';')

    for (const p of propsList) {
      const [key, val] = p.split(':')
      if (!groupMap[key]) groupMap[key] = []
      if (groupMap[key].indexOf(val) === -1) groupMap[key].push(val)
      if (isFirst) {
        keys.push(key)
        selected[key] = val
      }
    }
    isFirst = false
  }

  propKeys.value = keys
  selectedPropObj.value = selected
  selectedProp.value = Object.values(selected).join(', ')
  skuGroupList.value = Object.entries(groupMap).map(([k, v]) => ({ key: k, values: v }))
}

function selectProp(key, val) {
  selectedPropObj.value[key] = val
  selectedProp.value = Object.values(selectedPropObj.value).join(', ')
}

function onAddCart() {
  emit('add-to-cart', { ...currentSku.value, count: prodNum.value })
  close()
}

function onBuyNow() {
  emit('buy-now', { ...currentSku.value, count: prodNum.value })
  close()
}
</script>

<template>
  <!-- 触发按钮 -->
  <div>
    <slot name="trigger" :open="open">
      <button
        class="w-full py-3 rounded-lg text-sm font-medium transition-colors"
        @click="open"
      >
        <slot name="trigger-text">选择规格</slot>
      </button>
    </slot>
  </div>

  <!-- 弹窗遮罩 -->
  <Teleport to="body">
    <Transition name="fade">
      <div
        v-if="visible"
        class="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
      >
        <!-- 背景 -->
        <div class="absolute inset-0 bg-black/40" @click="close" />

        <!-- 弹窗主体 -->
        <div class="relative w-full max-w-lg bg-white rounded-t-2xl sm:rounded-2xl shadow-xl max-h-[80vh] overflow-y-auto">
          <div class="p-5">
            <!-- 头部 -->
            <div class="flex gap-4 mb-5">
              <ImageWithFallback
                :src="pic"
                class="w-20 h-20 rounded-lg object-cover shrink-0"
              />
              <div class="flex-1 min-w-0">
                <PriceDisplay :price="currentSku?.price || 0" size="base" />
                <p class="text-sm text-slate-500 mt-1">
                  已选：{{ selectedProp }}，{{ prodNum }}件
                </p>
              </div>
              <button class="shrink-0 w-6 h-6 text-slate-400 hover:text-slate-600" @click="close">
                ✕
              </button>
            </div>

            <!-- SKU 选项 -->
            <div class="space-y-4">
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
            </div>

            <!-- 数量选择 -->
            <div class="flex items-center justify-between mt-6 pt-4 border-t border-slate-100">
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

            <!-- 操作按钮 -->
            <div class="flex gap-3 mt-6">
              <button
                class="flex-1 py-3 rounded-lg text-sm font-medium bg-brand-50 text-brand-600 hover:bg-brand-100 transition-colors"
                @click="onAddCart"
              >
                加入购物车
              </button>
              <button
                class="flex-1 py-3 rounded-lg text-sm font-medium bg-rose-500 text-white hover:bg-rose-600 transition-colors"
                @click="onBuyNow"
              >
                立即购买
              </button>
            </div>
          </div>
        </div>
      </div>
    </Transition>
  </Teleport>
</template>

<style scoped>
.fade-enter-active, .fade-leave-active {
  transition: opacity 0.2s ease;
}
.fade-enter-from, .fade-leave-to {
  opacity: 0;
}
.fade-enter-active .relative,
.fade-leave-active .relative {
  transition: transform 0.2s ease;
}
.fade-enter-from .relative,
.fade-leave-to .relative {
  transform: translateY(20px);
}
</style>
