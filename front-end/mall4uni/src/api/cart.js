import http from './http'

export const cartApi = {
  // 获取购物车列表
  getCart() {
    return http.get('/p/shopCart/info')
  },
  // 获取购物车数量
  getCount() {
    return http.get('/p/shopCart/prodCount')
  },
  // 新增/修改购物车项
  changeItem(data) {
    return http.post('/p/shopCart/changeItem', data)
  },
  // 删除购物车项
  deleteItem(basketId) {
    return http.delete('/p/shopCart/deleteItem', {
      params: { basketId }
    })
  }
}
