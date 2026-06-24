/*
 * Copyright (c) 2018-2999 广州市蓝海创新科技有限公司 All rights reserved.
 *
 * https://www.mall4j.com/
 *
 * 未经允许，不可做商业用途！
 *
 * 版权所有，侵权必究！
 */

package com.yami.shop.api.service;

import com.yami.shop.bean.model.Product;
import com.yami.shop.bean.model.Sku;
import com.yami.shop.service.ProductService;
import com.yami.shop.service.SkuService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.stereotype.Service;
import org.springframework.web.client.RestTemplate;

import java.util.*;

/**
 * AI 智能客服服务
 */
@Service
public class ChatService {

    @Autowired
    private ProductService productService;

    @Autowired
    private SkuService skuService;

    @Value("${deepseek.api-key:}")
    private String apiKey;

    @Value("${deepseek.api-url:https://api.deepseek.com}")
    private String apiUrl;

    private final RestTemplate restTemplate = new RestTemplate();

    /**
     * 向 AI 提问
     * @param question  用户问题
     * @param productId 关联商品ID（可为null）
     * @return AI 回答
     */
    public String ask(String question, Long productId) {
        // 1. 构建上下文信息
        String context = buildContext(productId);

        // 2. 构建 Prompt
        String prompt = buildPrompt(context, question);

        // 3. 调用 DeepSeek API
        return callDeepSeek(prompt);
    }

    /**
     * 构建商品上下文
     */
    private String buildContext(Long productId) {
        if (productId == null) {
            return "";
        }

        Product product = productService.getById(productId);
        if (product == null) {
            return "";
        }

        StringBuilder ctx = new StringBuilder();
        ctx.append("当前商品信息：\n");
        ctx.append("- 商品名称：").append(product.getProdName()).append("\n");
        ctx.append("- 价格：¥").append(product.getPrice()).append("\n");
        if (product.getOriPrice() != null) {
            ctx.append("- 原价：¥").append(product.getOriPrice()).append("\n");
        }
        ctx.append("- 简要描述：").append(product.getBrief() != null ? product.getBrief() : "无").append("\n");

        // 查询SKU规格
        List<Sku> skuList = skuService.listByProdId(productId);
        if (skuList != null && !skuList.isEmpty()) {
            ctx.append("- 可选规格：");
            Set<String> specs = new LinkedHashSet<>();
            for (Sku sku : skuList) {
                if (sku.getProdName() != null) {
                    specs.add(sku.getProdName());
                }
            }
            ctx.append(String.join(" / ", specs)).append("\n");
        }

        ctx.append("- 库存总量：").append(product.getTotalStocks() != null ? product.getTotalStocks() : "0").append("\n");

        if (product.getContent() != null && !product.getContent().isEmpty()) {
            String content = product.getContent()
                    .replaceAll("<[^>]+>", "")  // 去除HTML标签
                    .replaceAll("\\s+", " ");
            if (content.length() > 500) {
                content = content.substring(0, 500) + "...";
            }
            ctx.append("- 商品详情：").append(content).append("\n");
        }

        return ctx.toString();
    }

    /**
     * 构建 Prompt
     */
    private String buildPrompt(String context, String question) {
        StringBuilder prompt = new StringBuilder();
        prompt.append("你是一个专业的电商购物助手，名叫「小M」。").append("\n");
        prompt.append("你的职责是热情、耐心地解答用户关于商品的任何问题。").append("\n");
        prompt.append("回答要简洁、准确，不要编造商品信息。如果不知道就说「建议咨询客服」。").append("\n");
        prompt.append("回答长度控制在100字以内。").append("\n\n");

        if (!context.isEmpty()) {
            prompt.append("=== 用户正在查看的商品信息 ===\n");
            prompt.append(context).append("\n");
            prompt.append("============================\n\n");
        }

        prompt.append("用户问：").append(question).append("\n\n");
        prompt.append("请回答：");

        return prompt.toString();
    }

    /**
     * 调用 DeepSeek API
     */
    private String callDeepSeek(String prompt) {
        try {
            // 如果没配置API Key，返回模拟回答
            if (apiKey == null || apiKey.isEmpty() || "sk-your-key-here".equals(apiKey)) {
                return getMockAnswer(prompt);
            }

            HttpHeaders headers = new HttpHeaders();
            headers.setContentType(MediaType.APPLICATION_JSON);
            headers.setBearerAuth(apiKey);

            Map<String, Object> requestBody = new HashMap<>();
            requestBody.put("model", "deepseek-chat");

            List<Map<String, String>> messages = new ArrayList<>();
            messages.add(Map.of("role", "user", "content", prompt));
            requestBody.put("messages", messages);
            requestBody.put("temperature", 0.7);
            requestBody.put("max_tokens", 500);

            HttpEntity<Map<String, Object>> request = new HttpEntity<>(requestBody, headers);

            ResponseEntity<Map> response = restTemplate.postForEntity(
                    apiUrl + "/v1/chat/completions",
                    request,
                    Map.class
            );

            if (response.getBody() != null) {
                List<Map<String, Object>> choices = (List<Map<String, Object>>) response.getBody().get("choices");
                if (choices != null && !choices.isEmpty()) {
                    Map<String, Object> message = (Map<String, Object>) choices.get(0).get("message");
                    return (String) message.get("content");
                }
            }

            return "抱歉，我现在无法回答，请稍后再试。";

        } catch (Exception e) {
            e.printStackTrace();
            return "😅 网络开小差了，请稍后再试。";
        }
    }

    /**
     * 未配置API Key时的模拟回答
     */
    private String getMockAnswer(String prompt) {
        String question = prompt.contains("用户问：")
                ? prompt.substring(prompt.lastIndexOf("用户问：") + 5, prompt.lastIndexOf("\n\n请回答"))
                : "";

        // 简单的关键词匹配
        if (question.contains("包邮") || question.contains("运费")) {
            return "本店满99元包邮哦～";
        }
        if (question.contains("退") || question.contains("换")) {
            return "支持7天无理由退换货，请确保商品完好不影响二次销售～";
        }
        if (question.contains("保修") || question.contains("售后")) {
            return "本店商品享受国家三包政策，非人为损坏可享1年免费保修～";
        }
        if (question.contains("优惠") || question.contains("券")) {
            return "可以看看首页的优惠券活动，新用户还有专享优惠哦～";
        }
        if (question.contains("颜色") || question.contains("尺寸") || question.contains("规格")) {
            return "亲，商品详情页有完整的规格信息，您可以选择自己喜欢的颜色和尺寸下单哦～";
        }

        return "您好！我是智能助手小M，有什么可以帮助您的吗？😊";
    }
}
