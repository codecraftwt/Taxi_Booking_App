const mongoose = require("mongoose");
const Validator = require("../utils/validator");

const userSchema = new mongoose.Schema({
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
    validate: {
      validator: (phone) => Validator.validatePhone(phone),
      message: (props) => `${props.value} is not a valid phone.`,
    },
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
  image_url: {
    type: String,
    minLength: 1,
    maxLength: 1000,
  },
});

const User = mongoose.models.User || mongoose.model("User", userSchema, "users");

module.exports = User;

