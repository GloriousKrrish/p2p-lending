-- ════════════════════════════════════════════════════
--  LendRoom — PostgreSQL Database Schema
--  ACID-compliant, Production-Ready
-- ════════════════════════════════════════════════════

-- Extensions
CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm"; -- for full-text search

-- ──────────────────────────────────────────────────
--  USERS
-- ──────────────────────────────────────────────────
CREATE TABLE users (
    id              SERIAL PRIMARY KEY,
    email           VARCHAR(255) UNIQUE NOT NULL,
    password_hash   VARCHAR(255) NOT NULL,
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    phone           VARCHAR(20),
    role            VARCHAR(20) NOT NULL CHECK (role IN ('lender','borrower','both','admin')),
    kyc_status      VARCHAR(20) DEFAULT 'pending' CHECK (kyc_status IN ('pending','verified','rejected')),
    kyc_document    VARCHAR(500),   -- S3 URL
    pan_number      VARCHAR(20),
    aadhar_hash     VARCHAR(255),   -- hashed for privacy
    is_active       BOOLEAN DEFAULT TRUE,
    last_login      TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_users_email ON users(email);
CREATE INDEX idx_users_role ON users(role);

-- ──────────────────────────────────────────────────
--  WALLETS
-- ──────────────────────────────────────────────────
CREATE TABLE wallets (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER UNIQUE NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    balance     NUMERIC(15,2) DEFAULT 0.00 CHECK (balance >= 0),
    locked_amount NUMERIC(15,2) DEFAULT 0.00,  -- funds locked in active positions
    currency    VARCHAR(5) DEFAULT 'INR',
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_wallets_user ON wallets(user_id);

-- ──────────────────────────────────────────────────
--  BANK ACCOUNTS (for withdrawals)
-- ──────────────────────────────────────────────────
CREATE TABLE bank_accounts (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id),
    account_number  VARCHAR(50) NOT NULL,
    ifsc_code       VARCHAR(20) NOT NULL,
    bank_name       VARCHAR(100),
    account_holder  VARCHAR(200),
    is_verified     BOOLEAN DEFAULT FALSE,
    is_primary      BOOLEAN DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_bank_accounts_user ON bank_accounts(user_id);

-- ──────────────────────────────────────────────────
--  CREDIT PROFILES
-- ──────────────────────────────────────────────────
CREATE TABLE credit_profiles (
    id                  SERIAL PRIMARY KEY,
    user_id             INTEGER UNIQUE NOT NULL REFERENCES users(id),
    score               SMALLINT DEFAULT 650 CHECK (score BETWEEN 300 AND 900),
    total_borrowed      NUMERIC(15,2) DEFAULT 0,
    total_repaid        NUMERIC(15,2) DEFAULT 0,
    loans_completed     INTEGER DEFAULT 0,
    loans_defaulted     INTEGER DEFAULT 0,
    on_time_payment_pct NUMERIC(5,2) DEFAULT 100.00,
    last_updated        TIMESTAMPTZ DEFAULT NOW(),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────────────
--  ROOMS
-- ──────────────────────────────────────────────────
CREATE TABLE rooms (
    id                  SERIAL PRIMARY KEY,
    name                VARCHAR(100) NOT NULL,
    description         TEXT,
    interest_rate       NUMERIC(5,2) NOT NULL CHECK (interest_rate BETWEEN 1 AND 50),
    max_borrow_limit    NUMERIC(15,2) NOT NULL,
    min_lend_amount     NUMERIC(15,2) NOT NULL DEFAULT 1000,
    max_loan_duration   SMALLINT NOT NULL DEFAULT 24,  -- months
    risk_level          VARCHAR(10) NOT NULL CHECK (risk_level IN ('low','medium','high')),
    processing_fee_pct  NUMERIC(4,2) DEFAULT 0.50,
    status              VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','paused','closed')),
    created_by          INTEGER REFERENCES users(id),
    cover_emoji         VARCHAR(10) DEFAULT '🏦',
    invite_code         VARCHAR(20) UNIQUE DEFAULT UPPER(SUBSTR(MD5(RANDOM()::TEXT), 1, 8)),
    created_at          TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at          TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_rooms_status ON rooms(status);
CREATE INDEX idx_rooms_risk ON rooms(risk_level);

-- ──────────────────────────────────────────────────
--  ROOM MEMBERS
-- ──────────────────────────────────────────────────
CREATE TABLE room_members (
    id          SERIAL PRIMARY KEY,
    room_id     INTEGER NOT NULL REFERENCES rooms(id),
    user_id     INTEGER NOT NULL REFERENCES users(id),
    role        VARCHAR(20) DEFAULT 'lender' CHECK (role IN ('lender','borrower','both','admin')),
    status      VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','suspended','left')),
    joined_at   TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(room_id, user_id)
);
CREATE INDEX idx_room_members_room ON room_members(room_id);
CREATE INDEX idx_room_members_user ON room_members(user_id);

-- ──────────────────────────────────────────────────
--  LENDING POSITIONS
-- ──────────────────────────────────────────────────
CREATE TABLE lending_positions (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id),
    room_id         INTEGER NOT NULL REFERENCES rooms(id),
    amount          NUMERIC(15,2) NOT NULL CHECK (amount > 0),
    interest_rate   NUMERIC(5,2) NOT NULL,  -- snapshot at time of deposit
    duration_months SMALLINT NOT NULL,
    start_date      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    maturity_date   TIMESTAMPTZ NOT NULL,
    status          VARCHAR(20) DEFAULT 'active' CHECK (status IN ('active','matured','withdrawn')),
    total_earned    NUMERIC(15,2) DEFAULT 0,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_lending_user ON lending_positions(user_id);
CREATE INDEX idx_lending_room ON lending_positions(room_id);
CREATE INDEX idx_lending_status ON lending_positions(status);
CREATE INDEX idx_lending_maturity ON lending_positions(maturity_date);

-- ──────────────────────────────────────────────────
--  LOANS
-- ──────────────────────────────────────────────────
CREATE TABLE loans (
    id              SERIAL PRIMARY KEY,
    borrower_id     INTEGER NOT NULL REFERENCES users(id),
    room_id         INTEGER NOT NULL REFERENCES rooms(id),
    principal       NUMERIC(15,2) NOT NULL CHECK (principal > 0),
    interest_rate   NUMERIC(5,2) NOT NULL,  -- snapshot
    duration_months SMALLINT NOT NULL,
    emi_amount      NUMERIC(15,2) NOT NULL,
    purpose         VARCHAR(500),
    loan_type       VARCHAR(50) DEFAULT 'personal',  -- personal/business/vehicle
    status          VARCHAR(20) DEFAULT 'pending'
                    CHECK (status IN ('pending','active','completed','defaulted','rejected')),
    risk_score      SMALLINT CHECK (risk_score BETWEEN 0 AND 100),
    applied_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    approved_at     TIMESTAMPTZ,
    disbursed_at    TIMESTAMPTZ,
    completed_at    TIMESTAMPTZ,
    next_emi_date   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_loans_borrower ON loans(borrower_id);
CREATE INDEX idx_loans_room ON loans(room_id);
CREATE INDEX idx_loans_status ON loans(status);
CREATE INDEX idx_loans_next_emi ON loans(next_emi_date) WHERE status = 'active';

-- ──────────────────────────────────────────────────
--  REPAYMENTS
-- ──────────────────────────────────────────────────
CREATE TABLE repayments (
    id          SERIAL PRIMARY KEY,
    loan_id     INTEGER NOT NULL REFERENCES loans(id),
    user_id     INTEGER NOT NULL REFERENCES users(id),
    amount      NUMERIC(15,2) NOT NULL,
    principal   NUMERIC(15,2),  -- portion going to principal
    interest    NUMERIC(15,2),  -- portion going to interest
    is_late     BOOLEAN DEFAULT FALSE,
    late_fee    NUMERIC(10,2) DEFAULT 0,
    paid_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_repayments_loan ON repayments(loan_id);
CREATE INDEX idx_repayments_user ON repayments(user_id);

-- ──────────────────────────────────────────────────
--  TRANSACTIONS (unified audit log)
-- ──────────────────────────────────────────────────
CREATE TABLE transactions (
    id              BIGSERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id),
    room_id         INTEGER REFERENCES rooms(id),
    type            VARCHAR(50) NOT NULL
                    CHECK (type IN ('deposit','withdrawal','lend','loan_disbursed','repayment','interest_credit','fee','refund','transfer')),
    amount          NUMERIC(15,2) NOT NULL,
    balance_after   NUMERIC(15,2),  -- snapshot of wallet balance
    reference_id    VARCHAR(255),   -- external payment ID or internal ID
    description     VARCHAR(500),
    metadata        JSONB,          -- flexible extra data
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_txns_user ON transactions(user_id);
CREATE INDEX idx_txns_room ON transactions(room_id);
CREATE INDEX idx_txns_type ON transactions(type);
CREATE INDEX idx_txns_created ON transactions(created_at DESC);
CREATE INDEX idx_txns_user_date ON transactions(user_id, created_at DESC);

-- ──────────────────────────────────────────────────
--  WITHDRAWALS
-- ──────────────────────────────────────────────────
CREATE TABLE withdrawals (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id),
    amount          NUMERIC(15,2) NOT NULL,
    bank_account_id INTEGER REFERENCES bank_accounts(id),
    status          VARCHAR(20) DEFAULT 'pending' CHECK (status IN ('pending','processing','completed','failed')),
    utr_number      VARCHAR(100),   -- bank reference
    processed_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- ──────────────────────────────────────────────────
--  NOTIFICATIONS
-- ──────────────────────────────────────────────────
CREATE TABLE notifications (
    id          SERIAL PRIMARY KEY,
    user_id     INTEGER NOT NULL REFERENCES users(id),
    type        VARCHAR(50) NOT NULL,
    title       VARCHAR(200) NOT NULL,
    message     TEXT,
    is_read     BOOLEAN DEFAULT FALSE,
    data        JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_notif_user ON notifications(user_id);
CREATE INDEX idx_notif_unread ON notifications(user_id) WHERE is_read = FALSE;

-- ──────────────────────────────────────────────────
--  AUDIT LOG
-- ──────────────────────────────────────────────────
CREATE TABLE audit_logs (
    id          BIGSERIAL PRIMARY KEY,
    user_id     INTEGER REFERENCES users(id),
    action      VARCHAR(100) NOT NULL,
    entity      VARCHAR(50),
    entity_id   INTEGER,
    old_value   JSONB,
    new_value   JSONB,
    ip_address  INET,
    user_agent  VARCHAR(500),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX idx_audit_user ON audit_logs(user_id);
CREATE INDEX idx_audit_entity ON audit_logs(entity, entity_id);

-- ──────────────────────────────────────────────────
--  TRIGGERS — auto update updated_at
-- ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION update_updated_at()
RETURNS TRIGGER AS $$
BEGIN NEW.updated_at = NOW(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated_at         BEFORE UPDATE ON users          FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_wallets_updated_at       BEFORE UPDATE ON wallets        FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_rooms_updated_at         BEFORE UPDATE ON rooms          FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_lending_updated_at       BEFORE UPDATE ON lending_positions FOR EACH ROW EXECUTE FUNCTION update_updated_at();
CREATE TRIGGER trg_loans_updated_at         BEFORE UPDATE ON loans          FOR EACH ROW EXECUTE FUNCTION update_updated_at();

-- ──────────────────────────────────────────────────
--  TRIGGER — auto balance snapshot in transactions
-- ──────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION snapshot_wallet_balance()
RETURNS TRIGGER AS $$
BEGIN
  SELECT balance INTO NEW.balance_after FROM wallets WHERE user_id = NEW.user_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_txn_balance_snapshot
BEFORE INSERT ON transactions
FOR EACH ROW EXECUTE FUNCTION snapshot_wallet_balance();

-- ──────────────────────────────────────────────────
--  SEED DATA
-- ──────────────────────────────────────────────────

-- Admin user (password: Admin@123)
INSERT INTO users (email, password_hash, first_name, last_name, role, kyc_status)
VALUES ('admin@lendroom.com', '$2a$12$examplehashedpassword', 'Admin', 'LendRoom', 'admin', 'verified');

-- Sample rooms
INSERT INTO rooms (name, description, interest_rate, max_borrow_limit, min_lend_amount, max_loan_duration, risk_level, created_by, cover_emoji) VALUES
  ('Alpha Growth Room',  'High-yield pool for experienced lenders', 14.50, 500000, 1000, 24, 'medium', 1, '🚀'),
  ('Safe Harbor Fund',   'Low-risk conservative lending pool',      9.80,  300000, 500,  18, 'low',    1, '⚓'),
  ('Velocity Capital',   'Fast-moving short-term loan pool',        18.20, 200000, 2000, 12, 'high',   1, '⚡'),
  ('Green Futures',      'ESG-focused sustainable lending',         11.00, 400000, 1000, 24, 'low',    1, '🌱'),
  ('Diamond Pool',       'Ultra-premium high-net-worth room',       16.80, 1000000,5000, 36, 'medium', 1, '💎');

-- ──────────────────────────────────────────────────
--  VIEWS (for reporting)
-- ──────────────────────────────────────────────────

-- Room summary view
CREATE VIEW room_summary AS
SELECT
    r.*,
    COUNT(DISTINCT rm.user_id) AS member_count,
    COALESCE(SUM(lp.amount), 0) AS pool_balance,
    COALESCE(SUM(l.principal), 0) AS active_loans,
    COALESCE(SUM(lp.amount), 0) - COALESCE(SUM(l.principal), 0) AS available_liquidity
FROM rooms r
LEFT JOIN room_members rm ON rm.room_id = r.id AND rm.status = 'active'
LEFT JOIN lending_positions lp ON lp.room_id = r.id AND lp.status = 'active'
LEFT JOIN loans l ON l.room_id = r.id AND l.status = 'active'
GROUP BY r.id;

-- User portfolio view
CREATE VIEW user_portfolio AS
SELECT
    u.id AS user_id,
    u.email,
    u.first_name,
    u.last_name,
    w.balance AS wallet_balance,
    COALESCE(SUM(lp.amount), 0) AS total_lent,
    COALESCE(SUM(l.principal), 0) AS total_borrowed,
    cp.score AS credit_score
FROM users u
LEFT JOIN wallets w ON w.user_id = u.id
LEFT JOIN lending_positions lp ON lp.user_id = u.id AND lp.status = 'active'
LEFT JOIN loans l ON l.borrower_id = u.id AND l.status = 'active'
LEFT JOIN credit_profiles cp ON cp.user_id = u.id
GROUP BY u.id, w.balance, cp.score;
