FROM node:24-alpine

ENV NODE_ENV=production

WORKDIR /app

# Copy files and explicitly hand ownership over to the pre-built node user
COPY --chown=node:node package*.json ./

# Install production dependencies
RUN npm ci --only=production

# Copy application source files and assign ownership to node user
COPY --chown=node:node . .


# Safely drop root privileges to the built-in node user
USER node

EXPOSE 3000

CMD ["node", "app.js"]
