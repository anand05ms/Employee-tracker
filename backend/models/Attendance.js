// models/Attendance.js
const mongoose = require("mongoose");

const AttendanceSchema = new mongoose.Schema(
  {
    employeeId: {
      type: mongoose.Schema.Types.ObjectId,
      ref: "User",
      required: true,
    },
    date: {
      type: String,
      required: true,
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
        type: [Number],
        required: true,
      },
      address: String,
      timestamp: Date,
    },
    checkInAddress: String,

    // ✅ Current location (updates in real-time)
    currentLocation: {
      type: {
        type: String,
        enum: ["Point"],
        default: "Point",
      },
      coordinates: {
        type: [Number],
      },
      address: String,
      timestamp: Date,
    },

    checkOutTime: Date,

    // ✅ Make checkOutLocation completely optional (no default)
    checkOutLocation: {
      type: {
        type: String,
        enum: ["Point"],
      },
      coordinates: {
        type: [Number],
      },
      address: String,
      timestamp: Date,
    },
    checkOutAddress: String,

    estimatedTimeToOffice: Number,
    distanceFromOffice: Number,
    totalHours: Number,
    status: {
      type: String,
      enum: ["CHECKED_IN", "REACHED_OFFICE", "CHECKED_OUT"],
      default: "CHECKED_IN",
    },
    reachedOfficeTime: Date,
  },
  { timestamps: true }
);

// Indexes for geospatial queries
AttendanceSchema.index({ checkInLocation: "2dsphere" });
AttendanceSchema.index({ currentLocation: "2dsphere" });
// Only index checkOutLocation if it exists
AttendanceSchema.index({ checkOutLocation: "2dsphere" }, { sparse: true });

module.exports = mongoose.model("Attendance", AttendanceSchema);
