import http from './http'

export const userApi = {
  // 登录
  login(data) {
    return http.post('/login', data)
  },
  // 注册
  register(data) {
    return http.post('/register', data)
  },
  // 刷新 token
  refresh() {
    return http.post('/token/refresh', {}, {
      headers: {
        Authorization: localStorage.getItem('token') || ''
      }
    })
  }
}
