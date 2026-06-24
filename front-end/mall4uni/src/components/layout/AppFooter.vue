<script setup>
</script>

<template>
  <footer class="bg-white border-t border-slate-200 mt-12">
    <div class="max-w-7xl mx-auto px-4 py-8">
      <div class="flex flex-col sm:flex-row items-center justify-between gap-4">
        <div class="flex items-center gap-2">
          <span class="text-lg font-bold text-brand-600">mall4j</span>
          <span class="text-sm text-slate-400">|</span>
          <span class="text-sm text-slate-400">专业电商购物平台</span>
        </div>
        <div class="flex items-center gap-6 text-sm text-slate-500">
          <a href="#" class="hover:text-slate-700 transition-colors">关于我们</a>
          <a href="#" class="hover:text-slate-700 transition-colors">帮助中心</a>
          <a href="#" class="hover:text-slate-700 transition-colors">客服</a>
        </div>
        <p class="text-xs text-slate-400">
          &copy; {{ new Date().getFullYear() }} mall4j. All rights reserved.
        </p>
      </div>
    </div>
  </footer>
</template>
