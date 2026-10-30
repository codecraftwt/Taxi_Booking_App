const mongoose = require("mongoose");

const addressSchema = new mongoose.Schema({
  place: {
    type: String,
  },
  street: {
    type: String,
    default: "Unnamed Road",
  },
  state: {
    type: String,
  },
  country: {
    type: String,
  },
  lat: {
    type: Number,
    required: true,
  },
  lon: {
    type: Number,
    required: true,
  },
  pincode: {
    type: String,
  },
});

const Address = mongoose.models.Address || mongoose.model("Address", addressSchema, "addresses");

module.exports = Address;

