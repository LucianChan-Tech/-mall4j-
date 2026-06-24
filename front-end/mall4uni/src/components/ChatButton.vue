<template>
  <view>
    <!-- 悬浮聊天按钮 -->
    <view
      v-if="!chatVisible"
      class="chat-float-btn"
      @tap="openChat"
    >
      <image
        class="chat-icon"
        src="data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='white'%3E%3Cpath d='M20 2H4c-1.1 0-2 .9-2 2v18l4-4h14c1.1 0 2-.9 2-2V4c0-1.1-.9-2-2-2z'/%3E%3C/svg%3E"
      />
      <text class="chat-float-text">AI</text>
    </view>

    <!-- 聊天对话框 -->
    <view
      v-if="chatVisible"
      class="chat-dialog"
    >
      <!-- 头部 -->
      <view class="chat-header">
        <text class="chat-header-title">🤖 AI 购物助手</text>
        <text
          class="chat-close"
          @tap="closeChat"
        >✕</text>
      </view>

      <!-- 消息列表 -->
      <scroll-view
        class="chat-messages"
        scroll-y
        :scroll-into-view="scrollId"
      >
        <!-- 欢迎消息 -->
        <view class="msg-row left">
          <view class="msg-avatar">🤖</view>
          <view class="msg-bubble">
            你好！我是智能助手小M，可以帮你了解商品信息、优惠活动、退换货政策等，有什么想问的吗？😊
          </view>
        </view>

        <view
          v-for="(msg, idx) in messages"
          :key="idx"
        >
          <view
            v-if="msg.role === 'user'"
            class="msg-row right"
          >
            <view class="msg-bubble user-bubble">
              {{ msg.content }}
            </view>
          </view>
          <view
            v-else
            class="msg-row left"
          >
            <view class="msg-avatar">🤖</view>
            <view class="msg-bubble">
              {{ msg.content }}
            </view>
          </view>
        </view>

        <!-- 加载中 -->
        <view
          v-if="loading"
          class="msg-row left"
        >
          <view class="msg-avatar">🤖</view>
          <view class="msg-bubble thinking">
            <text class="dot">.</text>
            <text class="dot">.</text>
            <text class="dot">.</text>
          </view>
        </view>

        <view :id="'msg-' + messages.length" />
      </scroll-view>

      <!-- 快捷问题 -->
      <view
        v-if="messages.length === 0 && !loading"
        class="quick-questions"
      >
        <view
          class="quick-tag"
          @tap="sendQuickQuestion('这个商品包邮吗？')"
        >
          包邮吗？
        </view>
        <view
          class="quick-tag"
          @tap="sendQuickQuestion('支持退换货吗？')"
        >
          退换货政策
        </view>
        <view
          class="quick-tag"
          @tap="sendQuickQuestion('有什么优惠活动？')"
        >
          优惠活动
        </view>
        <view
          class="quick-tag"
          @tap="sendQuickQuestion('保修多久？')"
        >
          保修政策
        </view>
      </view>

      <!-- 输入框 -->
      <view class="chat-input-area">
        <input
          v-model="inputText"
          class="chat-input"
          placeholder="输入您的问题..."
          @confirm="sendMessage"
          :adjust-position="false"
        />
        <view
          class="send-btn"
          @tap="sendMessage"
        >
          发送
        </view>
      </view>
    </view>
  </view>
</template>

<script setup>
import { ref, nextTick } from 'vue'
import http from '@/utils/http.js'

// 接收商品ID
const props = defineProps({
  productId: {
    type: Number,
    default: null
  }
})

const chatVisible = ref(false)
const inputText = ref('')
const messages = ref([])
const loading = ref(false)

const openChat = () => {
  chatVisible.value = true
}

const closeChat = () => {
  chatVisible.value = false
  messages.value = []
  inputText.value = ''
}

const sendQuickQuestion = (question) => {
  inputText.value = question
  sendMessage()
}

