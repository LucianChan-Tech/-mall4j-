import http from './http'

export const searchApi = {
  // 获取热搜词
  getHotSearch() {
    return http.get('/search/hotSearchList')
  },
  // 搜索商品
  searchProducts(params) {
    return http.get('/search/searchProdPage', { params })
  }
}
