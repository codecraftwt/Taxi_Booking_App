const mongoose = require("mongoose");
const Validator = require("../utils/validator");

const driverSchema = new mongoose.Schema({
  name: {
    type: String,
    required: true,
    minLength: 1,
    maxLength: 1000,
  },
  phone: {
    type: String,
    required: true,
    unique: true,
    minLength: 10,
    maxLength: 10,
  },
  email: {
    type: String,
    unique: true,
    sparse: true,
    index: true,
    minLength: 5,
    maxLength: 254,
    validate: {
      validator: (email) => Validator.validateEmail(email),
      message: (props) => `${props.value} is not a valid email.`,
    },
  },
  password: {
    type: String,
    required: true,
    minLength: 8,
    maxLength: 1000,
    validate: {
      validator: (password) => Validator.validatePassword(password),
      message: () => `Password must be atleast 8 characters long.`,
    },
  },
  vehicle_name: {
    type: String,
    required: true,
    minLength: 1,
    maxLength: 1000,
  },
  vehicle_number: {
    type: String,
    required: true,
    minLength: 1,
    maxLength: 1000,
  },
  image_url: {
    type: String,
    minLength: 1,
    maxLength: 1000,
  },
  active: {
    type: Boolean,
    default: true,
  },
});

const Driver = mongoose.models.Driver || mongoose.model("Driver", driverSchema, "drivers");

module.exports = Driver;

