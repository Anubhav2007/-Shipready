# install.ps1 - shipready v1.0.0
# Complete environment setup for production-ready applications
# Usage: .\install.ps1 [project-name]

param(
    [string]$ProjectName = "my-app"
)

# Set error handling
$ErrorActionPreference = "Stop"

# Colors for output
$Red = "`e[31m"
$Green = "`e[32m"
$Yellow = "`e[33m"
$Blue = "`e[34m"
$NC = "`e[0m" # No Color

# Print colored messages
function Write-Step {
    param([string]$Message)
    Write-Host "$Blue==>$NC $Green$Message$NC"
}

function Write-Error {
    param([string]$Message)
    Write-Host "$Red❌ Error:$NC $Message"
    exit 1
}

function Write-Warning {
    param([string]$Message)
    Write-Host "$Yellow⚠️  $Message$NC"
}

function Write-Success {
    param([string]$Message)
    Write-Host "$Green✅ $Message$NC"
}

# Check for required tools
function Check-Requirements {
    Write-Step "Checking system requirements..."
    
    # Check Node.js
    try {
        $nodeVersion = node -v 2>$null
        if (-not $nodeVersion) {
            Write-Error "Node.js is not installed. Please install Node.js 20+ from https://nodejs.org/"
        }
        
        $nodeVersion = $nodeVersion -replace 'v', ''
        $nodeMajor = [int]($nodeVersion -split '\.')[0]
        if ($nodeMajor -lt 20) {
            Write-Error "Node.js 20+ required. Found version $nodeVersion"
        }
        Write-Success "Node.js $nodeVersion detected"
    }
    catch {
        Write-Error "Node.js is not installed. Please install Node.js 20+ from https://nodejs.org/"
    }
    
    # Check npm
    try {
        $npmVersion = npm -v 2>$null
        if (-not $npmVersion) {
            Write-Error "npm is not installed"
        }
        Write-Success "npm $npmVersion detected"
    }
    catch {
        Write-Error "npm is not installed"
    }
    
    # Check git (optional)
    try {
        $gitVersion = git --version 2>$null
        if ($gitVersion) {
            $gitVersion = ($gitVersion -split ' ')[2]
            Write-Success "Git $gitVersion detected"
        }
    }
    catch {
        Write-Warning "Git is not installed. You'll need it for version control."
    }
    
    # Check Docker (optional)
    try {
        $dockerVersion = docker --version 2>$null
        if ($dockerVersion) {
            $dockerVersion = ($dockerVersion -split ' ')[2] -replace ',', ''
            Write-Success "Docker $dockerVersion detected"
            
            try {
                $composeVersion = docker-compose --version 2>$null
                if ($composeVersion) {
                    $composeVersion = ($composeVersion -split ' ')[2] -replace ',', ''
                    Write-Success "Docker Compose $composeVersion detected"
                }
            }
            catch {
                # Docker Compose might be a plugin
                try {
                    $composeVersion = docker compose version 2>$null
                    if ($composeVersion) {
                        $composeVersion = ($composeVersion -split ' ')[2] -replace ',', ''
                        Write-Success "Docker Compose $composeVersion detected"
                    }
                }
                catch {
                    Write-Warning "Docker Compose not found - optional for containerized development"
                }
            }
        }
    }
    catch {
        Write-Warning "Docker not found - optional for containerized development"
    }
    
    # Check PostgreSQL (optional)
    try {
        $psqlVersion = psql --version 2>$null
        if ($psqlVersion) {
            $psqlVersion = ($psqlVersion -split ' ')[2]
            Write-Success "PostgreSQL $psqlVersion detected"
        }
    }
    catch {
        Write-Warning "PostgreSQL not found - will use Docker or remote database"
    }
}

# Create project structure
function Create-ProjectStructure {
    if (Test-Path $ProjectName) {
        Write-Error "Directory '$ProjectName' already exists. Please choose a different name."
    }
    
    New-Item -ItemType Directory -Path $ProjectName -Force | Out-Null
    Set-Location $ProjectName
    Write-Success "Created directory structure"
}

