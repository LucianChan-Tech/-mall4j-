import { defineStore } from 'pinia'
import { ref } from 'vue'
import { cartApi } from '@/api/cart'

export const useCartStore = defineStore('cart', () => {
  const items = ref([])
  const totalCount = ref(0)
  const selectedIds = ref([])

  const selectedItems = computed(() =>
    items.value.filter(item => selectedIds.value.includes(item.basketId))
  )

  const totalPrice = computed(() =>
    selectedItems.value.reduce((sum, item) => sum + item.productPrice * item.prodCount, 0)
  )

  async function fetchCart() {
    const res = await cartApi.getCart()
    items.value = res.data.shopCartItems || []
    return res.data
  }

  async function addItem(prodId, skuId, count, shopId) {
    await cartApi.changeItem({
      basketId: 0,
      count,
      prodId,
      shopId,
      skuId
    })
    await fetchCount()
  }

  async function updateCount(basketId, count, prodId, shopId, skuId) {
    await cartApi.changeItem({ basketId, count, prodId, shopId, skuId })
    await fetchCart()
  }

  async function removeItem(basketId) {
    await cartApi.deleteItem(basketId)
    selectedIds.value = selectedIds.value.filter(id => id !== basketId)
    await fetchCart()
  }

  async function fetchCount() {
    const res = await cartApi.getCount()
    totalCount.value = res.data || 0
    return res.data
  }

  function toggleSelect(basketId) {
    const idx = selectedIds.value.indexOf(basketId)
    if (idx === -1) {
      selectedIds.value.push(basketId)
    } else {
      selectedIds.value.splice(idx, 1)
    }
  }

  function toggleSelectAll(checked) {
    if (checked) {
      selectedIds.value = items.value.map(i => i.basketId)
    } else {
      selectedIds.value = []
    }
  }

  return {
    items,
    totalCount,
    selectedIds,
    selectedItems,
    totalPrice,
    fetchCart,
    addItem,
    updateCount,
    removeItem,
    fetchCount,
    toggleSelect,
    toggleSelectAll
  }
})
