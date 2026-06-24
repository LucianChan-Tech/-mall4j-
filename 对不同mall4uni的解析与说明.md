# 对 mall4uni 的解析与说明——mall4v / mall4uni / mall4m 三端对比

> 项目：mall4j (Yami Shop) 电商系统
> 前端目录：`front-end/` 下三个子项目

---

## 一、三端概览

三者的角色非常清晰：

 前端项目    使用者            做什么
 ─────────── ───────────────── ──────────────────────────────────────────
 mall4v      🛡️ 管理员/运营    管理商品、处理订单、管理会员、系统配置
 mall4uni 🎯 👤 消费者         浏览商品、加购物车、下单支付
 mall4m      👤 消费者（旧版） 同上，但仅限微信小程序，已被 mall4uni 替代

| | mall4v | mall4uni | mall4m |
|---|---|---|---|
| **全称** | mall4v（Vue后台） | mall4uni（UniApp跨平台商城） | mall4m（Mini Program微信原生） |
| **面向用户** | 🛡️ 管理员/运营 | 👤 消费者（顾客） | 👤 消费者（顾客） |
| **核心用途** | 商品管理、订单处理、会员管理、系统配置 | 浏览商品、购物车、下单支付、个人中心 | 浏览商品、购物车、下单支付（仅微信） |
| **技术栈** | Vue 3.2 + Vite 4 + Element Plus | Vue 3.2 + UniApp 3.0 + Vite 4 | 微信小程序原生（无框架） |
| **UI 框架** | Element Plus + Avue | @uni-ui/code-ui | Vant Weapp |
| **后端接口** | admin 模块（:8085） | api 模块（:8086） | api 模块（:8086） |
| **状态** | ✅ 主力维护 | ✅ 主力维护 | ⚠️ 旧版，逐步被 mall4uni 替代 |

---

## 二、mall4uni 深度解析（推荐消费者端）

mall4uni 是整个项目面向**最终消费者**的核心前端，它基于 UniApp 3.0 框架，一套代码可编译到 **10 个平台**：

| 平台 | 构建命令 | 产物目录 |
|------|---------|---------|
| 🌐 H5 手机网页 | `pnpm dev:h5` / `pnpm build:h5` | `dist/build/h5/` |
| 💬 微信小程序 | `pnpm dev:mp-weixin` / `pnpm build:mp-weixin` | `dist/build/mp-weixin/` |
| 💳 支付宝小程序 | `pnpm build:mp-alipay` | — |
| 🏠 百度小程序 | `pnpm build:mp-baidu` | — |
| 🎯 头条/抖音小程序 | `pnpm build:mp-toutiao` | — |
| 🟢 快手小程序 | `pnpm build:mp-kuaishou` | — |
| 🐧 QQ 小程序 | `pnpm build:mp-qq` | — |
| 🛒 京东小程序 | `pnpm build:mp-jd` | — |
| 📱 Android App | `pnpm build:app-android` | — |
| 📱 iOS App | `pnpm build:app-ios` | — |

### 目录结构

```
front-end/mall4uni/src/
├── main.js                  # 应用入口（createSSRApp）
├── App.vue                  # 根组件（启动时获取购物车数量）
├── pages.json               # 所有页面 + tabBar 配置
├── manifest.json            # 各平台配置（微信 appid、Android 权限等）
├── pages/                   # 页面文件（文件式路由）
│   ├── index/               # 商城首页
│   ├── category/            # 商品分类
│   ├── basket/              # 购物车
│   ├── prod/                # 商品详情
│   ├── search-page/         # 搜索
│   ├── search-prod-show/    # 搜索结果
│   ├── submit-order/        # 提交订单
│   ├── orderList/           # 订单列表
│   ├── order-detail/        # 订单详情
│   ├── delivery-address/    # 收货地址管理
│   ├── editAddress/         # 编辑地址
│   ├── pay-result/          # 支付结果
│   ├── accountLogin/        # 登录页
│   ├── register/            # 注册页
│   ├── user/                # 个人中心
│   └── recent-news/         # 消息通知
├── components/              # 公共组件
│   ├── img-show.vue         # 图片展示
│   └── production/          # 商品相关组件
├── utils/                   # 工具函数
│   ├── http.js              # 网络请求封装（uni.request）
│   ├── login.js             # 登录状态管理 + Token 自动刷新
│   ├── crypto.js            # AES 密码加密
│   ├── constant.js          # 枚举常量
│   └── util.js              # 通用工具
└── static/images/           # 静态图片资源
```

### API 接入方式

```javascript
// src/utils/http.js — 网络请求封装
http.request = (params) => {
  // 1. 拼接完整 URL
  const baseUrl = import.meta.env.VITE_APP_BASE_API  // 默认 http://127.0.0.1:8086
  const url = baseUrl + params.url
  
  // 2. 请求头携带 Token
  const token = uni.getStorageSync('Token')
  if (token) {
    header.Authorization = token
  }
  
  // 3. 发送请求
  uni.request({ url, method, header, data, success, fail })
  
  // 4. 统一错误处理
  // 00000 → 成功
  // A00001 → 用户可见错误提示
  // A00004 → 未授权 → 跳转登录页
  // A00005 → 服务器异常
}
```

### 登录流程