# Initialize Git repository
function Init-Git {
    Write-Step "Initializing Git repository..."
    
    try {
        git init 2>$null | Out-Null
    }
    catch {
        Write-Warning "Git initialization failed"
    }
    
    @"
# dependencies
/node_modules
/.pnp
.pnp.js

# testing
/coverage

# next.js
/.next/
/out/

# production
/build

# misc
.DS_Store
*.pem

# debug
npm-debug.log*
yarn-debug.log*
yarn-error.log*

# local env files
.env*.local
.env

# vercel
.vercel

# typescript
*.tsbuildinfo
next-env.d.ts

# prisma
prisma/*.db
prisma/*.db-journal
prisma/migrations/*.sql

# docker
*.pid
*.pid.lock

# logs
logs/
*.log

# Windows
Thumbs.db
desktop.ini
"@ | Out-File -FilePath ".gitignore" -Encoding utf8
    
    Write-Success "Git initialized with .gitignore"
}

# Create package.json
function Create-PackageJson {
    Write-Step "Creating package.json..."
    
    @"
{
  "name": "$ProjectName",
  "version": "0.1.0",
  "private": true,
  "description": "A production-grade application generated by shipready",
  "scripts": {
    "dev": "next dev",
    "build": "next build",
    "start": "next start",
    "lint": "next lint",
    "type-check": "tsc --noEmit",
    "db:migrate": "prisma migrate dev",
    "db:deploy": "prisma migrate deploy",
    "db:seed": "tsx prisma/seed.ts",
    "db:studio": "prisma studio",
    "docker:up": "docker-compose up -d",
    "docker:down": "docker-compose down",
    "docker:logs": "docker-compose logs -f",
    "docker:build": "docker-compose build",
    "vercel:build": "npx prisma generate && npm run build"
  },
  "dependencies": {
    "@prisma/client": "5.14.0",
    "@radix-ui/react-avatar": "1.0.4",
    "@radix-ui/react-checkbox": "1.0.4",
    "@radix-ui/react-dialog": "1.0.5",
    "@radix-ui/react-dropdown-menu": "2.0.6",
    "@radix-ui/react-label": "2.0.2",
    "@radix-ui/react-popover": "1.0.7",
    "@radix-ui/react-select": "2.0.0",
    "@radix-ui/react-separator": "1.0.3",
    "@radix-ui/react-slot": "1.0.2",
    "@radix-ui/react-switch": "1.0.3",
    "@radix-ui/react-toast": "1.1.5",
    "@radix-ui/react-tooltip": "1.0.7",
    "@upstash/ratelimit": "0.3.4",
    "@upstash/redis": "1.27.0",
    "bcryptjs": "2.4.3",
    "class-variance-authority": "0.7.0",
    "clsx": "2.1.0",
    "lucide-react": "0.294.0",
    "next": "14.2.1",
    "next-auth": "5.0.0-beta.16",
    "pino": "8.19.0",
    "pino-pretty": "10.3.1",
    "react": "18.2.0",
    "react-dom": "18.2.0",
    "react-hook-form": "7.51.3",
    "react-email": "2.0.0",
    "resend": "3.0.0",
    "tailwind-merge": "2.2.0",
    "tailwindcss-animate": "1.0.7",
    "zod": "3.22.4"
  },
  "devDependencies": {
    "@types/bcryptjs": "2.4.6",
    "@types/node": "20.12.7",
    "@types/react": "18.2.79",
    "@types/react-dom": "18.2.25",
    "@typescript-eslint/eslint-plugin": "7.8.0",
    "@typescript-eslint/parser": "7.8.0",
    "autoprefixer": "10.4.19",
    "eslint": "8.57.0",
    "eslint-config-next": "14.2.1",
    "postcss": "8.4.38",
    "prisma": "5.14.0",
    "tailwindcss": "3.4.3",
    "tsx": "4.7.3",
    "typescript": "5.4.5"
  }
}
"@ | Out-File -FilePath "package.json" -Encoding utf8
    
    Write-Success "package.json created"
}

# Create TypeScript configuration
function Create-Tsconfig {
    Write-Step "Creating TypeScript configuration..."
    
    @"
{
  "compilerOptions": {
    "target": "ES2017",
    "lib": ["dom", "dom.iterable", "esnext"],
    "allowJs": true,
    "skipLibCheck": true,
    "strict": true,
    "forceConsistentCasingInFileNames": true,
    "noEmit": true,
    "esModuleInterop": true,
    "module": "esnext",
    "moduleResolution": "bundler",
    "resolveJsonModule": true,
    "isolatedModules": true,
    "jsx": "preserve",
    "incremental": true,
    "plugins": [
      {
        "name": "next"
      }
    ],
    "paths": {
      "@/*": ["./src/*"]
    }
  },
  "include": ["next-env.d.ts", "**/*.ts", "**/*.tsx", ".next/types/**/*.ts"],
  "exclude": ["node_modules"]
}
"@ | Out-File -FilePath "tsconfig.json" -Encoding utf8
    
    Write-Success "tsconfig.json created"
}

