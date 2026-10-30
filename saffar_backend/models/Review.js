const mongoose = require("mongoose");

const reviewSchema = new mongoose.Schema({
  review: {
    type: String,
    required: true,
    minLength: 1,
    maxLength: 50000,
  },
  stars: {
    type: Number,
    required: true,
    min: 0,
    max: 5,
  },
  user: {
    type: mongoose.SchemaTypes.ObjectId,
    required: true,
    ref: "User",
  },
  driver: {
    type: mongoose.SchemaTypes.ObjectId,
    required: true,
    ref: "Driver",
  },
  createdAt: {
    type: Date,
    required: true,
  },
  updatedAt: {
    type: Date,
    required: true,
  },
});

const Review = mongoose.models.Review || mongoose.model("Review", reviewSchema, "reviews");

module.exports = Review;

