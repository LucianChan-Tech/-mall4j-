import { createRouter, createWebHistory } from 'vue-router'

const routes = [
  // 首页
  {
    path: '/',
    name: 'Home',
    component: () => import('@/views/home/index.vue'),
    meta: { title: 'mall4j', showNav: true }
  },
  // 分类
  {
    path: '/category',
    name: 'Category',
    component: () => import('@/views/category/index.vue'),
    meta: { title: '分类商品', showNav: true }
  },
  {
    path: '/category/sub',
    name: 'SubCategory',
    component: () => import('@/views/category/sub.vue'),
    meta: { title: '子分类', showNav: true }
  },
  // 搜索
  {
    path: '/search',
    name: 'Search',
    component: () => import('@/views/search/index.vue'),
    meta: { title: '搜索', showNav: true }
  },
  {
    path: '/search/result',
    name: 'SearchResult',
    component: () => import('@/views/search/result.vue'),
    meta: { title: '搜索结果', showNav: true }
  },
  // 商品
  {
    path: '/product/:id',
    name: 'ProductDetail',
    component: () => import('@/views/product/detail.vue'),
    meta: { title: '商品详情', showNav: true }
  },
  {
    path: '/product/classify',
    name: 'ProductClassify',
    component: () => import('@/views/product/classify.vue'),
    meta: { title: '商品列表', showNav: true }
  },
  // 购物车
  {
    path: '/cart',
    name: 'Cart',
    component: () => import('@/views/cart/index.vue'),
    meta: { title: '购物车', showNav: true }
  },
  // 结算
  {
    path: '/checkout',
    name: 'Checkout',
    component: () => import('@/views/checkout/submit.vue'),
    meta: { title: '提交订单', showNav: true }
  },
  // 订单
  {
    path: '/orders',
    name: 'OrderList',
    component: () => import('@/views/order/list.vue'),
    meta: { title: '订单列表', showNav: true }
  },
  {
    path: '/orders/:id',
    name: 'OrderDetail',
    component: () => import('@/views/order/detail.vue'),
    meta: { title: '订单详情', showNav: true }
  },
  // 支付
  {
    path: '/payment/result',
    name: 'PaymentResult',
    component: () => import('@/views/misc/payment-result.vue'),
    meta: { title: '支付结果', showNav: false }
  },
  // 物流
  {
    path: '/logistics/:id',
    name: 'Logistics',
    component: () => import('@/views/misc/logistics.vue'),
    meta: { title: '物流查询', showNav: true }
  },
  // 地址
  {
    path: '/address',
    name: 'AddressList',
    component: () => import('@/views/address/list.vue'),
    meta: { title: '收货地址', showNav: true }
  },
  {
    path: '/address/new',
    name: 'AddressNew',
    component: () => import('@/views/address/edit.vue'),
    meta: { title: '新增地址', showNav: true }
  },
  {
    path: '/address/:id/edit',
    name: 'AddressEdit',
    component: () => import('@/views/address/edit.vue'),
    meta: { title: '编辑地址', showNav: true }
  },
  // 用户
  {
    path: '/login',
    name: 'Login',
    component: () => import('@/views/user/login.vue'),
    meta: { title: '用户登录', showNav: false }
  },
  {
    path: '/register',
    name: 'Register',
    component: () => import('@/views/user/register.vue'),
    meta: { title: '用户注册', showNav: false }
  },
  {
    path: '/user',
    name: 'UserProfile',
    component: () => import('@/views/user/profile.vue'),
    meta: { title: '个人中心', showNav: true }
  },
  // 公告
  {
    path: '/news',
    name: 'NewsList',
    component: () => import('@/views/misc/news.vue'),
    meta: { title: '最新公告', showNav: true }
  },
  {
    path: '/news/:id',
    name: 'NewsDetail',
    component: () => import('@/views/misc/news-detail.vue'),
    meta: { title: '最新公告', showNav: true }
  },
  // 404 兜底
  {
    path: '/:pathMatch(.*)*',
    name: 'NotFound',
    component: () => import('@/views/misc/news-detail.vue'),
    meta: { title: '页面未找到', showNav: false }
  }
]

const router = createRouter({
  history: createWebHistory(),
  routes,
  scrollBehavior() {
    return { top: 0 }
  }
})

export default router