# Create Next.js configuration
function Create-NextConfig {
    Write-Step "Creating Next.js configuration..."
    
    @"
import type { NextConfig } from 'next'

const nextConfig: NextConfig = {
  output: 'standalone',
  images: {
    domains: [],
    formats: ['image/avif', 'image/webp'],
  },
  experimental: {
    optimizePackageImports: ['@radix-ui/react-icons', 'lucide-react'],
  },
  swcMinify: true,
  poweredByHeader: false,
  reactStrictMode: true,
  compress: true,
  compiler: {
    removeConsole: process.env.NODE_ENV === 'production',
  },
  redirects: async () => {
    return [
      {
        source: '/',
        destination: '/dashboard',
        permanent: true,
      },
    ]
  },
}

export default nextConfig
"@ | Out-File -FilePath "next.config.ts" -Encoding utf8
    
    Write-Success "next.config.ts created"
}

# Create Tailwind CSS configuration
function Create-TailwindConfig {
    Write-Step "Creating Tailwind CSS configuration..."
    
    @"
import type { Config } from 'tailwindcss'

const config: Config = {
  darkMode: ['class'],
  content: [
    './src/pages/**/*.{js,ts,jsx,tsx,mdx}',
    './src/components/**/*.{js,ts,jsx,tsx,mdx}',
    './src/app/**/*.{js,ts,jsx,tsx,mdx}',
  ],
  theme: {
    container: {
      center: true,
      padding: '2rem',
      screens: {
        '2xl': '1400px',
      },
    },
    extend: {
      colors: {
        border: 'hsl(var(--border))',
        input: 'hsl(var(--input))',
        ring: 'hsl(var(--ring))',
        background: 'hsl(var(--background))',
        foreground: 'hsl(var(--foreground))',
        primary: {
          DEFAULT: 'hsl(var(--primary))',
          foreground: 'hsl(var(--primary-foreground))',
        },
        secondary: {
          DEFAULT: 'hsl(var(--secondary))',
          foreground: 'hsl(var(--secondary-foreground))',
        },
        destructive: {
          DEFAULT: 'hsl(var(--destructive))',
          foreground: 'hsl(var(--destructive-foreground))',
        },
        muted: {
          DEFAULT: 'hsl(var(--muted))',
          foreground: 'hsl(var(--muted-foreground))',
        },
        accent: {
          DEFAULT: 'hsl(var(--accent))',
          foreground: 'hsl(var(--accent-foreground))',
        },
        popover: {
          DEFAULT: 'hsl(var(--popover))',
          foreground: 'hsl(var(--popover-foreground))',
        },
        card: {
          DEFAULT: 'hsl(var(--card))',
          foreground: 'hsl(var(--card-foreground))',
        },
      },
      borderRadius: {
        lg: 'var(--radius)',
        md: 'calc(var(--radius) - 2px)',
        sm: 'calc(var(--radius) - 4px)',
      },
      keyframes: {
        'accordion-down': {
          from: { height: '0' },
          to: { height: 'var(--radix-accordion-content-height)' },
        },
        'accordion-up': {
          from: { height: 'var(--radix-accordion-content-height)' },
          to: { height: '0' },
        },
      },
      animation: {
        'accordion-down': 'accordion-down 0.2s ease-out',
        'accordion-up': 'accordion-up 0.2s ease-out',
      },
    },
  },
  plugins: [require('tailwindcss-animate')],
}
export default config
"@ | Out-File -FilePath "tailwind.config.ts" -Encoding utf8
    
    Write-Success "tailwind.config.ts created"
}

