FROM node:18-alpine

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy application files (excluding .env files via .dockerignore)
# SECURITY: .env files are NOT copied into the image - they are passed via docker-compose env_file
COPY . .

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Start the application
# SECURITY: Environment variables are provided at runtime via docker-compose, not baked into image
CMD ["node", "server.js"]

