FROM node:20-alpine AS build

WORKDIR /app

COPY package*.json ./

RUN if [ -f package-lock.json ]; then \
      npm ci --no-audit; \
    else \
      npm install --no-audit; \
    fi

COPY . .

ARG VITE_IS_BASE_URL=https://localhost:9444
ARG VITE_IS_CLIENT_ID=REPLACE_WITH_WSO2_IS_SPA_CLIENT_ID
ARG VITE_REDIRECT_URL=http://localhost:5173
ARG VITE_SIGN_OUT_REDIRECT_URL=http://localhost:5173
ARG VITE_APIM_BASE_URL=http://localhost:5173/gateway
ARG VITE_BANKING_MI_CONTEXT=
ARG VITE_AGENT_CONTRACT=ai-adapter
ARG VITE_AGENT_CHAT_URL=http://localhost:5173/gateway/v1/ai/omni_a2a/chat/completions
ARG VITE_ENABLE_MOCK_AUTH=false
ARG VITE_MOCK_SCOPES=
ARG VITE_AGENT_ID=not-configured
ARG VITE_AGENT_NAME=Banking Omni Assistant Agent
ARG VITE_AGENT_PURPOSE=Governed banking assistant with read-only default permissions.

ENV VITE_IS_BASE_URL=$VITE_IS_BASE_URL
ENV VITE_IS_CLIENT_ID=$VITE_IS_CLIENT_ID
ENV VITE_REDIRECT_URL=$VITE_REDIRECT_URL
ENV VITE_SIGN_OUT_REDIRECT_URL=$VITE_SIGN_OUT_REDIRECT_URL
ENV VITE_APIM_BASE_URL=$VITE_APIM_BASE_URL
ENV VITE_BANKING_MI_CONTEXT=$VITE_BANKING_MI_CONTEXT
ENV VITE_AGENT_CONTRACT=$VITE_AGENT_CONTRACT
ENV VITE_AGENT_CHAT_URL=$VITE_AGENT_CHAT_URL
ENV VITE_ENABLE_MOCK_AUTH=$VITE_ENABLE_MOCK_AUTH
ENV VITE_MOCK_SCOPES=$VITE_MOCK_SCOPES
ENV VITE_AGENT_ID=$VITE_AGENT_ID
ENV VITE_AGENT_NAME=$VITE_AGENT_NAME
ENV VITE_AGENT_PURPOSE=$VITE_AGENT_PURPOSE

RUN npm run build

FROM nginx:1.27-alpine

COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html

EXPOSE 80

HEALTHCHECK --interval=20s --timeout=5s --retries=10 \
  CMD wget -qO- http://localhost/ >/dev/null || exit 1

CMD ["nginx", "-g", "daemon off;"]