# Create PostCSS configuration
function Create-PostcssConfig {
    Write-Step "Creating PostCSS configuration..."
    
    @"
module.exports = {
  plugins: {
    tailwindcss: {},
    autoprefixer: {},
  },
}
"@ | Out-File -FilePath "postcss.config.js" -Encoding utf8
    
    Write-Success "postcss.config.js created"
}

# Create ESLint configuration
function Create-EslintConfig {
    Write-Step "Creating ESLint configuration..."
    
    @"
{
  "extends": ["next/core-web-vitals", "plugin:@typescript-eslint/recommended"],
  "parser": "@typescript-eslint/parser",
  "plugins": ["@typescript-eslint"],
  "rules": {
    "@typescript-eslint/no-unused-vars": ["error", { "argsIgnorePattern": "^_" }],
    "@typescript-eslint/no-explicit-any": "error",
    "react-hooks/rules-of-hooks": "error",
    "react-hooks/exhaustive-deps": "warn",
    "no-console": ["warn", { "allow": ["error"] }]
  }
}
"@ | Out-File -FilePath ".eslintrc.json" -Encoding utf8
    
    Write-Success ".eslintrc.json created"
}

# Create environment variables
function Create-EnvFiles {
    Write-Step "Creating environment variable files..."
    
    @"
# Database
DATABASE_URL="postgresql://appuser:password@localhost:5432/appdb?schema=public"
POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=password

# Authentication
NEXTAUTH_SECRET="generate-a-secret-with-openssl-rand-hex-32"
NEXTAUTH_URL="http://localhost:3000"
NEXTAUTH_URL_INTERNAL="http://app:3000"

# Rate Limiting (Upstash Redis)
UPSTASH_REDIS_REST_URL="https://your-redis.upstash.io"
UPSTASH_REDIS_REST_TOKEN="your-token"

# Email (Resend)
RESEND_API_KEY="re_your-api-key"
EMAIL_FROM="noreply@yourdomain.com"

# Stripe (if using payments)
STRIPE_SECRET_KEY="sk_test_..."
STRIPE_WEBHOOK_SECRET="whsec_..."

# AWS S3 (if using file uploads)
AWS_ACCESS_KEY_ID=""
AWS_SECRET_ACCESS_KEY=""
AWS_REGION="us-east-1"
AWS_S3_BUCKET=""

# Application
NODE_ENV=development
LOG_LEVEL=info
NEXT_PUBLIC_APP_URL="http://localhost:3000"
NEXT_PUBLIC_APP_NAME="My App"

# CORS
CORS_ORIGIN="http://localhost:3000,https://yourdomain.com"
"@ | Out-File -FilePath ".env.example" -Encoding utf8
    
    @"
# Development environment
# Copy this to .env.local and modify as needed
DATABASE_URL="postgresql://appuser:password@localhost:5432/appdb?schema=public"
POSTGRES_DB=appdb
POSTGRES_USER=appuser
POSTGRES_PASSWORD=devpassword

NEXTAUTH_SECRET="dev-secret-key-please-change-in-production"
NEXTAUTH_URL="http://localhost:3000"

NODE_ENV=development
LOG_LEVEL=debug
NEXT_PUBLIC_APP_URL="http://localhost:3000"
NEXT_PUBLIC_APP_NAME="My App (Dev)"
"@ | Out-File -FilePath ".env.local.example" -Encoding utf8
    
    Write-Success "Environment files created"
}

