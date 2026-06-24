import http from './http'

export const homeApi = {
  // 获取首页轮播图
  getBanners() {
    return http.get('/indexImgs')
  },
  // 获取顶部公告
  getNotices() {
    return http.get('/shop/notice/topNoticeList')
  },
  // 获取商品标签列表
  getTagList() {
    return http.get('/prod/tag/prodTagList')
  },
  // 根据标签获取商品
  getProductsByTag(tagId, size = 6) {
    return http.get('/prod/prodListByTagId', {
      params: { tagId, size }
    })
  }
}