```
用户输入 手机号/用户名 + 密码
        ↓
AES 加密密码（密钥: -mall4j-password）
        ↓
POST /login → { userName, passWord }
        ↓
后端验证 → 返回 { accessToken, expiresIn }
        ↓
uni.setStorageSync('Token', accessToken)
uni.setStorageSync('expiresIn', expiresIn)
        ↓
后续请求自动在 Header 携带 Token
每过半程有效期自动刷新 Token
```

---

## 三、三端核心差异对比

### 3.1 技术栈差异

| 维度 | mall4v | mall4uni | mall4m |
|------|--------|----------|--------|
| **框架** | Vue 3.2 + Vite 4 | Vue 3.2 + UniApp 3.0 | 微信原生（无框架） |
| **语言** | Vue SFC + JS | Vue SFC + JS | wxml + wxss + js |
| **路由** | Vue Router（动态路由） | pages.json（文件式路由） | app.json（文件式路由） |
| **状态管理** | Pinia | uni.getStorageSync() | 无 |
| **HTTP 请求** | axios | uni.request() | wx.request() |
| **构建工具** | Vite 4 | Vite 4 + uni插件 | 无（微信IDE内置） |
| **CSS 方案** | SCSS | SCSS | wxss |
| **代码复用** | 组件化 | 跨平台一套代码 | 仅微信 |

### 3.2 后端连接差异

| 项目 | 后端模块 | 默认端口 | API 地址配置位置 | 配置方式 |
|------|---------|---------|----------------|---------|
| **mall4v** | yami-shop-admin | **8085** | `.env.development` / `.env.production` | 环境变量 `VITE_APP_BASE_API` |
| **mall4uni** | yami-shop-api | **8086** | `.env.development` / `.env.production` | 环境变量 `VITE_APP_BASE_API` |
| **mall4m** | yami-shop-api | 8086 | `utils/api.js` 中**硬编码** | 直接改 JS 文件 |

### 3.3 认证方式差异

| 项目 | 登录方式 | 密码传输 | Token 存储 | 验证码 |
|------|---------|---------|-----------|-------|
| **mall4v** | 用户名 + 密码 | AES 加密 | Cookie（vue-cookies） | ✅ 滑块验证码 |
| **mall4uni** | 手机号 + 密码 | AES 加密 | uni.setStorageSync | ❌ 无 |
| **mall4m** | 微信 OAuth 静默登录 | — | 微信 Storage | ❌ 无 |

### 3.4 页面功能差异

| 功能 | mall4v（后台管理） | mall4uni（商城） | mall4m（商城-旧） |
|------|------------------|-----------------|------------------|
| 商品管理（增删改查） | ✅ | ❌ | ❌ |
| 订单管理/退款处理 | ✅ | ❌ | ❌ |
| 会员管理 | ✅ | ❌ | ❌ |
| 系统配置/角色权限 | ✅ | ❌ | ❌ |
| 浏览商品/搜索 | ❌ | ✅ | ✅ |
| 购物车 | ❌ | ✅ | ✅ |
| 下单支付 | ❌ | ✅ | ✅ |
| 个人中心/地址管理 | ❌ | ✅ | ✅ |
| 优惠券 | ❌ | ✅ | ✅ |
| 滑块验证码 | ✅ | ❌ | ❌ |

---

## 四、用户如何选择

| 你的角色 | 应该访问哪个 | 启动方式 |
|---------|------------|---------|
| 🛡️ **商家/运营**——管后台 | **mall4v** → `http://localhost:8080` | `pnpm dev` 或 Docker Nginx |
| 👤 **普通消费者**——买东西 | **mall4uni** → H5 或小程序 | `pnpm dev:h5` |
| 👤 **微信小程序用户** | **mall4uni（推荐）**或 mall4m（旧） | 微信开发者工具打开 |

---

## 五、环境变量配置参考

### mall4uni 的 `.env` 文件

```bash
# front-end/mall4uni/.env.development（开发环境）
VITE_APP_ENV = 'development'
VITE_APP_BASE_API = 'http://127.0.0.1:8086'   # 连接后端 api 模块
```

```bash
# front-end/mall4uni/.env.production（生产环境）
VITE_APP_ENV = 'production'
VITE_APP_BASE_API = 'https://your-domain.com'  # 改为实际生产域名
```

### mall4v 的 `.env` 文件

```bash
# front-end/mall4v/.env.development
VITE_APP_ENV = 'development'
VITE_APP_BASE_API = 'http://127.0.0.1:8085'   # 连接后端 admin 模块
```

```bash
# front-end/mall4v/.env.production
VITE_APP_ENV = 'production'
VITE_APP_BASE_API = 'http://127.0.0.1:8085'   # 改为实际生产域名
```

---

## 六、总结

- **mall4uni** 是面向**终端消费者**的主力前端，一个项目覆盖 H5 + 各大平台小程序 + App
- **mall4v** 是面向**管理员**的后台管理系统，功能完全不同
- **mall4m** 是旧版微信原生小程序，功能已被 mall4uni 覆盖，建议新项目直接使用 mall4uni
- 三者通过 `.env` 文件中的 `VITE_APP_BASE_API` 分别连接到不同的后端模块（admin:8085 / api:8086）
