module.exports = {
  id: "002_payment_refund_fields",
  description: "Add gateway signature, refund columns, and status indexes to payments table",
  async up(client) {
    await client.query(`
      ALTER TABLE payments ADD COLUMN IF NOT EXISTS gateway_signature VARCHAR(255);
      ALTER TABLE payments ADD COLUMN IF NOT EXISTS refund_id VARCHAR(255);
      ALTER TABLE payments ADD COLUMN IF NOT EXISTS refund_amount_minor INT DEFAULT 0;
      ALTER TABLE payments ADD COLUMN IF NOT EXISTS refund_reason TEXT;
      CREATE INDEX IF NOT EXISTS idx_payments_gateway_order_id ON payments(gateway_order_id);
      CREATE INDEX IF NOT EXISTS idx_payments_gateway_payment_id ON payments(gateway_payment_id);
      CREATE INDEX IF NOT EXISTS idx_payments_status ON payments(status);
    `);
  }
};

