import http from './http'

export const orderApi = {
  // 提交订单
  submit(data) {
    return http.post('/p/order/submit', data)
  },
  // 获取订单列表
  getList(params) {
    return http.get('/p/order/getOrderList', { params })
  },
  // 获取订单详情
  getDetail(orderId) {
    return http.get('/p/order/orderDetail', {
      params: { orderId }
    })
  },
  // 取消订单
  cancel(orderId) {
    return http.post('/p/order/cancel', orderId)
  },
  // 获取物流信息
  getDelivery(orderId) {
    return http.get('/p/order/getDeliveryInfo', {
      params: { orderId }
    })
  }
}
