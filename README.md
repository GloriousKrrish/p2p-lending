# 🏦 LendRoom — Complete Project Documentation

> "Your money grows while you sleep."

---

## 📁 Project Structure

```
LendRoom/
├── index.html                 ← Complete Frontend (single-file SPA)
├── backend/
│   ├── server.js              ← Node.js + Express REST API
│   ├── package.json           ← Dependencies
│   └── .env.example           ← Environment variables
├── database/
│   └── schema.sql             ← PostgreSQL schema + seed data
└── README.md                  ← This file
```

---

## 🚀 Quick Start

### 1. Frontend (Static)
Just open `index.html` in a browser. Fully functional demo with no backend needed for UI.

### 2. Backend Setup

```bash
cd backend
npm install
cp .env.example .env
# Fill in your .env values
npm run dev
```

### 3. Database Setup

```bash
# Create database
createdb lendroom

# Run schema
psql -d lendroom -f database/schema.sql
```

---

## 🌍 Environment Variables

```env
DATABASE_URL=postgresql://user:password@localhost:5432/lendroom
JWT_SECRET=your_super_secret_jwt_key_here
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxxxxxx
FRONTEND_URL=http://localhost:3000
PORT=5000
NODE_ENV=development
```

---

## 📦 Backend Dependencies

```json
{
  "express": "^4.18.2",
  "pg": "^8.11.3",
  "bcryptjs": "^2.4.3",
  "jsonwebtoken": "^9.0.2",
  "dotenv": "^16.3.1",
  "cors": "^2.8.5",
  "helmet": "^7.1.0",
  "express-validator": "^7.0.1",
  "node-cron": "^3.0.3",
  "razorpay": "^2.9.2",
  "winston": "^3.11.0"
}
```

---

## 🔌 API Reference

### Authentication

| Method | Endpoint | Description |
|--------|----------|-------------|
| POST | `/api/auth/register` | Register new user |
| POST | `/api/auth/login` | Login & get JWT token |

**Register Request:**
```json
{
  "email": "user@example.com",
  "password": "SecurePass123",
  "firstName": "Rahul",
  "lastName": "Sharma",
  "role": "both"
}
```

**Login Response:**
```json
{
  "token": "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...",
  "user": {
    "id": 1,
    "email": "user@example.com",
    "firstName": "Rahul",
    "lastName": "Sharma",
    "role": "both",
    "walletBalance": 0
  }
}
```

---

### Users

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/users/me` | Get own profile | ✅ |
| GET | `/api/users/dashboard` | Dashboard stats | ✅ |

---

### Rooms

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/rooms` | List rooms (paginated) | ✅ |
| GET | `/api/rooms/:id` | Room detail + activity | ✅ |
| POST | `/api/rooms` | Create room | ✅ |
| POST | `/api/rooms/:id/join` | Join room | ✅ |

**Create Room Request:**
```json
{
  "name": "My Growth Fund",
  "description": "A community pool for disciplined lenders",
  "interestRate": 12.5,
  "maxBorrowLimit": 500000,
  "minLendAmount": 1000,
  "maxLoanDuration": 24,
  "riskLevel": "medium"
}
```

---

### Lending

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/lend` | Open lending position | ✅ |
| GET | `/api/lend/positions` | My positions | ✅ |

**Lend Request:**
```json
{
  "roomId": 1,
  "amount": 50000,
  "durationMonths": 12
}
```

**Lend Response:**
```json
{
  "message": "Lending position opened",
  "position": { "id": 42, "amount": 50000, ... },
  "expectedMonthlyReturn": 604.17
}
```

---

### Borrowing

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| POST | `/api/loans/apply` | Apply for loan | ✅ |
| POST | `/api/loans/:id/repay` | Make EMI repayment | ✅ |
| GET | `/api/loans/my` | My active loans | ✅ |

**Loan Application Request:**
```json
{
  "roomId": 1,
  "amount": 25000,
  "durationMonths": 12,
  "purpose": "Home renovation"
}
```

**Loan Response:**
```json
{
  "loan": { "id": 7, "principal": 25000, ... },
  "emi": 2258,
  "totalPayable": 27096,
  "riskScore": 18,
  "status": "auto-approved"
}
```

---

### Wallet

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/wallet` | Wallet details | ✅ |
| POST | `/api/wallet/deposit/create-order` | Create Razorpay order | ✅ |
| POST | `/api/wallet/deposit/verify` | Verify & credit payment | ✅ |
| POST | `/api/wallet/withdraw` | Initiate withdrawal | ✅ |

---

### Transactions

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/transactions` | History (filterable) | ✅ |

**Query params:** `page`, `limit`, `type`, `roomId`, `startDate`, `endDate`

---

### Admin

| Method | Endpoint | Description | Auth |
|--------|----------|-------------|------|
| GET | `/api/admin/stats` | Platform-wide stats | Admin |
| GET | `/api/admin/users` | All users | Admin |

---

## 🗄️ Database Schema

### Tables

| Table | Purpose |
|-------|---------|
| `users` | User accounts with KYC fields |
| `wallets` | One wallet per user, balance tracking |
| `bank_accounts` | Linked bank accounts for withdrawals |
| `credit_profiles` | Credit score & history |
| `rooms` | Financial pool rooms |
| `room_members` | Room membership |
| `lending_positions` | Active lending stakes |
| `loans` | Borrow applications & active loans |
| `repayments` | EMI payment records |
| `transactions` | Unified audit trail |
| `withdrawals` | Bank withdrawal requests |
| `notifications` | User notifications |
| `audit_logs` | Admin audit trail |

### Key Relationships
```
users ──< wallets (1:1)
users ──< credit_profiles (1:1)
users ──< room_members >── rooms
users ──< lending_positions >── rooms
users ──< loans >── rooms
loans ──< repayments
users ──< transactions
```

---

## 💰 Core Business Logic

### Pool-Based Lending Flow

```
Lender deposits ₹50,000 → Wallet deducted → Lending Position created
                         → Room pool balance increases

