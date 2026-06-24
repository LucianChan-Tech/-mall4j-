<script setup>
import { ref, onMounted } from 'vue'
import { useRouter } from 'vue-router'
import { addressApi } from '@/api/address'
import { useUserStore } from '@/stores/user'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'
import EmptyState from '@/components/common/EmptyState.vue'

const router = useRouter()
const userStore = useUserStore()

const addresses = ref([])
const loading = ref(true)

async function fetchAddresses() {
  loading.value = true
  try {
    const res = await addressApi.getList()
    addresses.value = res.data || []
  } catch (err) {
    console.error('加载地址失败:', err)
  } finally {
    loading.value = false
  }
}

function goNew() {
  router.push('/address/new')
}

function goEdit(addr) {
  router.push(`/address/${addr.addrId}/edit`)
}

async function deleteAddress(addrId) {
  if (!confirm('确定删除该地址？')) return
  try {
    await addressApi.delete(addrId)
    fetchAddresses()
  } catch (err) {
    alert(err.message || '删除失败')
  }
}

function formatAddress(addr) {
  return [addr.province, addr.city, addr.area, addr.addr].filter(Boolean).join('')
}

onMounted(() => {
  if (!userStore.isLoggedIn) {
    router.push('/login')
    return
  }
  fetchAddresses()
})
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-3xl mx-auto px-4 py-6">
      <div class="flex items-center justify-between mb-6">
        <h1 class="text-xl font-bold text-slate-800">收货地址</h1>
        <button
          class="text-sm text-brand-600 hover:text-brand-700 font-medium"
          @click="goNew"
        >
          + 新增地址
        </button>
      </div>

      <LoadingSpinner v-if="loading" />
      <EmptyState v-else-if="!addresses.length" message="暂无收货地址" />

      <div v-else class="space-y-3">
        <div
          v-for="addr in addresses"
          :key="addr.addrId"
          class="bg-white rounded-xl shadow-sm p-5"
        >
          <div class="flex items-start justify-between">
            <div class="flex-1 min-w-0">
              <div class="flex items-center gap-3 mb-1">
                <span class="font-medium text-slate-800">{{ addr.receiver }}</span>
                <span class="text-sm text-slate-500">{{ addr.mobile }}</span>
                <span
                  v-if="addr.isDefault === 1"
                  class="px-2 py-0.5 text-[10px] font-medium text-brand-600 bg-brand-50 rounded-full"
                >
                  默认
                </span>
              </div>
              <p class="text-sm text-slate-500">{{ formatAddress(addr) }}</p>
            </div>
          </div>

          <div class="flex items-center justify-end gap-4 mt-3 pt-3 border-t border-slate-50">
            <button
              class="text-xs text-slate-400 hover:text-brand-600 transition-colors"
              @click="goEdit(addr)"
            >
              编辑
            </button>
            <button
              class="text-xs text-slate-400 hover:text-rose-500 transition-colors"
              @click="deleteAddress(addr.addrId)"
            >
              删除
            </button>
          </div>
        </div>
      </div>
    </div>
  </div>
</template>