# Create Docker files
function Create-DockerFiles {
    Write-Step "Creating Docker configuration..."
    
    @"
FROM node:20-alpine AS base

# Install dependencies only when needed
FROM base AS deps
RUN apk add --no-cache libc6-compat
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --only=production

# Build the application
FROM base AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npx prisma generate
RUN npm run build

# Production image
FROM base AS runner
WORKDIR /app
ENV NODE_ENV production
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nextjs
COPY --from=builder /app/public ./public
COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static
USER nextjs
EXPOSE 3000
ENV PORT 3000
CMD ["node", "server.js"]
"@ | Out-File -FilePath "Dockerfile" -Encoding utf8
    
    @"
version: '3.9'

services:
  db:
    image: postgres:16-alpine
    restart: unless-stopped
    environment:
      POSTGRES_DB: ${POSTGRES_DB:-appdb}
      POSTGRES_USER: ${POSTGRES_USER:-appuser}
      POSTGRES_PASSWORD: ${POSTGRES_PASSWORD:-devpassword}
    volumes:
      - postgres_data:/var/lib/postgresql/data
    ports:
      - "5432:5432"
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U ${POSTGRES_USER:-appuser}"]
      interval: 10s
      timeout: 5s
      retries: 5

  redis:
    image: redis:7-alpine
    restart: unless-stopped
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

  app:
    build: .
    restart: unless-stopped
    ports:
      - "3000:3000"
    env_file:
      - .env.local
    depends_on:
      db:
        condition: service_healthy
      redis:
        condition: service_started
    volumes:
      - ./src:/app/src
      - ./public:/app/public
    command: npm run dev

volumes:
  postgres_data:
  redis_data:
"@ | Out-File -FilePath "docker-compose.yml" -Encoding utf8
    
    Write-Success "Docker files created"
}

# Create Prisma setup
function Create-PrismaSetup {
    Write-Step "Creating Prisma setup..."
    
    New-Item -ItemType Directory -Path "prisma" -Force | Out-Null
    
    @"
generator client {
  provider = "prisma-client-js"
}

datasource db {
  provider = "postgresql"
  url      = env("DATABASE_URL")
}

model User {
  id         String    @id @default(uuid())
  email      String    @unique
  password   String?   @db.Text
  name       String?
  role       Role      @default(USER)
  createdAt  DateTime  @default(now()) @map("created_at")
  updatedAt  DateTime  @updatedAt @map("updated_at")
  
  // Add your relationships here
  // posts Post[]
  
  @@map("users")
  @@index([email])
}

enum Role {
  USER
  ADMIN
}

// Add your models below
// model Post {
//   id        String   @id @default(uuid())
//   title     String
//   content   String?  @db.Text
//   published Boolean  @default(false)
//   authorId  String
//   author    User     @relation(fields: [authorId], references: [id], onDelete: CASCADE)
//   createdAt DateTime @default(now()) @map("created_at")
//   updatedAt DateTime @updatedAt @map("updated_at")
//   
//   @@map("posts")
//   @@index([authorId])
// }
"@ | Out-File -FilePath "prisma\schema.prisma" -Encoding utf8
    
    @"
import { PrismaClient } from '@prisma/client'
import { hash } from 'bcryptjs'

const prisma = new PrismaClient()

async function main() {
  console.log('🌱 Seeding database...')

  // Create admin user
  const adminPassword = await hash('admin123', 10)
  const admin = await prisma.user.upsert({
    where: { email: 'admin@example.com' },
    update: {},
    create: {
      email: 'admin@example.com',
      password: adminPassword,
      name: 'Admin User',
      role: 'ADMIN',
    },
  })
  console.log(`👤 Created admin: ${admin.email}`)

  // Create regular user
  const userPassword = await hash('user123', 10)
  const user = await prisma.user.upsert({
    where: { email: 'user@example.com' },
    update: {},
    create: {
      email: 'user@example.com',
      password: userPassword,
      name: 'Regular User',
      role: 'USER',
    },
  })
  console.log(`👤 Created user: ${user.email}`)

  // Add your seed data here
  console.log('✅ Seeding complete!')
}

main()
  .catch((e) => {
    console.error('❌ Seeding failed:', e)
    process.exit(1)
  })
  .finally(async () => {
    await prisma.$disconnect()
  })
"@ | Out-File -FilePath "prisma\seed.ts" -Encoding utf8
    
    Write-Success "Prisma setup created"
}