Borrower applies → Credit check → Risk score → Auto/Manual approve
                → Loan disbursed to wallet from pool

Daily cron job → Calculate daily interest per position
              → Credit to lender wallets
              → Log interest_credit transactions

Borrower repays EMI → Wallet deducted → Repayment recorded
                    → Pool replenished → Credit score updated
```

### Interest Calculation

```
Daily Interest = (Principal × Annual Rate%) / 365
Monthly Interest = Daily Interest × 30
EMI = P × r × (1+r)^n / ((1+r)^n - 1)
  where r = monthly rate, n = months
```

### Credit Score Logic

| Score Range | Category | Max Loan |
|------------|----------|----------|
| 750 – 900 | Excellent | ₹5,00,000 |
| 700 – 749 | Good | ₹3,00,000 |
| 650 – 699 | Fair | ₹1,00,000 |
| 600 – 649 | Poor | ₹25,000 |
| < 600 | Denied | — |

Score improves +15 per completed loan, -30 per default.

### AI Risk Scoring

```
Risk Score (0–100):
+ Credit score < 600 → +30
+ Credit score < 700 → +15
+ Loan > ₹1,00,000  → +20
+ Loan > ₹50,000    → +10
+ Duration > 24mo   → +10

Auto-approve if: risk < 40 AND credit ≥ 650
Manual review if: risk 40–60
Reject if: risk > 60 OR credit < 500
```

---

## 🔐 Security Features

- **Passwords**: bcrypt with cost factor 12
- **JWT**: 7-day expiry, HS256 signed
- **Input Validation**: express-validator on all routes
- **Wallet Safety**: `CHECK (balance >= 0)` at DB level
- **Payment Signature**: Razorpay HMAC-SHA256 verification
- **SQL Injection**: Parameterized queries throughout
- **CORS**: Restricted to frontend origin
- **Helmet**: Security headers (XSS, HSTS, etc.)
- **Audit Log**: Every financial action logged

---

## 📱 Frontend Pages

| Page | Description |
|------|-------------|
| Landing | Hero + features + trust stats + particle animation |
| Auth | Login/Signup with demo mode |
| Dashboard | Stats, portfolio chart, activity feed |
| Rooms | Grid of all rooms with join/lend actions |
| Room Detail | Deep-dive: pool stats, rules, activity |
| Wallet | Balance, deposit/withdraw, cashflow chart |
| Lend | Position calculator + active positions |
| Borrow | EMI calculator + credit score + loan status |
| Transactions | Full history with filters |
| Notifications | Real-time alerts |
| Admin | Platform stats, user management |

---

## 🔄 Automated Jobs (Cron)

| Schedule | Job | Description |
|----------|-----|-------------|
| Daily 00:00 | Interest Distribution | Credits daily interest to all active lenders |
| Daily 09:00 | EMI Reminders | Sends notifications for upcoming EMIs |
| Weekly | Credit Score Refresh | Recalculates scores based on behavior |
| Monthly | Maturity Check | Returns principal for matured positions |

---

## 🚀 Deployment Guide

### Frontend
- Deploy `index.html` to Vercel / Netlify / S3 + CloudFront
- Zero build step needed (pure HTML/CSS/JS)

### Backend
```bash
# Production
NODE_ENV=production node server.js

# With PM2
pm2 start server.js --name lendroom-api

# Docker
docker build -t lendroom-api .
docker run -p 5000:5000 --env-file .env lendroom-api
```

### Database
- Use managed PostgreSQL: **Supabase** (free tier), **Railway**, or **AWS RDS**
- Run `schema.sql` once on fresh database

### Recommended Stack
- **Frontend**: Vercel (free)
- **Backend**: Railway or Render (free tier)
- **Database**: Supabase (free tier — 500MB)
- **Payments**: Razorpay (0% setup cost)
- **Total Cost to Launch**: ₹0/month to start

---

## 🎯 Roadmap (Post-MVP)

- [ ] Mobile App (React Native)
- [ ] UPI AutoPay for EMI collection
- [ ] Room invite codes
- [ ] Referral program
- [ ] Lender insurance pool
- [ ] Advanced AI risk models (ML-based)
- [ ] Multi-currency support
- [ ] WhatsApp notifications
- [ ] Video KYC integration
- [ ] Secondary market (sell lending positions)

---

## 📊 Sample Data

The schema seeds:
- 1 admin user
- 5 ready-to-use rooms (Alpha, Safe Harbor, Velocity, Green Futures, Diamond)

To add more sample data:
```sql
-- Sample lender
INSERT INTO users (email, password_hash, first_name, last_name, role, kyc_status)
VALUES ('rahul@test.com', 'hashed_password', 'Rahul', 'Sharma', 'both', 'verified');
```

---

*Built with ❤️ for the LendRoom vision. Ready for investor demo.*
