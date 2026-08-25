USE lego_sandbox;

-- Standalone forward-engineered DDL for the Marketplace Sync model slice.
-- Intended for bootstrapping lego_sandbox without running the full database deployer.
-- Existing referenced tables expected to already exist:
--   item_inventory, marketplace_listing, transactions, transaction_item

CREATE TABLE IF NOT EXISTS marketplace_order_sync_run (
    marketplace_order_sync_run_id INT NOT NULL AUTO_INCREMENT,
    marketplace_code VARCHAR(30) NOT NULL,
    sync_job_name VARCHAR(100) NULL,
    sync_direction VARCHAR(20) NOT NULL,
    sync_status_code VARCHAR(30) NOT NULL,
    started_at DATETIME NOT NULL,
    completed_at DATETIME NULL,
    orders_discovered INT NOT NULL DEFAULT 0,
    orders_fetched INT NOT NULL DEFAULT 0,
    orders_failed INT NOT NULL DEFAULT 0,
    error_message TEXT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (marketplace_order_sync_run_id),
    INDEX idx_marketplace_order_sync_run_marketplace_status (marketplace_code, sync_status_code),
    INDEX idx_marketplace_order_sync_run_started_at (started_at)
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

-- BrickLink order ingestion and accounting foundation (Phase 1)
CREATE TABLE IF NOT EXISTS party_external_identity (
    party_external_identity_id BIGINT NOT NULL AUTO_INCREMENT,
    party_id BIGINT NOT NULL,
    transaction_platform_id INT NOT NULL,
    external_party_id VARCHAR(255) NOT NULL,
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (party_external_identity_id),
    UNIQUE KEY uq_party_external_identity_platform_party (transaction_platform_id, external_party_id),
    KEY idx_party_external_identity_party (party_id),
    CONSTRAINT fk_party_external_identity_party FOREIGN KEY (party_id) REFERENCES party (party_id),
    CONSTRAINT fk_party_external_identity_platform FOREIGN KEY (transaction_platform_id) REFERENCES transaction_platform (transaction_platform_id)
) ENGINE=InnoDB COMMENT='Stable marketplace identity for a reusable transaction party.';

CREATE TABLE IF NOT EXISTS transaction_party_snapshot (
    transaction_party_snapshot_id BIGINT NOT NULL AUTO_INCREMENT,
    transaction_id BIGINT NOT NULL,
    party_id BIGINT NOT NULL,
    party_role_code VARCHAR(16) NOT NULL,
    display_name VARCHAR(255) NULL,
    address1 VARCHAR(255) NULL,
    address2 VARCHAR(255) NULL,
    city VARCHAR(255) NULL,
    state VARCHAR(64) NULL,
    postal_code VARCHAR(64) NULL,
    country_code VARCHAR(8) NULL,
    country VARCHAR(255) NULL,
    phone VARCHAR(64) NULL,
    email VARCHAR(255) NULL,
    captured_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (transaction_party_snapshot_id),
    UNIQUE KEY uq_transaction_party_snapshot_role (transaction_id, party_role_code),
    KEY idx_transaction_party_snapshot_party (party_id),
    CONSTRAINT fk_transaction_party_snapshot_transaction FOREIGN KEY (transaction_id) REFERENCES transactions (transaction_id),
    CONSTRAINT fk_transaction_party_snapshot_party FOREIGN KEY (party_id) REFERENCES party (party_id)
) ENGINE=InnoDB COMMENT='Immutable order-time contact and address snapshot for each transaction party.';

CREATE TABLE IF NOT EXISTS transaction_item_revenue (
    transaction_item_revenue_id BIGINT NOT NULL AUTO_INCREMENT,
    transaction_item_id BIGINT NOT NULL,
    currency_code VARCHAR(8) NOT NULL,
    unit_amount DECIMAL(12,4) NOT NULL,
    quantity INT NOT NULL,
    total_amount DECIMAL(12,4) NOT NULL,
    PRIMARY KEY (transaction_item_revenue_id),
    UNIQUE KEY uq_transaction_item_revenue_item (transaction_item_id),
    CONSTRAINT fk_transaction_item_revenue_item FOREIGN KEY (transaction_item_id) REFERENCES transaction_item (transaction_item_id)
) ENGINE=InnoDB COMMENT='Revenue earned from a sold transaction item; intentionally separate from costs.';

ALTER TABLE transactions
    ADD UNIQUE KEY uq_transactions_platform_order (transaction_platform_id, transaction_order_id);

ALTER TABLE shipment
    ADD COLUMN external_shipment_id VARCHAR(100) NULL AFTER shipment_id,
    ADD COLUMN fulfillment_platform_code VARCHAR(30) NULL AFTER carrier_code,
    ADD COLUMN service_code VARCHAR(100) NULL AFTER fulfillment_platform_code,
    ADD COLUMN shipment_cost DECIMAL(12,4) NULL AFTER service_code,
    ADD COLUMN insurance_cost DECIMAL(12,4) NULL AFTER shipment_cost,
    ADD COLUMN currency_code VARCHAR(8) NULL AFTER insurance_cost,
    ADD UNIQUE KEY uq_shipment_platform_external (fulfillment_platform_code, external_shipment_id);

CREATE TABLE IF NOT EXISTS marketplace_order (
    marketplace_order_id INT NOT NULL AUTO_INCREMENT,
    last_sync_run_id INT NULL,
    marketplace_code VARCHAR(30) NOT NULL,
    external_order_id VARCHAR(100) NOT NULL,
    order_direction VARCHAR(20) NOT NULL,
    external_status_code VARCHAR(50) NOT NULL,
    ordered_at DATETIME NULL,
    status_changed_at DATETIME NULL,
    buyer_display_name VARCHAR(150) NULL,
    buyer_email VARCHAR(255) NULL,
    payment_status_code VARCHAR(50) NULL,
    payment_method VARCHAR(100) NULL,
    payment_currency_code CHAR(3) NULL,
    paid_at DATETIME NULL,
    shipping_method VARCHAR(150) NULL,
    shipping_method_id VARCHAR(100) NULL,
    shipping_address_present TINYINT(1) NULL DEFAULT 0,
    tracking_present TINYINT(1) NULL DEFAULT 0,
    subtotal_amount DECIMAL(10,2) NULL,
    shipping_amount DECIMAL(10,2) NULL,
    grand_total_amount DECIMAL(10,2) NULL,
    currency_code CHAR(3) NULL,
    display_currency_code CHAR(3) NULL,
    total_count INT NULL,
    unique_count INT NULL,
    total_weight DECIMAL(10,3) NULL,
    is_invoiced TINYINT(1) NULL,
    is_filed TINYINT(1) NULL,
    sent_drive_thru TINYINT(1) NULL,
    require_insurance TINYINT(1) NULL,
    payload_hash VARCHAR(64) NULL,
    last_seen_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (marketplace_order_id),
    UNIQUE KEY uq_marketplace_order_source_order (marketplace_code, external_order_id),
    INDEX idx_marketplace_order_status (marketplace_code, external_status_code),
    INDEX idx_marketplace_order_last_sync_run (last_sync_run_id),
    CONSTRAINT fk_marketplace_order_sync_run1
        FOREIGN KEY (last_sync_run_id)
        REFERENCES marketplace_order_sync_run (marketplace_order_sync_run_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS marketplace_order_item (
    marketplace_order_item_id INT NOT NULL AUTO_INCREMENT,
    marketplace_order_id INT NOT NULL,
    marketplace_listing_id INT NULL,
    item_inventory_id INT NULL,
    external_order_item_id VARCHAR(100) NULL,
    external_inventory_id VARCHAR(100) NULL,
    external_item_no VARCHAR(100) NULL,
    external_item_type VARCHAR(30) NULL,
    color_id INT NULL,
    color_name VARCHAR(100) NULL,
    quantity INT NOT NULL DEFAULT 0,
    condition_code VARCHAR(10) NULL,
    completeness_code VARCHAR(10) NULL,
    unit_price DECIMAL(10,2) NULL,
    final_unit_price DECIMAL(10,2) NULL,
    currency_code CHAR(3) NULL,
    item_weight DECIMAL(10,3) NULL,
    remarks TEXT NULL,
    description TEXT NULL,
    payload_hash VARCHAR(64) NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (marketplace_order_item_id),
    INDEX idx_marketplace_order_item_order (marketplace_order_id),
    INDEX idx_marketplace_order_item_listing (marketplace_listing_id),
    INDEX idx_marketplace_order_item_inventory (item_inventory_id),
    INDEX idx_marketplace_order_item_external_inventory (external_inventory_id),
    CONSTRAINT fk_marketplace_order_item_order1
        FOREIGN KEY (marketplace_order_id)
        REFERENCES marketplace_order (marketplace_order_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    CONSTRAINT fk_marketplace_order_item_marketplace_listing1
        FOREIGN KEY (marketplace_listing_id)
        REFERENCES marketplace_listing (marketplace_listing_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    CONSTRAINT fk_marketplace_order_item_item_inventory1
        FOREIGN KEY (item_inventory_id)
        REFERENCES item_inventory (item_inventory_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS marketplace_order_payload (
    marketplace_order_payload_id INT NOT NULL AUTO_INCREMENT,
    marketplace_order_id INT NOT NULL,
    marketplace_order_sync_run_id INT NULL,
    payload_type_code VARCHAR(50) NOT NULL,
    payload_hash VARCHAR(64) NULL,
    payload_json TEXT NULL,
    captured_at DATETIME NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (marketplace_order_payload_id),
    INDEX idx_marketplace_order_payload_order (marketplace_order_id),
    INDEX idx_marketplace_order_payload_sync_run (marketplace_order_sync_run_id),
    INDEX idx_marketplace_order_payload_type_hash (payload_type_code, payload_hash),
    CONSTRAINT fk_marketplace_order_payload_order1
        FOREIGN KEY (marketplace_order_id)
        REFERENCES marketplace_order (marketplace_order_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    CONSTRAINT fk_marketplace_order_payload_sync_run1
        FOREIGN KEY (marketplace_order_sync_run_id)
        REFERENCES marketplace_order_sync_run (marketplace_order_sync_run_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS marketplace_order_transaction_link (
    marketplace_order_transaction_link_id INT NOT NULL AUTO_INCREMENT,
    marketplace_order_id INT NOT NULL,
    transaction_id INT NOT NULL,
    marketplace_order_item_id INT NULL,
    transaction_item_id INT NULL,
    link_type_code VARCHAR(30) NOT NULL,
    link_status_code VARCHAR(30) NOT NULL,
    linked_at DATETIME NOT NULL,
    unlinked_at DATETIME NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    PRIMARY KEY (marketplace_order_transaction_link_id),
    INDEX idx_marketplace_order_transaction_link_order (marketplace_order_id),
    INDEX idx_marketplace_order_transaction_link_transaction (transaction_id),
    INDEX idx_marketplace_order_transaction_link_order_item (marketplace_order_item_id),
    INDEX idx_marketplace_order_transaction_link_transaction_item (transaction_item_id),
    INDEX idx_marketplace_order_transaction_link_type_status (link_type_code, link_status_code),
    CONSTRAINT fk_marketplace_order_transaction_link_order1
        FOREIGN KEY (marketplace_order_id)
        REFERENCES marketplace_order (marketplace_order_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    CONSTRAINT fk_marketplace_order_transaction_link_transaction1
        FOREIGN KEY (transaction_id)
        REFERENCES transactions (transaction_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    CONSTRAINT fk_marketplace_order_transaction_link_order_item1
        FOREIGN KEY (marketplace_order_item_id)
        REFERENCES marketplace_order_item (marketplace_order_item_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT,
    CONSTRAINT fk_marketplace_order_transaction_link_transaction_item1
        FOREIGN KEY (transaction_item_id)
        REFERENCES transaction_item (transaction_item_id)
        ON DELETE RESTRICT
        ON UPDATE RESTRICT
) ENGINE = InnoDB DEFAULT CHARSET = utf8mb4 COLLATE = utf8mb4_unicode_ci;