# Create source directory structure
function Create-SourceStructure {
    Write-Step "Creating source directory structure..."
    
    $dirs = @(
        "src\app\api\health",
        "src\app\api\v1",
        "src\app\(auth)\login",
        "src\app\(auth)\register",
        "src\app\(dashboard)",
        "src\app\admin",
        "src\components\ui",
        "src\components\forms",
        "src\lib\validations",
        "src\lib\auth",
        "src\types",
        "src\hooks"
    )
    
    foreach ($dir in $dirs) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    
    # Create app layout
    @"
import type { Metadata } from 'next'
import { Inter } from 'next/font/google'
import './globals.css'
import { Toaster } from '@/components/ui/toaster'
import { AuthProvider } from '@/components/auth-provider'

const inter = Inter({ subsets: ['latin'] })

export const metadata: Metadata = {
  title: 'My App',
  description: 'Generated by shipready',
  metadataBase: new URL(process.env.NEXT_PUBLIC_APP_URL || 'http://localhost:3000'),
}

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode
}>) {
  return (
    <html lang="en">
      <body className={inter.className}>
        <AuthProvider>
          {children}
          <Toaster />
        </AuthProvider>
      </body>
    </html>
  )
}
"@ | Out-File -FilePath "src\app\layout.tsx" -Encoding utf8
    
    # Create globals.css
    @"
@tailwind base;
@tailwind components;
@tailwind utilities;

@layer base {
  :root {
    --background: 0 0% 100%;
    --foreground: 222.2 84% 4.9%;
    --card: 0 0% 100%;
    --card-foreground: 222.2 84% 4.9%;
    --popover: 0 0% 100%;
    --popover-foreground: 222.2 84% 4.9%;
    --primary: 221.2 83.2% 53.3%;
    --primary-foreground: 210 40% 98%;
    --secondary: 210 40% 96.1%;
    --secondary-foreground: 222.2 47.4% 11.2%;
    --muted: 210 40% 96.1%;
    --muted-foreground: 215.4 16.3% 46.9%;
    --accent: 210 40% 96.1%;
    --accent-foreground: 222.2 47.4% 11.2%;
    --destructive: 0 84.2% 60.2%;
    --destructive-foreground: 210 40% 98%;
    --border: 214.3 31.8% 91.4%;
    --input: 214.3 31.8% 91.4%;
    --ring: 221.2 83.2% 53.3%;
    --radius: 0.5rem;
  }

  .dark {
    --background: 222.2 84% 4.9%;
    --foreground: 210 40% 98%;
    --card: 222.2 84% 4.9%;
    --card-foreground: 210 40% 98%;
    --popover: 222.2 84% 4.9%;
    --popover-foreground: 210 40% 98%;
    --primary: 217.2 91.2% 59.8%;
    --primary-foreground: 222.2 47.4% 11.2%;
    --secondary: 217.2 32.6% 17.5%;
    --secondary-foreground: 210 40% 98%;
    --muted: 217.2 32.6% 17.5%;
    --muted-foreground: 215 20.2% 65.1%;
    --accent: 217.2 32.6% 17.5%;
    --accent-foreground: 210 40% 98%;
    --destructive: 0 62.8% 30.6%;
    --destructive-foreground: 210 40% 98%;
    --border: 217.2 32.6% 17.5%;
    --input: 217.2 32.6% 17.5%;
    --ring: 224.3 76.3% 48%;
  }
}

@layer base {
  * {
    @apply border-border;
  }
  body {
    @apply bg-background text-foreground;
  }
}
"@ | Out-File -FilePath "src\app\globals.css" -Encoding utf8
    
    # Create health check
    @"
import { prisma } from '@/lib/prisma'
import { NextResponse } from 'next/server'
import { logger } from '@/lib/logger'

export async function GET() {
  try {
    await prisma.$queryRaw`SELECT 1`
    
    return NextResponse.json({
      status: 'ok',
      timestamp: new Date().toISOString(),
      database: 'connected',
      version: process.env.npm_package_version ?? '0.1.0',
      environment: process.env.NODE_ENV,
    })
  } catch (error) {
    logger.error({ error }, 'Health check failed')
    
    return NextResponse.json(
      {
        status: 'error',
        timestamp: new Date().toISOString(),
        database: 'disconnected',
        error: 'Database connection failed',
      },
      { status: 503 }
    )
  }
}
"@ | Out-File -FilePath "src\app\api\health\route.ts" -Encoding utf8
    
    Write-Success "Source structure created"
}

