import http from './http'

export const categoryApi = {
  // 获取分类列表
  getCategories() {
    return http.get('/category/list')
  },
  // 获取分类下商品
  getProducts(params) {
    return http.get('/prod/pageProd', { params })
  }
}
