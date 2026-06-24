/*
 * Copyright (c) 2018-2999 广州市蓝海创新科技有限公司 All rights reserved.
 *
 * https://www.mall4j.com/
 *
 * 未经允许，不可做商业用途！
 *
 * 版权所有，侵权必究！
 */

package com.yami.shop.api.controller;

import com.yami.shop.api.service.ChatService;
import com.yami.shop.common.response.ServerResponseEntity;
import io.swagger.v3.oas.annotations.Operation;
import io.swagger.v3.oas.annotations.tags.Tag;
import jakarta.validation.constraints.NotBlank;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.*;

/**
 * AI 智能客服接口
 */
@RestController
@RequestMapping("/chat")
@Tag(name = "AI智能客服")
public class ChatController {

    @Autowired
    private ChatService chatService;

    /**
     * 向 AI 客服提问
     * @param request 提问请求
     * @return AI 回答
     */
    @PostMapping("/send")
    @Operation(summary = "向AI客服提问" , description = "用户向AI客服发送问题，支持商品上下文问答")
    public ServerResponseEntity<String> send(@RequestBody ChatRequest request) {
        String answer = chatService.ask(request.getQuestion(), request.getProductId());
        return ServerResponseEntity.success(answer);
    }

    /**
     * 提问请求体
     */
    public static class ChatRequest {
        @NotBlank(message = "问题不能为空")
        private String question;
        private Long productId;

        public String getQuestion() {
            return question;
        }

        public void setQuestion(String question) {
            this.question = question;
        }

        public Long getProductId() {
            return productId;
        }

        public void setProductId(Long productId) {
            this.productId = productId;
        }
    }
}
