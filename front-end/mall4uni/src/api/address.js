import http from './http'

export const addressApi = {
  // 获取地址列表
  getList() {
    return http.get('/p/address/addressList')
  },
  // 保存地址（新增/编辑）
  save(data) {
    return http.post('/p/address/saveAddress', data)
  },
  // 删除地址
  delete(addressId) {
    return http.delete('/p/address/deleteAddress', {
      params: { addressId }
    })
  }
}