# Create essential lib files
function Create-LibFiles {
    Write-Step "Creating library files..."
    
    # Prisma client
    @"
import { PrismaClient } from '@prisma/client'
import { logger } from './logger'

const globalForPrisma = globalThis as unknown as { prisma: PrismaClient }

export const prisma =
  globalForPrisma.prisma ??
  new PrismaClient({
    log: [
      { emit: 'event', level: 'query' },
      { emit: 'event', level: 'error' },
      { emit: 'event', level: 'warn' },
    ],
  })

prisma.$on('error', (e) => {
  logger.error({ err: e }, 'Prisma error')
})

prisma.$on('warn', (e) => {
  logger.warn({ err: e }, 'Prisma warning')
})

if (process.env.NODE_ENV !== 'production') {
  globalForPrisma.prisma = prisma
}
"@ | Out-File -FilePath "src\lib\prisma.ts" -Encoding utf8
    
    # Logger
    @"
import pino from 'pino'

export const logger = pino({
  level: process.env.LOG_LEVEL ?? 'info',
  redact: ['password', 'token', 'secret', 'authorization', 'cookie', '*.password'],
  ...(process.env.NODE_ENV !== 'production' && {
    transport: {
      target: 'pino-pretty',
      options: {
        colorize: true,
        translateTime: 'HH:MM:ss',
        ignore: 'pid,hostname',
      },
    },
  }),
})
"@ | Out-File -FilePath "src\lib\logger.ts" -Encoding utf8
    
    # Environment validation
    @"
import { z } from 'zod'

const envSchema = z.object({
  DATABASE_URL: z.string().url(),
  NEXTAUTH_SECRET: z.string().min(32),
  NEXTAUTH_URL: z.string().url(),
  NODE_ENV: z.enum(['development', 'test', 'production']).default('development'),
  LOG_LEVEL: z.enum(['debug', 'info', 'warn', 'error']).default('info'),
  NEXT_PUBLIC_APP_URL: z.string().url().default('http://localhost:3000'),
  NEXT_PUBLIC_APP_NAME: z.string().default('My App'),
  CORS_ORIGIN: z.string().optional().default('http://localhost:3000'),
  
  // Optional but recommended
  UPSTASH_REDIS_REST_URL: z.string().url().optional(),
  UPSTASH_REDIS_REST_TOKEN: z.string().optional(),
  RESEND_API_KEY: z.string().optional(),
  EMAIL_FROM: z.string().email().optional(),
})

const _env = envSchema.safeParse(process.env)

if (!_env.success) {
  console.error('❌ Invalid environment variables:\n', _env.error.format())
  process.exit(1)
}

export const env = _env.data
"@ | Out-File -FilePath "src\lib\env.ts" -Encoding utf8
    
    # Rate limiting
    @"
import { Ratelimit } from '@upstash/ratelimit'
import { Redis } from '@upstash/redis'
import { env } from './env'

let ratelimit: Ratelimit | null = null

if (env.UPSTASH_REDIS_REST_URL && env.UPSTASH_REDIS_REST_TOKEN) {
  const redis = new Redis({
    url: env.UPSTASH_REDIS_REST_URL,
    token: env.UPSTASH_REDIS_REST_TOKEN,
  })

  ratelimit = new Ratelimit({
    redis,
    limiter: Ratelimit.slidingWindow(5, '15m'),
    analytics: true,
    prefix: 'ratelimit',
  })
}

export const rateLimit = ratelimit
"@ | Out-File -FilePath "src\lib\rate-limit.ts" -Encoding utf8
    
    Write-Success "Library files created"
}

