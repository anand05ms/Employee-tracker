// models/Location.js
const mongoose = require('mongoose');

const locationSchema = new mongoose.Schema({
  employeeId: {
    type: mongoose.Schema.Types.ObjectId,
    ref: 'User',
    required: true,
    index: true,
  },
  location: {
    type: {
      type: String,
      enum: ['Point'],
      default: 'Point',
    },
    coordinates: {
      type: [Number],
      required: true,
    },
  },
  address: {
    type: String,
    trim: true,
  },
  accuracy: {
    type: Number,
  },
  speed: {
    type: Number,
    default: 0,
  },
  heading: {
    type: Number,
  },
  timestamp: {
    type: Date,
    default: Date.now,
    // Removed index: true from here (keeping it only in schema.index below)
  },
  status: {
    type: String,
    enum: ['ACTIVE', 'IDLE', 'OFFLINE'],
    default: 'ACTIVE',
  },
  isInOffice: {
    type: Boolean,
    default: false,
  },
  batteryLevel: {
    type: Number,
    min: 0,
    max: 100,
  },
});

// Create geospatial index for location queries
locationSchema.index({ location: '2dsphere' });

// Compound index for efficient queries
locationSchema.index({ employeeId: 1, timestamp: -1 });

// Auto-delete old location records after 30 days (optional)
// Comment out if you want to keep all history
// locationSchema.index({ timestamp: 1 }, { expireAfterSeconds: 2592000 });

module.exports = mongoose.model('Location', locationSchema);
