FROM node:24-bookworm-slim

WORKDIR /app

COPY docusaurus/package*.json ./docusaurus/
RUN cd docusaurus && npm install --legacy-peer-deps

COPY docusaurus ./docusaurus
COPY docusaurus-renderer ./docusaurus-renderer

WORKDIR /app/docusaurus-renderer
ENV PORT=3000
EXPOSE 3000

CMD ["npm", "start"]
