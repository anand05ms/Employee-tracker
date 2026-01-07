// controllers/employeeController.js
const Location = require("../models/Location");
const Attendance = require("../models/Attendance");

// Helper: Calculate distance between two points (Haversine formula)
const calculateDistance = (lat1, lon1, lat2, lon2) => {
  const R = 6371e3; // Earth radius in meters
  const φ1 = (lat1 * Math.PI) / 180;
  const φ2 = (lat2 * Math.PI) / 180;
  const Δφ = ((lat2 - lat1) * Math.PI) / 180;
  const Δλ = ((lon2 - lon1) * Math.PI) / 180;

  const a =
    Math.sin(Δφ / 2) * Math.sin(Δφ / 2) +
    Math.cos(φ1) * Math.cos(φ2) * Math.sin(Δλ / 2) * Math.sin(Δλ / 2);
  const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));

  return R * c; // Distance in meters
};

// Helper: Calculate ETA in minutes (assuming 40 km/h average speed)
const calculateETA = (distanceInMeters) => {
  const speedKmh = 40; // Average speed
  const distanceKm = distanceInMeters / 1000;
  const timeHours = distanceKm / speedKmh;
  return Math.round(timeHours * 60); // Convert to minutes
};

// @desc    Check in
// @route   POST /api/employee/check-in
// @access  Private (Employee)
exports.checkIn = async (req, res) => {
  try {
    const { latitude, longitude, address, accuracy } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        message: "Please provide latitude and longitude",
      });
    }

    const employeeId = req.user.id;
    const today = new Date().toISOString().split("T")[0];

    // Check if already checked in today
    const existingAttendance = await Attendance.findOne({
      employeeId,
      date: today,
      status: { $in: ["CHECKED_IN", "REACHED_OFFICE"] },
    });

    if (existingAttendance) {
      return res.status(400).json({
        success: false,
        message: "You are already checked in for today",
      });
    }

    // Calculate distance from office
    const officeLat = parseFloat(process.env.OFFICE_LAT);
    const officeLng = parseFloat(process.env.OFFICE_LNG);
    const distanceFromOffice = calculateDistance(
      latitude,
      longitude,
      officeLat,
      officeLng
    );

    const eta = calculateETA(distanceFromOffice);
    const officeRadius = parseFloat(process.env.OFFICE_RADIUS);
    const isInOffice = distanceFromOffice <= officeRadius;

    // If checking in from office, set status as REACHED_OFFICE
    const attendanceStatus = isInOffice ? "REACHED_OFFICE" : "CHECKED_IN";

    // Create attendance record
    const attendance = await Attendance.create({
      employeeId,
      date: today,
      checkInTime: new Date(),
      checkInLocation: {
        type: "Point",
        coordinates: [longitude, latitude],
      },
      checkInAddress: address || "Unknown",
      estimatedTimeToOffice: eta,
      distanceFromOffice: Math.round(distanceFromOffice),
      status: attendanceStatus,
    });

    // Create location record
    await Location.create({
      employeeId,
      location: {
        type: "Point",
        coordinates: [longitude, latitude],
      },
      address: address || "Unknown",
      accuracy,
      status: isInOffice ? "REACHED" : "ACTIVE",
      isInOffice,
      timestamp: new Date(),
    });

    // 🚀 BROADCAST CHECK-IN TO ADMIN
    if (req.app.get("io")) {
      req.app
        .get("io")
        .to("admin")
        .emit("employee_status_changed", {
          type: isInOffice ? "REACHED_OFFICE" : "CHECKED_IN",
          employeeId,
          employeeName: req.user.name,
          employeeDepartment: req.user.department,
          employeePhone: req.user.phone,
          latitude,
          longitude,
          address: address || "Unknown",
          isInOffice,
          checkInTime: new Date().toISOString(),
          timestamp: new Date().toISOString(),
        });
    }

    res.status(201).json({
      success: true,
      message: isInOffice
        ? "🎉 You have reached the office!"
        : `Checked in successfully (${Math.round(
            distanceFromOffice / 1000
          )} km from office)`,
      data: {
        attendance,
        isInOffice,
        hasReachedOffice: isInOffice,
        distanceFromOffice: Math.round(distanceFromOffice),
        eta,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error checking in",
      error: error.message,
    });
  }
};

// @desc    Check out
// @route   POST /api/employee/check-out
// @access  Private (Employee)
exports.checkOut = async (req, res) => {
  try {
    const { latitude, longitude, address } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        message: "Please provide latitude and longitude",
      });
    }

    const employeeId = req.user.id;
    const today = new Date().toISOString().split("T")[0];

    // Find today's attendance
    const attendance = await Attendance.findOne({
      employeeId,
      date: today,
      status: { $in: ["CHECKED_IN", "REACHED_OFFICE"] },
    });

    if (!attendance) {
      return res.status(400).json({
        success: false,
        message: "You are not checked in today",
      });
    }

    // Calculate total hours
    const checkInTime = new Date(attendance.checkInTime);
    const checkOutTime = new Date();
    const totalHours = (
      (checkOutTime - checkInTime) /
      (1000 * 60 * 60)
    ).toFixed(2);

    // Update attendance
    attendance.checkOutTime = checkOutTime;
    attendance.checkOutLocation = {
      type: "Point",
      coordinates: [longitude, latitude],
    };
    attendance.checkOutAddress = address || "Unknown";
    attendance.totalHours = parseFloat(totalHours);
    attendance.status = "CHECKED_OUT";
    await attendance.save();

    // Update location to OFFLINE
    await Location.create({
      employeeId,
      location: {
        type: "Point",
        coordinates: [longitude, latitude],
      },
      address: address || "Unknown",
      status: "OFFLINE",
      isInOffice: false,
      timestamp: new Date(),
    });

    // 🛑 BROADCAST CHECK-OUT TO ADMIN
    if (req.app.get("io")) {
      req.app
        .get("io")
        .to("admin")
        .emit("employee_status_changed", {
          type: "CHECKED_OUT",
          employeeId,
          employeeName: req.user.name,
          totalHours: parseFloat(totalHours),
          checkOutTime: new Date().toISOString(),
        });
    }

    res.status(200).json({
      success: true,
      message: `Checked out successfully. Total hours: ${totalHours}`,
      data: {
        attendance,
        totalHours: parseFloat(totalHours),
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error checking out",
      error: error.message,
    });
  }
};

