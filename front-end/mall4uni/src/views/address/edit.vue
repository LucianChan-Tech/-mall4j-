<script setup>
import { ref, onMounted } from 'vue'
import { useRouter, useRoute } from 'vue-router'
import { addressApi } from '@/api/address'
import { useUserStore } from '@/stores/user'
import LoadingSpinner from '@/components/common/LoadingSpinner.vue'

const router = useRouter()
const route = useRoute()
const userStore = useUserStore()

const loading = ref(true)
const saving = ref(false)
const isEdit = ref(false)

const form = ref({
  receiver: '',
  mobile: '',
  province: '',
  city: '',
  area: '',
  addr: '',
  isDefault: 0
})

async function loadAddress() {
  const addrId = route.params.id
  if (!addrId) {
    // 新增模式
    loading.value = false
    return
  }

  isEdit.value = true
  try {
    const res = await addressApi.getList()
    const addr = (res.data || []).find(a => String(a.addrId) === String(addrId))
    if (addr) {
      form.value = {
        receiver: addr.receiver || '',
        mobile: addr.mobile || '',
        province: addr.province || '',
        city: addr.city || '',
        area: addr.area || '',
        addr: addr.addr || '',
        isDefault: addr.isDefault || 0
      }
    }
  } catch (err) {
    console.error('加载地址失败:', err)
  } finally {
    loading.value = false
  }
}

async function save() {
  if (!form.value.receiver || !form.value.mobile || !form.value.addr) {
    alert('请填写完整信息')
    return
  }

  saving.value = true
  try {
    const data = {
      ...form.value,
      addrId: isEdit.value ? Number(route.params.id) : undefined
    }
    await addressApi.save(data)
    router.push('/address')
  } catch (err) {
    alert(err.message || '保存失败')
  } finally {
    saving.value = false
  }
}

onMounted(() => {
  if (!userStore.isLoggedIn) {
    router.push('/login')
    return
  }
  loadAddress()
})
</script>

<template>
  <div class="min-h-screen bg-slate-50">
    <div class="max-w-lg mx-auto px-4 py-6">
      <h1 class="text-xl font-bold text-slate-800 mb-6">
        {{ isEdit ? '编辑地址' : '新增地址' }}
      </h1>

      <LoadingSpinner v-if="loading" />

      <div v-else class="bg-white rounded-xl shadow-sm p-6">
        <form @submit.prevent="save" class="space-y-4">
          <div>
            <label class="block text-sm text-slate-600 mb-1">收货人</label>
            <input
              v-model="form.receiver"
              type="text"
              placeholder="请输入收货人姓名"
              class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
            />
          </div>

          <div>
            <label class="block text-sm text-slate-600 mb-1">手机号码</label>
            <input
              v-model="form.mobile"
              type="tel"
              placeholder="请输入手机号码"
              class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
            />
          </div>

          <div class="grid grid-cols-3 gap-3">
            <div>
              <label class="block text-sm text-slate-600 mb-1">省份</label>
              <input
                v-model="form.province"
                type="text"
                placeholder="省"
                class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm text-slate-600 mb-1">城市</label>
              <input
                v-model="form.city"
                type="text"
                placeholder="市"
                class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
              />
            </div>
            <div>
              <label class="block text-sm text-slate-600 mb-1">区/县</label>
              <input
                v-model="form.area"
                type="text"
                placeholder="区"
                class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
              />
            </div>
          </div>

          <div>
            <label class="block text-sm text-slate-600 mb-1">详细地址</label>
            <input
              v-model="form.addr"
              type="text"
              placeholder="街道、门牌号等"
              class="w-full h-11 px-4 rounded-xl border border-slate-200 text-sm focus:outline-none focus:ring-2 focus:ring-brand-500 focus:border-brand-500 transition-all"
            />
          </div>

          <div class="flex items-center gap-2">
            <input
              id="isDefault"
              v-model="form.isDefault"
              type="checkbox"
              :true-value="1"
              :false-value="0"
              class="rounded text-brand-600 focus:ring-brand-500"
            />
            <label for="isDefault" class="text-sm text-slate-600">设为默认地址</label>
          </div>

          <button
            type="submit"
            class="w-full h-11 rounded-xl text-sm font-medium bg-brand-600 text-white hover:bg-brand-700 disabled:opacity-50 transition-colors mt-6"
            :disabled="saving"
          >
            {{ saving ? '保存中...' : '保存' }}
          </button>
        </form>
      </div>
    </div>
  </div>
</template>
