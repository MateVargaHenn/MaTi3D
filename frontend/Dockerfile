FROM node:24-alpine AS dependencies
WORKDIR /app
COPY package.json package-lock.json .npmrc ./
RUN npm ci --no-audit --no-fund

FROM dependencies AS public-build
COPY . .
RUN npx ng build mati3d-public --configuration production

FROM node:24-alpine AS public
WORKDIR /app
ENV NODE_ENV=production PORT=4000
COPY --from=public-build --chown=node:node /app/dist/mati3d-public ./dist/mati3d-public
USER node
EXPOSE 4000
CMD ["node", "dist/mati3d-public/server/server.mjs"]

FROM dependencies AS admin-build
COPY . .
RUN npx ng build mati3d-admin --configuration production --base-href /admin/

FROM nginx:1.29-alpine AS admin
COPY nginx.admin.conf /etc/nginx/conf.d/default.conf
COPY --from=admin-build /app/dist/mati3d-admin/browser /usr/share/nginx/html
EXPOSE 80