const sendMessage = () => {
  const text = inputText.value.trim()
  if (!text || loading.value) return

  // 添加用户消息
  messages.value.push({ role: 'user', content: text })
  inputText.value = ''
  loading.value = true

  // 调用后端API
  http.request({
    url: '/chat/send',
    method: 'POST',
    data: {
      question: text,
      productId: props.productId
    }
  })
    .then(res => {
      if (res.data) {
        messages.value.push({ role: 'assistant', content: res.data })
      }
    })
    .catch(() => {
      messages.value.push({ role: 'assistant', content: '😅 网络开小差了，请稍后再试。' })
    })
    .finally(() => {
      loading.value = false
    })
}
</script>

<style scoped>
/* 悬浮按钮 */
.chat-float-btn {
  position: fixed;
  right: 20rpx;
  bottom: 160rpx;
  width: 100rpx;
  height: 100rpx;
  background: linear-gradient(135deg, #07c160, #00a854);
  border-radius: 50%;
  display: flex;
  flex-direction: column;
  align-items: center;
  justify-content: center;
  box-shadow: 0 4rpx 16rpx rgba(7, 193, 96, 0.4);
  z-index: 999;
}

.chat-icon {
  width: 40rpx;
  height: 40rpx;
}

.chat-float-text {
  color: white;
  font-size: 18rpx;
  font-weight: bold;
  margin-top: 2rpx;
}

/* 聊天对话框 */
.chat-dialog {
  position: fixed;
  right: 20rpx;
  bottom: 140rpx;
  width: 580rpx;
  height: 750rpx;
  background: #fff;
  border-radius: 20rpx;
  box-shadow: 0 10rpx 40rpx rgba(0, 0, 0, 0.15);
  display: flex;
  flex-direction: column;
  z-index: 1000;
  overflow: hidden;
}

/* 头部 */
.chat-header {
  background: linear-gradient(135deg, #07c160, #00a854);
  padding: 24rpx 30rpx;
  display: flex;
  justify-content: space-between;
  align-items: center;
}

.chat-header-title {
  color: white;
  font-size: 30rpx;
  font-weight: bold;
}

.chat-close {
  color: white;
  font-size: 32rpx;
  padding: 10rpx;
}

/* 消息列表 */
.chat-messages {
  flex: 1;
  padding: 20rpx;
  overflow-y: auto;
}

.msg-row {
  display: flex;
  margin-bottom: 24rpx;
  align-items: flex-start;
}

.msg-row.right {
  justify-content: flex-end;
}

.msg-avatar {
  width: 50rpx;
  height: 50rpx;
  font-size: 36rpx;
  flex-shrink: 0;
  margin-right: 12rpx;
}

.msg-bubble {
  max-width: 400rpx;
  padding: 16rpx 20rpx;
  background: #f0f0f0;
  border-radius: 12rpx;
  font-size: 26rpx;
  line-height: 1.6;
  color: #333;
  word-break: break-all;
}

.user-bubble {
  background: #07c160;
  color: white;
}

.thinking {
  background: #f0f0f0;
}

.dot {
  animation: blink 1.4s infinite;
  font-size: 40rpx;
  font-weight: bold;
  color: #999;
}

.dot:nth-child(2) {
  animation-delay: 0.2s;
}

.dot:nth-child(3) {
  animation-delay: 0.4s;
}

@keyframes blink {
  0%, 20% { opacity: 0; }
  50% { opacity: 1; }
  100% { opacity: 0; }
}

/* 快捷问题 */
.quick-questions {
  display: flex;
  flex-wrap: wrap;
  padding: 10rpx 20rpx;
  gap: 12rpx;
  border-top: 1px solid #eee;
}

.quick-tag {
  padding: 10rpx 24rpx;
  background: #f5f5f5;
  border-radius: 30rpx;
  font-size: 24rpx;
  color: #666;
  border: 1px solid #ddd;
}

/* 输入框 */
.chat-input-area {
  display: flex;
  padding: 16rpx 20rpx;
  border-top: 1px solid #eee;
  background: #fff;
}

.chat-input {
  flex: 1;
  height: 60rpx;
  background: #f5f5f5;
  border-radius: 30rpx;
  padding: 0 24rpx;
  font-size: 26rpx;
}

.send-btn {
  width: 100rpx;
  height: 60rpx;
  background: #07c160;
  color: white;
  border-radius: 30rpx;
  display: flex;
  align-items: center;
  justify-content: center;
  font-size: 26rpx;
  margin-left: 16rpx;
}
</style>
