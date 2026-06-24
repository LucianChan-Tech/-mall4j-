<script setup>
import { ref, onMounted } from 'vue'
import ProductCard from './ProductCard.vue'
import { useStaggerFadeIn } from '@/composables/useAnimation'

const props = defineProps({
  products: { type: Array, default: () => [] },
  mode: { type: String, default: 'grid' }, // grid | list
  animated: { type: Boolean, default: true }
})

const gridRef = ref(null)

if (props.animated) {
  useStaggerFadeIn(gridRef, { stagger: 0.06 })
}
</script>

<template>
  <div
    ref="gridRef"
    class="grid gap-4"
    :class="mode === 'grid' ? 'grid-cols-2 sm:grid-cols-3 lg:grid-cols-5' : 'grid-cols-1'"
  >
    <ProductCard
      v-for="prod in products"
      :key="prod.prodId"
      :prod="prod"
      :mode="mode"
    />
  </div>
</template>