# Create README
function Create-Readme {
    Write-Step "Creating README.md..."
    
    $ReadmeContent = @'
# $ProjectName

A production-grade application generated by **shipready** — a complete, deploy-ready codebase with security, database, error handling, API design, environment, performance, frontend, and DevOps baked in from line one.

## 🚀 Tech Stack

- **Framework:** Next.js 14 (App Router)
- **Language:** TypeScript (strict mode)
- **Database:** PostgreSQL with Prisma ORM
- **Auth:** NextAuth.js v5
- **Styling:** Tailwind CSS
- **Forms:** react-hook-form + Zod
- **Logging:** Pino
- **Rate Limiting:** Upstash Redis
- **Email:** Resend + react-email
- **Deployment:** Vercel (primary) + Docker

## 📋 Prerequisites

- Node.js 20+
- npm 9+
- PostgreSQL 16+ (or Docker)
- Git

## 🛠️ Quick Setup

1. **Clone the repository:**
   ```bash
   git clone <your-repo-url>
   cd $ProjectName
   ```

2. **Install dependencies:**
   ```bash
   npm install
   ```

3. **Set up environment variables:**
   ```bash
   cp .env.local.example .env.local
   # Edit .env.local with your values
   ```

4. **Start the database (with Docker):**
   ```bash
   npm run docker:up
   ```

5. **Run database migrations:**
   ```bash
   npm run db:migrate
   ```

6. **Seed the database:**
   ```bash
   npm run db:seed
   ```

7. **Start the development server:**
   ```bash
   npm run dev
   ```

   Your app is now running at **http://localhost:3000**

## 🔑 Default Admin Credentials

- **Email:** admin@example.com
- **Password:** admin123

**Please change these credentials immediately in production!**

## 📦 Available Scripts

| Command | Description |
|---------|-------------|
| `npm run dev` | Start development server |
| `npm run build` | Build for production |
| `npm run start` | Start production server |
| `npm run lint` | Run ESLint |
| `npm run type-check` | Type check TypeScript |
| `npm run db:migrate` | Run database migrations |
| `npm run db:deploy` | Deploy migrations to production |
| `npm run db:seed` | Seed database with initial data |
| `npm run db:studio` | Open Prisma Studio |
| `npm run docker:up` | Start Docker containers |
| `npm run docker:down` | Stop Docker containers |
| `npm run docker:build` | Build Docker image |

## 🏗️ Project Structure

```
$ProjectName/
├── src/
│   ├── app/               # Next.js App Router
│   │   ├── (auth)/        # Authentication routes
│   │   │   ├── login/
│   │   │   └── register/
│   │   ├── (dashboard)/   # Dashboard routes
│   │   ├── admin/         # Admin panel
│   │   ├── api/           # API routes
│   │   │   ├── health/    # Health check
│   │   │   │   └── route.ts
│   │   │   └── v1/        # Versioned API
│   │   ├── globals.css    # Global Tailwind styles
│   │   └── layout.tsx     # Root layout
│   ├── components/        # React components
│   │   ├── ui/            # UI components
│   │   └── forms/         # Form components
│   ├── hooks/             # Custom React hooks
│   ├── lib/               # Utility functions and clients
│   │   ├── auth.ts        # Auth configuration
│   │   ├── env.ts         # Zod environment schema
│   │   ├── logger.ts      # Pino logger configuration
│   │   ├── prisma.ts      # Prisma client instance
│   │   └── rate-limit.ts  # Upstash rate limiting
│   └── types/             # TypeScript types
└── prisma/                # Prisma ORM schema and migrations
    ├── schema.prisma
    └── seed.ts
```
'@
    $ReadmeContent = $ReadmeContent -replace '\$ProjectName', $ProjectName

    $ReadmeContent | Out-File -FilePath "README.md" -Encoding utf8
    
    Write-Success "README.md created"
}

# Run the installation
Check-Requirements
Create-ProjectStructure
Init-Git
Create-PackageJson
Create-Tsconfig
Create-NextConfig
Create-TailwindConfig
Create-PostcssConfig
Create-EslintConfig
Create-EnvFiles
Create-DockerFiles
Create-PrismaSetup
Create-SourceStructure
Create-LibFiles
Create-Readme

Write-Step "Installing dependencies..."
npm install

Write-Success "Project '$ProjectName' created successfully!"
Write-Host ""
Write-Host "To get started:"
Write-Host "  cd $ProjectName"
Write-Host "  npm run dev"
Write-Host ""