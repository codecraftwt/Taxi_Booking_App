const mongoose = require("mongoose");

const priceSchema = new mongoose.Schema({
  base_price: {
    type: Number,
    required: true,
  },
  price_per_km: {
    type: Number,
    required: true,
  },
});

const Price = mongoose.models.Price || mongoose.model("Price", priceSchema, "prices");

module.exports = Price;