// @desc    Update location (🚀 REAL-TIME TRACKING - AUTO REACH DETECTION)
// @route   POST /api/employee/location
// @access  Private (Employee)
exports.updateLocation = async (req, res) => {
  try {
    const {
      latitude,
      longitude,
      address,
      accuracy,
      speed,
      heading,
      batteryLevel,
    } = req.body;

    if (!latitude || !longitude) {
      return res.status(400).json({
        success: false,
        message: "Please provide latitude and longitude",
      });
    }

    const employeeId = req.user.id;
    const today = new Date().toISOString().split("T")[0];

    // Calculate distance from office
    const officeLat = parseFloat(process.env.OFFICE_LAT);
    const officeLng = parseFloat(process.env.OFFICE_LNG);
    const officeRadius = parseFloat(process.env.OFFICE_RADIUS);
    const distanceFromOffice = calculateDistance(
      latitude,
      longitude,
      officeLat,
      officeLng
    );
    const isInOffice = distanceFromOffice <= officeRadius;

    // 🎯 AUTO-DETECT OFFICE ARRIVAL
    const attendance = await Attendance.findOne({
      employeeId,
      date: today,
      status: "CHECKED_IN",
    });

    let hasReachedOffice = false;

    if (attendance && isInOffice) {
      // Employee has reached office!
      attendance.status = "REACHED_OFFICE";
      await attendance.save();
      hasReachedOffice = true;

      console.log(`🎉 ${req.user.name} has REACHED the office!`);
    }

    // Create location record
    const location = await Location.create({
      employeeId,
      location: {
        type: "Point",
        coordinates: [longitude, latitude],
      },
      address: address || "Unknown",
      accuracy,
      speed: speed || 0,
      heading,
      isInOffice,
      batteryLevel,
      status: isInOffice ? "REACHED" : "ACTIVE",
      timestamp: new Date(),
    });

    // 🚀 BROADCAST TO ADMIN
    if (req.app.get("io")) {
      const updateData = {
        type: hasReachedOffice ? "REACHED_OFFICE" : "LOCATION_UPDATE",
        employeeId,
        employeeName: req.user.name,
        employeeDepartment: req.user.department,
        latitude,
        longitude,
        address: address || "Unknown",
        isInOffice,
        hasReachedOffice,
        accuracy,
        speed: speed || 0,
        batteryLevel,
        distanceFromOffice: Math.round(distanceFromOffice),
        timestamp: new Date().toISOString(),
      };

      req.app.get("io").to("admin").emit("employee_status_changed", updateData);
    }

    res.status(201).json({
      success: true,
      message: hasReachedOffice
        ? "🎉 You have reached the office!"
        : "Location updated",
      data: {
        location,
        isInOffice,
        hasReachedOffice,
        distanceFromOffice: Math.round(distanceFromOffice),
      },
    });
  } catch (error) {
    console.error("Location update error:", error.message);
    res.status(200).json({
      success: false,
      message: "Location update failed silently",
    });
  }
};

// @desc    Get my attendance history
// @route   GET /api/employee/attendance
// @access  Private (Employee)
exports.getMyAttendance = async (req, res) => {
  try {
    const employeeId = req.user.id;
    const { startDate, endDate, limit = 30 } = req.query;

    let query = { employeeId };

    if (startDate && endDate) {
      query.date = {
        $gte: startDate,
        $lte: endDate,
      };
    }

    const attendance = await Attendance.find(query)
      .sort({ date: -1 })
      .limit(parseInt(limit));

    res.status(200).json({
      success: true,
      count: attendance.length,
      data: {
        attendance,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching attendance",
      error: error.message,
    });
  }
};

// @desc    Get my current status
// @route   GET /api/employee/status
// @access  Private (Employee)
exports.getMyStatus = async (req, res) => {
  try {
    const employeeId = req.user.id;
    const today = new Date().toISOString().split("T")[0];

    const attendance = await Attendance.findOne({
      employeeId,
      date: today,
    });

    const latestLocation = await Location.findOne({
      employeeId,
      timestamp: {
        $gte: new Date(Date.now() - 5 * 60 * 1000),
      },
    })
      .sort({ timestamp: -1 })
      .limit(1);

    const isCheckedIn =
      attendance &&
      ["CHECKED_IN", "REACHED_OFFICE"].includes(attendance.status);
    const hasReachedOffice =
      attendance && attendance.status === "REACHED_OFFICE";

    res.status(200).json({
      success: true,
      data: {
        attendance,
        latestLocation,
        isCheckedIn,
        hasReachedOffice,
      },
    });
  } catch (error) {
    res.status(500).json({
      success: false,
      message: "Error fetching status",
      error: error.message,
    });
  }
};
