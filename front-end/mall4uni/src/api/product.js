import http from './http'

export const productApi = {
  // 获取商品详情
  getDetail(prodId) {
    return http.get('/prod/prodInfo', {
      params: { prodId }
    })
  },
  // 检查是否收藏
  isCollected(prodId) {
    return http.get('/p/user/collection/isCollection', {
      params: { prodId }
    })
  },
  // 添加/取消收藏
  toggleCollection(prodId) {
    return http.post('/p/user/collection/addOrCancel', prodId)
  }
}
