import axios from 'axios'
import { useUserStore } from '@/stores/user'

const http = axios.create({
  baseURL: import.meta.env.VITE_APP_BASE_API || 'http://127.0.0.1:8086',
  timeout: 15000,
  headers: {
    'Content-Type': 'application/json'
  }
})

// 请求拦截器 - 注入 Token
http.interceptors.request.use(
  (config) => {
    const token = localStorage.getItem('token')
    if (token) {
      config.headers.Authorization = token
    }
    return config
  },
  (error) => Promise.reject(error)
)

// 响应拦截器 - 统一错误处理
http.interceptors.response.use(
  (response) => {
    const res = response.data

    // 00000 / A00002 成功
    if (res.code === '00000' || res.code === 'A00002') {
      return res
    }

    // A00004 未授权 — 跳转登录
    if (res.code === 'A00004') {
      const userStore = useUserStore()
      userStore.logout()
      // 记录当前路由，登录后跳回
      const currentPath = window.location.pathname + window.location.search
      if (currentPath !== '/login') {
        sessionStorage.setItem('redirectAfterLogin', currentPath)
      }
      window.location.href = '/login'
      return Promise.reject(new Error(res.msg || '未登录'))
    }

    // A00005 服务器错误
    if (res.code === 'A00005') {
      console.error('服务器出了点小差~', res)
      return Promise.reject(new Error('服务器出了点小差~'))
    }

    // 其他业务错误 — A00001 / A04001 / A00012 / A00006
    if (res.code !== '00000') {
      return Promise.reject(new Error(res.msg || res.data || '请求失败'))
    }

    return res
  },
  (error) => {
    console.error('请求失败:', error)
    return Promise.reject(error)
  }
)

export default http
