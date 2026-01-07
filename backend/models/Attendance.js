// models/Attendance.js
const mongoose = require("mongoose");

const attendanceSchema = new mongoose.Schema({
  employeeId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: "User",
    required: true,
    index: true,
  },
  date: {
    type: String, // Format: YYYY-MM-DD
    required: true,
    index: true,
  },
  checkInTime: {
    type: Date,
    required: true,
  },
  checkInLocation: {
    type: {
      type: String,
      enum: ["Point"],
      default: "Point",
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
      required: true,
    },
  },
  checkInAddress: {
    type: String,
    trim: true,
  },
  estimatedTimeToOffice: {
    type: Number, // Minutes
  },
  distanceFromOffice: {
    type: Number, // Meters
  },
  checkOutTime: {
    type: Date,
  },
  checkOutLocation: {
    type: {
      type: String,
      enum: ["Point"],
    },
    coordinates: {
      type: [Number], // [longitude, latitude]
    },
  },
  checkOutAddress: {
    type: String,
    trim: true,
  },
  totalHours: {
    type: Number, // Decimal hours (e.g., 8.5)
    default: 0,
  },
  status: {
    type: String,
    enum: ["CHECKED_IN", "CHECKED_OUT", "ABSENT"],
    default: "CHECKED_IN",
  },
  notes: {
    type: String,
    trim: true,
  },
  createdAt: {
    type: Date,
    default: Date.now,
  },
  updatedAt: {
    type: Date,
    default: Date.now,
  },
});

// Compound index for quick queries
attendanceSchema.index({ employeeId: 1, date: -1 });

// Geospatial indexes
attendanceSchema.index({ checkInLocation: "2dsphere" });
attendanceSchema.index({ checkOutLocation: "2dsphere" });

// Update 'updatedAt' on save
attendanceSchema.pre("save", function (next) {
  this.updatedAt = Date.now();
  next();
});

module.exports = mongoose.model("Attendance", attendanceSchema);
