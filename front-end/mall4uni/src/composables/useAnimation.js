import { onMounted, ref, unref } from 'vue'
import gsap from 'gsap'
import { ScrollTrigger } from 'gsap/ScrollTrigger'

gsap.registerPlugin(ScrollTrigger)

/**
 * 滚动到视口时的交错淡入动画
 * @param {import('vue').Ref<HTMLElement> | HTMLElement | string} target - 目标元素/ref/选择器
 * @param {Object} opts - 配置项
 * @param {number} [opts.y=40] - Y轴偏移量
 * @param {number} [opts.stagger=0.08] - 交错延迟（秒）
 * @param {number} [opts.duration=0.5] - 动画时长
 * @param {string} [opts.ease='power2.out'] - 缓动函数
 * @param {string} [opts.start='top 85%'] - ScrollTrigger 触发位置
 */
export function useStaggerFadeIn(target, opts = {}) {
  const {
    y = 40,
    stagger = 0.08,
    duration = 0.5,
    ease = 'power2.out',
    start = 'top 85%'
  } = opts

  onMounted(() => {
    const el = unref(target)
    const children = typeof el === 'string' ? document.querySelector(el) : el
    if (!children) return

    // 如果 target 是容器本身，对其子元素做 staggger
    // 如果 target 是选择器字符串传给 ScrollTrigger，对匹配元素做 stagger
    gsap.from(children.children?.length ? children.children : children, {
      opacity: 0,
      y,
      stagger,
      duration,
      ease,
      scrollTrigger: {
        trigger: children,
        start
      }
    })
  })
}

/**
 * 飞入动画 — 元素从一个位置飞到另一个位置
 * @param {HTMLElement} el - 要飞行的元素
 * @param {{ x: number, y: number }} to - 目标坐标
 * @param {Object} opts
 * @param {number} [opts.duration=0.5]
 * @param {string} [opts.ease='power3.out']
 */
export function useFlyTo(el, to, opts = {}) {
  const { duration = 0.5, ease = 'power3.out' } = opts

  return new Promise((resolve) => {
    gsap.to(el, {
      x: to.x,
      y: to.y,
      scale: 0.3,
      opacity: 0,
      duration,
      ease,
      onComplete: () => {
        gsap.set(el, { clearProps: 'all' })
        resolve()
      }
    })
  })
}

/**
 * 数字弹跳动效
 * @param {import('vue').Ref<HTMLElement> | string} target
 * @param {Object} opts
 */
export function useBounce(target, opts = {}) {
  const { scale = 1.2, duration = 0.25 } = opts

  onMounted(() => {
    const el = unref(target)
    if (!el) return

    gsap.fromTo(el, { scale: 1 }, {
      scale,
      duration: duration / 2,
      yoyo: true,
      repeat: 1,
      ease: 'elastic.out(1, 0.3)'
    })
  })
}
