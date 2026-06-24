<script setup>
import { computed } from 'vue'
import { useRoute } from 'vue-router'
import AppNavbar from './AppNavbar.vue'
import AppFooter from './AppFooter.vue'

const route = useRoute()
// 部分页面不需要 Navbar（登录/注册/支付结果）
const showNavbar = computed(() => route.meta.showNav !== false)
</script>

<template>
  <div class="min-h-screen flex flex-col bg-slate-50">
    <!-- 顶部导航 -->
    <AppNavbar v-if="showNavbar" />

    <!-- 主内容区 -->
    <main class="flex-1" :class="showNavbar ? 'pt-16' : ''">
      <router-view />
    </main>

    <!-- 底部页脚 -->
    <AppFooter v-if="showNavbar" />
  </div>
</template>
