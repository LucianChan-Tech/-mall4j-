# Mall4j 商城系统 — 项目架构框架说明

> 项目名称：mall4j（Yami Shop）
> 技术栈：Spring Boot 4.x + Vue 3.x + UniApp + MySQL + Redis
> 版本：0.0.1-SNAPSHOT

---

## 目录

- [一、系统架构总览](#一系统架构总览)
- [二、后端 Maven 多模块架构](#二后端-maven-多模块架构)
- [三、后端技术栈详解](#三后端技术栈详解)
- [四、前端多端架构](#四前端多端架构)
- [五、数据库表领域划分](#五数据库表领域划分)
- [六、Docker 部署架构](#六docker-部署架构)
- [七、本地运行架构](#七本地运行架构)
- [八、接口与认证体系](#八接口与认证体系)

---

## 一、系统架构总览

```
┌──────────────────────────────────────────────────────────────────────────┐
│                            用户访问层                                    │
├─────────────────┬────────────────────────┬───────────────────────────────┤
│                 │                        │                               │
│  mall4v         │  mall4uni             │  mall4m                       │
│  Vue3 + Vite    │  UniApp(Vue3)         │  微信小程序原生               │
│  后台管理 SPA   │  商城(H5/小程序/App)  │  商城(仅微信)                 │
│  :8080(Docker)  │  (需编译运行)         │  (需微信开发者工具)           │
│                 │                        │                               │
└────────┬────────┴──────────┬─────────────┴──────────┬────────────────────┘
         │                   │                        │
         │      HTTP API     │       HTTP API         │
         ▼                   ▼                        │
┌──────────────────────────────────────────────────────┐ │
│                 后端服务 (Spring Boot)                │ │
├───────────────────────┬──────────────────────────────┤ │
│                       │                              │ │
│  admin (port 8085)    │  api (port 8086)             │ │
│  后台管理 API 入口     │  商城前端 API 入口            │◄┘
│  商品/订单/会员管理    │  商品浏览/购物车/下单/支付    │
│  yami-shop-admin      │  yami-shop-api               │
│                       │                              │
└──────┬────────────────┴──────┬───────────────────────┘
       │                       │
       └──────────┬────────────┘
                  ▼
┌──────────────────────────────────────────────────┐
│               yami-shop-service                  │
│        业务逻辑层 + 数据访问层 (30+ Mapper)       │
├──────────────────────────────────────────────────┤
│               yami-shop-bean                     │
│         领域模型 / DTO / 枚举 / 事件               │
├──────────────────────────────────────────────────┤
│               yami-shop-common                   │
│       基础设施 / 配置 / 工具 / XSS / 文件上传      │
├─────────────────┬────────────────────────────────┤
│ yami-shop-sys   │ yami-shop-security             │
│ 系统管理(SRUD)  │ ├─ security-common             │
│ 菜单/角色/用户   │ ├─ security-admin              │
│                 │ └─ security-api                │
└──────┬──────────┴────────────────────────────────┘
       │
       ▼
┌──────────────────────────────────────────────────┐
│                   基础设施                         │
├──────────┬──────────┬───────────────────────────┤
│          │          │                           │
│  MySQL   │  Redis   │  七牛云 OSS / 阿里云 SMS  │
│  yami_   │  Redisson│  XXL-Job 分布式调度        │
│  shops   │  分布式锁 │  Knife4j API 文档          │
│          │          │                           │
└──────────┴──────────┴───────────────────────────┘
```

---

## 二、后端 Maven 多模块架构

### 2.1 模块清单

根 `pom.xml` 定义了 7 个模块的聚合构建：

| 模块 | 打包方式 | 端口 | 职责 |
|------|----------|------|------|
| **yami-shop-admin** | jar | 8085 | 后台管理系统 API 入口 |
| **yami-shop-api** | jar | 8086 | 商城前端 API 入口 |
| **yami-shop-service** | jar | — | 业务逻辑层 + 数据访问层 |
| **yami-shop-bean** | jar | — | 领域模型 / DTO / 枚举 / 事件 |
| **yami-shop-common** | jar | — | 基础设施 / 工具 / 全局配置 |
| **yami-shop-sys** | jar | — | 系统管理业务层 |
| **yami-shop-security** | pom | — | 安全认证聚合模块 |
| ├─ security-common | jar | — | 认证/授权公共逻辑 |
| ├─ security-admin | jar | — | 后台安全适配 |
| └─ security-api | jar | — | 商城安全适配 |

### 2.2 模块依赖关系

```
yami-shop-admin ───┐
                   ├── yami-shop-service ──┐
yami-shop-api ─────┘                      │
                                          ├── yami-shop-bean ──┐
yami-shop-sys ────────────────────────────┘                    │
                                                               ├── yami-shop-common
yami-shop-security-admin ───┐                                  │
                            ├── yami-shop-security-common ─────┘
yami-shop-security-api ─────┘
```

简化依赖链：

```
admin / api (启动入口)          sys (系统管理)
       │                            │
       └──── yami-shop-service ─────┘
                   │
             yami-shop-bean
                   │
             yami-shop-common
                   │
         security-admin/api
                   │
             security-common
```

### 2.3 各模块详细说明

#### yami-shop-admin（后台管理 API）

- **端口**：8085
- **配置**：`application.yml`（dev / docker 多环境）
- **包结构**：
  - `controller/` — 后台管理控制器（ProductController、OrderController、UserController、CategoryController、BrandController、SysUserController 等 20+）
  - `task/` — 定时任务（OrderTask）
  - `WebApplication.java` — Spring Boot 启动类
- **Dockerfile**：基于 `openjdk:17.0.2`，运行 JAR 包，暴露 8085 端口

#### yami-shop-api（商城前端 API）

- **端口**：8086
- **包结构**：
  - `controller/` — 商城 API 控制器（ProdController、ShopCartController、OrderController、PayController、UserRegisterController 等）
  - `listener/` — 事件监听器（ConfirmOrderListener、SubmitOrderListener）
  - `ApiApplication.java` — Spring Boot 启动类
- **Dockerfile**：基于 `openjdk:17.0.2`，运行 JAR 包，暴露 8086 端口

#### yami-shop-service（业务逻辑层）

- **无 Controller**，纯业务 Jar
- **包结构**：
  - `dao/` — 数据访问层，30+ 个 Mapper（AreaMapper、BasketMapper、OrderMapper、ProdMapper、SkuMapper、UserMapper 等）
  - `service/` — Service 接口
  - `service/impl/` — Service 实现类
- **业务范围**：商品、订单、购物车、用户、优惠券、支付、评论、收藏、运费等

#### yami-shop-bean（领域模型层）

- **包结构**：
  - `model/` — 实体类（Product、Order、Sku、Basket、User、Category、Brand 等）
  - `app/dto/` — 商城专用 DTO（ShopCartDto、OrderShopDto 等）
  - `enums/` — 枚举（OrderStatus、PayType、ProdStatus 等）
  - `event/` — 领域事件（PaySuccessOrderEvent 等）

#### yami-shop-common（基础设施层）

- **包结构**：
  - `config/` — 全局配置（MybatisPlusConfig、RedisCacheConfig、FileUploadConfig、CorsConfig）
  - `util/` — 工具类（RedisUtil、Json、CacheManagerUtil、IPHelper）
  - `aspect/` — AOP（RedisLockAspect）
  - `xss/` — XSS 防御过滤器
  - `handler/` — 全局异常处理器
  - `response/` — 统一响应封装

#### yami-shop-sys（系统管理层）

- **包结构**：
  - `controller/` — 系统管理控制器（SysUserController、SysRoleController、SysMenuController、SysLogController、SysConfigController）
  - `model/` — 系统实体（SysUser、SysRole、SysMenu、SysLog、SysConfig）
  - `service/` — Service 层

#### yami-shop-security（安全认证层）

- **security-common**：认证/授权公共逻辑
  - `filter/AuthFilter.java` — 认证过滤器
  - `manager/TokenStore.java` — Token 管理（Redis 存储）
  - `permission/PermissionService.java` — 权限校验
  - `adapter/MallWebSecurityConfigurerAdapter.java` — Spring Security 适配

- **security-admin**：后台安全适配
  - `model/YamiSysUser.java` — 后台用户模型
  - 后台用户登录验证、角色权限控制

- **security-api**：商城安全适配
  - `controller/LoginController.java` — 商城登录接口
  - `model/YamiUser.java` — 商城用户模型

---

## 三、后端技术栈详解

### 3.1 核心框架

| 技术 | 版本 | 用途 |
|------|------|------|
| Java | 17 | 运行环境 |
| Spring Boot | 4.0.3 | 应用框架（Jakarta EE） |
| Spring MVC | 随 Boot 4.x | REST API 控制器 |
| Spring Security | 随 Boot 4.x | 底层安全支撑 |
| Sa-Token | 1.44.0 | 权限认证框架（token 管理） |

### 3.2 数据层

| 技术 | 版本 | 用途 |
|------|------|------|
| MySQL | 8.x | 关系型数据库 |
| MyBatis-Plus | 3.5.16 | ORM 框架 + 分页插件 |
| Redis | 5.0.4 | 缓存 / Token 存储 |
| Redisson | 4.3.0 | 分布式锁 + Redis 客户端 |
| HikariCP | 随 Boot | 数据库连接池 |

### 3.3 API 与文档

| 技术 | 版本 | 用途 |
|------|------|------|
| Knife4j | 4.5.0 | API 文档 UI（OpenAPI 3） |
| SpringDoc | 3.0.2 | OpenAPI 3 规范生成 |

### 3.4 工具与中间件

| 技术 | 版本 | 用途 |
|------|------|------|
| Hutool | 5.8.35 | 全能 Java 工具库 |
| Guava | 33.4.0 | Google 工具库 |
| 七牛云 OSS SDK | 7.12.1 | 文件存储 |
| 阿里云 SMS | 4.3.9 + 1.1.0 | 短信验证码 |
| XXL-Job | 2.4.2 | 分布式定时任务调度 |
| AJ-Captcha | 1.3.0 | 行为式验证码（滑块/点选） |
| jsoup | 1.15.3 | XSS 防御过滤 |
| POI | 5.4.0 | Excel 导出（仅 admin 模块使用） |
| Jackson | 最新 | JSON 序列化 |
| Lombok | 最新 | 简化代码 |

### 3.5 多环境配置

后端支持三种配置环境，通过 `spring.profiles.active` 切换：

| Profile | 配置文件 | 适用场景 |
|---------|----------|----------|
| `dev` | `application-dev.yml` | 本地开发（MySQL/Redis → `127.0.0.1`） |
| `docker` | `application-docker.yml` | Docker 部署（通过环境变量发现服务） |
| `prod` | 未提供 | 生产环境 |

---

## 四、前端多端架构

项目提供三个独立前端子项目，覆盖不同客户端场景：

### 4.1 mall4v — 后台管理端

| 属性 | 说明 |
|------|------|
| **目录** | `front-end/mall4v/` |
| **技术栈** | Vue 3.2 + Vite 4 + Pinia + Vue Router 4 + Element Plus 2.3 |
| **CRUD 框架** | Avue 3.2（快速表格/表单生成） |
| **图表** | ECharts 5（数据看板） |
| **验证码** | AJ-Captcha 前端组件（行为式滑块验证） |
| **密码加密** | AES（ECB/Pkcs7，密钥 `-mall4j-password`） |
| **构建命令** | `pnpm dev`（开发） / `pnpm build`（生产） |
| **Docker 部署** | Nginx 1.20 容器，静态文件挂载到 `/usr/share/nginx/html/dist` |
| **端口** | 内部 80 → 宿主机 8080 |

**页面路由模块（`src/views/`）：**

```
login/          — 登录页（用户名/密码 + 滑块验证码）
modules/
  prod/         — 商品管理（商品列表、发布、编辑、分类、品牌、规格、分组标签）
  order/        — 订单管理（订单列表、详情、退款处理）
  user/         — 会员管理（会员列表、收货地址）
  shop/         — 门店管理（店铺设置、自提点、配送/运费模板）
  coupon/       — 优惠券管理
  sys/          — 系统管理（用户、角色、菜单、日志、配置）
  admin/        — 后台管理（文件管理、公告、首页轮播图）
```

### 4.2 mall4uni — 商城 UniApp 端（跨平台）

| 属性 | 说明 |
|------|------|
| **目录** | `front-end/mall4uni/` |
| **技术栈** | Vue 3.2 + Uni-App 3.0 + Vite 4 |
| **支持平台** | H5 / 微信小程序 / 支付宝小程序 / 百度小程序 / 字节跳动 / QQ / 快手 / 京东 / App(Android+iOS) |
| **构建命令** | `pnpm dev:h5`（H5 开发） / `pnpm build:mp-weixin`（微信小程序） |
| **UI** | @uni-ui/code-ui |

**页面路由（`src/pages/`）：**

```
accountLogin/       — 账号密码登录
accountRegister/    — 用户注册
index/              — 商城首页
category/           — 商品分类
prod/               — 商品详情
search-page/        — 商品搜索
search-prod-show/   — 搜索结果展示
basket/             — 购物车
submit-order/       — 提交订单
orderList/          — 订单列表
order-detail/       — 订单详情
pay-result/         — 支付结果
user/               — 个人中心
delivery-address/   — 收货地址管理
binding-phone/      — 绑定手机
recent-news/        — 消息通知
```

### 4.3 mall4m — 微信小程序原生版

| 属性 | 说明 |
|------|------|
| **目录** | `front-end/mall4m/` |
| **技术栈** | 微信小程序原生（app.js / app.json / app.wxss） |
| **UI** | Vant Weapp |
| **适用场景** | 纯微信小程序（已逐步被 mall4uni 覆盖） |

---

## 五、数据库表领域划分

数据库 `yami_shops` 中所有表以 `tz_` 为前缀，按业务领域划分：

### 商品模块

| 表名 | 说明 |
|------|------|
| `tz_prod` | 商品主表 |
| `tz_sku` | SKU 库存单位 |
| `tz_brand` | 品牌 |
| `tz_category` | 商品分类 |
| `tz_category_brand` | 分类-品牌关联 |
| `tz_category_prop` | 分类属性 |
| `tz_prod_prop` | 规格属性 |
| `tz_prod_prop_value` | 规格属性值 |
| `tz_prod_tag` | 商品分组标签 |
| `tz_prod_tag_reference` | 标签-商品关联 |

### 订单模块

| 表名 | 说明 |
|------|------|
| `tz_order` | 订单主表 |
| `tz_order_item` | 订单项明细 |
| `tz_order_refund` | 退款记录 |
| `tz_order_settlement` | 结算记录 |
| `tz_basket` | 购物车 |

### 用户模块

| 表名 | 说明 |
|------|------|
| `tz_user` | 用户主表 |
| `tz_user_addr` | 收货地址 |
| `tz_user_addr_order` | 订单地址快照 |
| `tz_user_collection` | 用户收藏 |

### 营销模块

| 表名 | 说明 |
|------|------|
| `tz_coupon` | 优惠券活动 |
| `tz_coupon_user` | 用户优惠券 |

### 门店 / 物流模块

| 表名 | 说明 |
|------|------|
| `tz_shop_detail` | 店铺信息 |
| `tz_pick_addr` | 自提点地址 |
| `tz_delivery` | 配送方式 |
| `tz_transport` | 运费模板 |
| `tz_transfee` | 运费明细 |
| `tz_transcity` | 指定城市运费 |
| `tz_transcity_free` | 指定包邮城市 |
| `tz_transfee_free` | 包邮条件明细 |

### 系统管理模块

| 表名 | 说明 |
|------|------|
| `tz_sys_user` | 后台管理员用户 |
| `tz_sys_role` | 角色 |
| `tz_sys_menu` | 菜单/权限 |
| `tz_sys_user_role` | 用户-角色关联 |
| `tz_sys_role_menu` | 角色-菜单关联 |
| `tz_sys_log` | 操作日志 |
| `tz_sys_config` | 系统配置 |

### 内容 / 工具模块

| 表名 | 说明 |
|------|------|
| `tz_index_img` | 首页轮播图 |
| `tz_notice` | 公告通知 |
| `tz_message` | 用户留言/消息 |
| `tz_hot_search` | 热门搜索词 |
| `tz_prod_comm` | 商品评论/评价 |
| `tz_prod_favorite` | 商品收藏 |
| `tz_area` | 地区字典（省市区） |
| `tz_attach_file` | 附件文件记录 |
| `tz_sms_log` | 短信发送记录 |

---

## 六、Docker 部署架构

### 6.1 docker-compose.yml 定义

```yaml
version: '3'
services:
  mall4j-mysql:    # MySQL 数据库容器
    build: ./db/Dockerfile
    ports: 3306:3306
    env:  root / root

  mall4j-redis:       # Redis 缓存容器
    image: redis:5.0.4
    ports: 6379:6379

  mall4j-admin:       # 后台管理 API
    build: ./yami-shop-admin/Dockerfile
    ports: 8085:8085
    depends_on: [mall4j-redis, mall4j-mysql]

  mall4j-api:         # 商城前端 API
    build: ./yami-shop-api/Dockerfile
    ports: 8086:8086
    depends_on: [mall4j-redis, mall4j-mysql]
```

### 6.2 容器依赖关系

```
                       ┌───────────────┐
                       │  mall4j-redis │
                       │  Redis 5.0.4  │
                       │  :6379        │
                       └───────┬───────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                 ▼
       ┌────────────┐  ┌────────────┐  ┌────────────────┐
       │ mall4j-    │  │ mall4j-    │  │ mall4j-mysql   │
       │ admin      │  │ api        │  │ MySQL          │
       │ :8085      │  │ :8086      │  │ :3306          │
       │ JAR 启动   │  │ JAR 启动   │  │                │
       └────────────┘  └────────────┘  └────────────────┘
                                            │
                                     ┌──────┴──────┐
                                     │  数据卷持久化 │
                                     │ mall4j-mysql/│
                                     └─────────────┘
```

### 6.3  Dockerfile 说明

#### yami-shop-admin/Dockerfile

```dockerfile
FROM openjdk:17.0.2
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
WORKDIR /opt/projects/mall4j
ADD ./yami-shop-admin/target/yami-shop-admin-0.0.1-SNAPSHOT.jar ./
EXPOSE 8085
CMD java -jar -Xms512m -Xmx512m -Xss256k \
     -Dspring.profiles.active=docker \
     yami-shop-admin-0.0.1-SNAPSHOT.jar
```

#### yami-shop-api/Dockerfile

```dockerfile
FROM openjdk:17.0.2
RUN ln -sf /usr/share/zoneinfo/Asia/Shanghai /etc/localtime
WORKDIR /opt/projects/mall4j
ADD ./yami-shop-api/target/yami-shop-api-0.0.1-SNAPSHOT.jar ./
EXPOSE 8086
CMD java -jar -Xms1024m -Xmx1024m -Xmn256m -Xss256k \
     -Dspring.profiles.active=docker \
     yami-shop-api-0.0.1-SNAPSHOT.jar
```

#### 前端 Dockerfile（以 mall4v 为例）

```dockerfile
FROM nginx:1.20
COPY ./dist /usr/share/nginx/html/dist
COPY ./nginx.conf /etc/nginx/conf.d
```

---

## 七、本地运行架构

### 7.1 当前实际运行拓扑

```
┌─────────────────────────────────────────────────────────┐
│                    Windows 宿主机                        │
│                                                         │
│  ┌───────────────┐    ┌───────────────┐                 │
│  │ java.exe      │    │ java.exe      │                 │
│  │ admin :8085   │    │ api   :8086   │                 │
│  │ PID 59548     │    │ PID 59920     │                 │
│  │ jar 本地启动   │    │ jar 本地启动   │                 │
│  └───────┬───────┘    └───────┬───────┘                 │
│          │                    │                         │
│          └────────┬───────────┘                         │
│                   ▼                                     │
│          ┌────────────────┐    ┌──────────────────┐     │
│          │ MySQL (本地)   │    │ Redis (Docker)    │     │
│          │ localhost:3306 │    │ localhost:6379    │     │
│          │ yami_shops     │    │ 172.17.0.2       │     │
│          └────────────────┘    └──────────────────┘     │
│                                                         │
│          ┌──────────────────────────────────┐           │
│          │ Docker Desktop                   │           │
│          │  ┌─────────────────────────┐    │           │
│          │  │ mall4v-frontend         │    │           │
│          │  │ Nginx 1.20 :8080→80     │    │           │
│          │  │ 前端静态资源             │    │           │
│          │  └─────────────────────────┘    │           │
│          │  ┌─────────────────────────┐    │           │
│          │  │ yami-redis              │    │           │
│          │  │ Redis 5.0.4 :6379       │    │           │
│          │  └─────────────────────────┘    │           │
│          └──────────────────────────────────┘           │
└─────────────────────────────────────────────────────────┘
```

### 7.2 本地启动方式

**后端（java -jar 本地启动）：**

```bash
# admin 后台管理 API（开发环境）
java -jar -Dspring.profiles.active=dev \
  -Xms512m -Xmx512m yami-shop-admin/target/yami-shop-admin-0.0.1-SNAPSHOT.jar

# api 商城前端 API（开发环境）
java -jar -Dspring.profiles.active=dev \
  -Xms512m -Xmx512m yami-shop-api/target/yami-shop-api-0.0.1-SNAPSHOT.jar
```

**前端 + 基础设施（Docker 启动）：**

```bash
# 前端管理页面（单独 Docker 容器）
docker run -d --name mall4v-frontend -p 8080:80 mall4v-frontend

# Redis（单独 Docker 容器）
docker run -d --name yami-redis -p 6379:6379 redis:5.0.4

# 全量启动（含后端）
docker compose up
```

### 7.3 环境配置差异

| 配置项 | 本地 dev 环境 | Docker 环境 |
|--------|-------------|------------|
| MySQL 地址 | `127.0.0.1:3306` | `mall4j-mysql:3306` |
| MySQL 密码 | `#Cwy050525`（admin）/ `root`（api） | `root` |
| Redis 地址 | `127.0.0.1:6379` | `mall4j-redis:6379` |
| Redis 数据库 | `0` | `1`（admin） |
| 日志配置 | `logback-dev.xml` | `logback-prod.xml` |
| XXL-Job | `localhost:8080` | `mall4j-job:8080` |

---

## 八、接口与认证体系

### 8.1 主要 API 端点

| 系统 | 方法 | 路径 | 说明 |
|------|------|------|------|
| Admin | POST | `/adminLogin` | 后台登录（需滑块验证码） |
| Admin | — | `/sys/**` | 系统管理接口 |
| Admin | — | `/prod/**` | 商品管理接口 |
| Admin | — | `/order/**` | 订单管理接口 |
| API | POST | `/login` | 商城用户登录 |
| API | POST | `/user/register` | 商城用户注册 |
| API | PUT | `/user/updatePwd` | 修改密码 |
| API | POST | `/p/sms/send` | 发送短信验证码 |
| API | — | `/p/**` | 公开接口（无需登录） |
| API | — | `/cart/**` | 购物车接口 |
| API | — | `/order/**` | 订单接口 |

### 8.2 认证流程

**后台管理登录流程：**

```
① 用户输入 账号 + 密码
         ↓
② 滑块验证码组件 → POST /captcha/get (获取验证码背景图)
         ↓
③ 用户拖动滑块 → POST /captcha/check (验证拖动位置)
         ↓
④ 验证通过 → POST /adminLogin (userName + 加密密码 + captchaVerification)
         ↓
⑤ 返回 TokenInfoVO (accessToken + refreshToken + expiresIn)
         ↓
⑥ 前端将 Authorization 写入 Cookie
         ↓
⑦ 后续请求 AuthFilter 从 Header/Cookie 读取 token → Redis 校验
```

**商城用户登录流程：**

```
① 用户输入 手机号/用户名 + 密码
         ↓
② AES 加密密码（时间戳+明文 → ECB/Pkcs7 加密）
         ↓
③ POST /login (userName + passWord)
         ↓
④ 先查手机号匹配 → 再查用户名匹配
         ↓
⑤ 返回 TokenInfoVO → 前端存储 token
```

### 8.3 安全架构

```
请求 → AuthFilter (security-common)
       ├── 白名单路径 (/p/**) → 直接放行
       ├── 无 token → 401
       ├── 有 token → Redis 查询
       │     ├── token 不存在/过期 → 401
       │     └── token 有效 → 注入用户上下文
       └── 资源访问 → PermissionService 校验角色/权限
                       ├── admin → 查 tz_sys_role + tz_sys_menu
                       └── api   → 查 tz_user 状态
```

- **Token 存储**：Redis（Sa-Token + `sa-token-redis-jackson`）
- **密码存储**：bcrypt 加密（`{bcrypt}$2a$10$...`）
- **密码传输**：前端 AES 加密后再 POST
- **XSS 防御**：jsoup HTML 过滤器（yami-shop-common）
- **验证码**：AJ-Captcha 行为式验证（滑块拼图），仅在后台管理使用

---

## 附：技术栈版本速查

```
后端核心：
  Java 17  |  Spring Boot 4.0.3  |  MyBatis-Plus 3.5.16
  Redisson 4.3.0  |  Sa-Token 1.44.0  |  MySQL 8.x  |  Redis 5.0.4

后端工具：
  Knife4j 4.5.0  |  Hutool 5.8.35  |  Guava 33.4.0
  七牛云 7.12.1  |  阿里云 SMS 4.3.9  |  XXL-Job 2.4.2
  POI 5.4.0  |  jsoup 1.15.3  |  AJ-Captcha 1.3.0

前端后台 (mall4v)：
  Vue 3.2.47  |  Vite 4.3.9  |  Element Plus 2.3.6
  Pinia 2.0.33  |  Vue Router 4.1.6  |  Avue 3.2.22
  ECharts 5.4.1  |  Axios 1.3.4

前端商城 (mall4uni)：
  Vue 3.2  |  Uni-App 3.0  |  Vite 4

基础设施：
  Docker 29.3.1  |  Docker Compose v5.1.1  |  Nginx 1.20
```

---

> 本文档基于 mall4j 项目源代码生成，版本 `0.0.1-SNAPSHOT`
> 生成时间：2025-06-23
